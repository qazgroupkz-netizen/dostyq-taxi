import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/supabase/sb_auth.dart';
import '../data/supabase/sb_catalog.dart';
import '../data/supabase/sb_client.dart';
import '../state.dart';
import '../theme.dart';

/// Разовый перенос справочников из Firebase в свою базу: районы, тарифы, улицы, места.
/// Есть только в админке на Firebase. Заказы и водители не переносятся — там тестовые данные.
class MigratePage extends StatefulWidget {
  const MigratePage({super.key});
  @override
  State<MigratePage> createState() => _MigratePageState();
}

class _MigratePageState extends State<MigratePage> {
  final _auth = SupabaseAuthRepository();
  final _phone = TextEditingController(text: '+77770000000');
  final _code = TextEditingController();
  bool _ready = false;
  bool _codeSent = false;
  bool _busy = false;
  String? _signedIn;
  final _log = <String>[];

  @override
  void initState() {
    super.initState();
    initSupabase().then((_) async {
      final u = _auth.current;
      final p = u == null ? null : await _auth.profile(u.uid);
      if (!mounted) return;
      setState(() {
        _ready = true;
        _signedIn = p?.role == 'admin' ? u!.phone : null;
      });
    });
  }

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() f) async {
    setState(() => _busy = true);
    try {
      await f();
    } catch (e) {
      _log.add('Ошибка: $e');
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _send() => _run(() async {
        await _auth.sendCode(_phone.text.trim());
        _codeSent = true;
      });

  Future<void> _verify() => _run(() async {
        await _auth.verifyCode(_code.text.trim());
        final u = _auth.current!;
        final p = await _auth.profile(u.uid);
        if (p?.role != 'admin') {
          _log.add('Номер ${u.phone} в новой базе не администратор — перенос не получится.');
          return;
        }
        _signedIn = u.phone;
      });

  Future<void> _migrate() => _run(() async {
        final st = context.read<AppState>();
        final to = SupabaseCatalogRepository();
        _log.clear();

        final regions = st.allRegions;
        for (final r in regions) {
          await to.saveRegion(r);
        }
        _log.add('Районы: ${regions.length}');
        setState(() {});

        for (final r in regions) {
          final s = await st.catalog.watchSettings(r.id).first;
          await to.saveSettings(r.id, s);
          for (final e in s.routes.entries) {
            await to.saveRoutePrice(r.id, e.key, e.value);
          }
          final streets = await st.catalog.watchStreets(r.id).first;
          if (streets.isNotEmpty) await to.saveStreets(r.id, streets);
          _log.add('${r.name}: тарифы${s.routes.isEmpty ? '' : ' и ${s.routes.length} направл.'}, улиц ${streets.length}');
          setState(() {});
        }

        final places = await st.catalog.watchPlaces().first;
        for (final p in places) {
          await to.savePlace(p);
        }
        _log.add('Места: ${places.length}');
        _log.add('Готово. Откройте alakoltaxi.kz/beta/admin/ и проверьте.');
      });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Перенос в новую базу',
            style: TextStyle(color: context.ink, fontSize: 26, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(
          'Копирует районы, тарифы, цены направлений, улицы и места из Firebase в базу на alakoltaxi.kz. '
          'Можно запускать несколько раз — записи обновятся, не задвоятся. Заказы и водители не переносятся.',
          style: TextStyle(color: context.muted, fontSize: 15, height: 1.5),
        ),
        const SizedBox(height: 20),
        if (!_ready)
          const LinearProgressIndicator()
        else if (_signedIn == null) ...[
          Text('1. Войдите в новую базу номером администратора',
              style: TextStyle(color: context.ink, fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          SizedBox(
            width: 360,
            child: TextField(
              controller: _phone,
              decoration: const InputDecoration(labelText: 'Телефон'),
            ),
          ),
          if (_codeSent)
            SizedBox(
              width: 360,
              child: TextField(
                controller: _code,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Код (для тестовых номеров 123456)'),
              ),
            ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(
              onPressed: _busy ? null : (_codeSent ? _verify : _send),
              style: FilledButton.styleFrom(backgroundColor: context.taxi, minimumSize: const Size(0, 48)),
              child: Text(_codeSent ? 'Войти' : 'Получить код'),
            ),
          ),
        ] else ...[
          Text('Вошли в новую базу: $_signedIn',
              style: TextStyle(color: context.ink, fontSize: 15)),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: _busy ? null : _migrate,
              icon: const Icon(Icons.cloud_upload_outlined),
              label: const Text('Перенести справочники'),
              style: FilledButton.styleFrom(backgroundColor: context.taxi, minimumSize: const Size(0, 48)),
            ),
          ),
        ],
        if (_busy)
          const Padding(padding: EdgeInsets.only(top: 16), child: LinearProgressIndicator()),
        const SizedBox(height: 16),
        for (final l in _log)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(l, style: TextStyle(color: context.ink, fontSize: 15)),
          ),
      ],
    );
  }
}
