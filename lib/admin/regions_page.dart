import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart' show MapController;
import 'package:provider/provider.dart';
import '../data/regions.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/taxi_map.dart';

class RegionsPage extends StatefulWidget {
  const RegionsPage({super.key});
  @override
  State<RegionsPage> createState() => _RegionsPageState();
}

class _RegionsPageState extends State<RegionsPage> {
  final _map = MapController();
  final _name = TextEditingController();
  final _radius = TextEditingController();
  Region? _edit;
  bool _isNew = false;
  bool _active = true;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _radius.dispose();
    super.dispose();
  }

  void _snack(String t) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  void _open(Region r, {bool isNew = false}) {
    setState(() {
      _edit = r;
      _isNew = isNew;
      _name.text = r.name;
      _radius.text = r.radiusKm.toStringAsFixed(0);
      _active = r.active;
    });
    _map.move(r.center, 13);
  }

  Future<void> _new() async {
    final id = await context.read<AppState>().catalog.newRegionId();
    if (!mounted) return;
    _open(Region(id: id, name: '', center: _map.camera.center, radiusKm: 5), isNew: true);
  }

  Future<void> _importBuiltIn() async {
    setState(() => _busy = true);
    try {
      final catalog = context.read<AppState>().catalog;
      for (final r in builtInRegions) {
        await catalog.saveRegion(r);
      }
      _snack('Районы загружены в базу. Теперь их можно править и добавлять новые.');
    } catch (e) {
      _snack('Не удалось загрузить: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    final r = _edit;
    if (r == null) return;
    final radius = double.tryParse(_radius.text.trim());
    if (_name.text.trim().isEmpty || radius == null || radius <= 0) {
      _snack('Введите название и радиус в километрах');
      return;
    }
    final updated = r.copyWith(
      name: _name.text.trim(),
      center: _map.camera.center,
      radiusKm: radius,
      active: _active,
    );
    setState(() => _busy = true);
    try {
      await context.read<AppState>().catalog.saveRegion(updated);
      if (!mounted) return;
      setState(() {
        _edit = updated;
        _isNew = false;
      });
      _snack('Сохранено');
    } catch (e) {
      _snack('Не удалось сохранить: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final inDb = state.regionsFromDb.isNotEmpty;
    final wide = MediaQuery.of(context).size.width >= 1100;

    final map = ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: TaxiMap(
        controller: _map,
        initialCenter: state.region.center,
        centerPin: _edit != null,
        pinLabel: _edit == null ? null : 'Центр района',
      ),
    );

    final panel = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.paper,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.lineC),
      ),
      child: _edit == null ? _list(context, state, inDb) : _form(context),
    );

    if (wide) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 380, child: SingleChildScrollView(child: panel)),
            const SizedBox(width: 16),
            Expanded(child: map),
          ],
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        SizedBox(height: 320, child: map),
        const SizedBox(height: 12),
        panel,
      ],
    );
  }

  Widget _list(BuildContext context, AppState state, bool inDb) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Районы',
            style: TextStyle(color: context.ink, fontSize: 22, fontWeight: FontWeight.w800)),
        Text(
          'У каждого района свои цены, места и водители. '
          'Выключенный район клиенты не видят.',
          style: TextStyle(color: context.muted, fontSize: 13.5, height: 1.4),
        ),
        const SizedBox(height: 12),
        if (!inDb) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.taxiSft,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.jLine),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Сейчас работают встроенные районы: Достык и Ушарал. '
                    'Загрузите их в базу, чтобы править и добавлять новые.',
                    style: TextStyle(color: context.ink, fontSize: 14, height: 1.4)),
                const SizedBox(height: 10),
                FilledButton(
                  onPressed: _busy ? null : _importBuiltIn,
                  style: FilledButton.styleFrom(backgroundColor: context.taxi),
                  child: const Text('Загрузить районы в базу'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: inDb && !_busy ? _new : null,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Новый район'),
            style: FilledButton.styleFrom(backgroundColor: context.taxi),
          ),
        ),
        const SizedBox(height: 8),
        for (final r in state.allRegions)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            leading: Icon(Icons.location_city_rounded,
                color: r.active ? AdminC.ok : context.muted),
            title: Text(r.name, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(
              '${r.active ? 'Работает' : 'Выключен'} · радиус ${r.radiusKm.toStringAsFixed(0)} км',
            ),
            onTap: inDb ? () => _open(r) : null,
          ),
      ],
    );
  }

  Widget _form(BuildContext context) {
    InputDecoration deco(String label) => InputDecoration(
          labelText: label,
          isDense: true,
          filled: true,
          fillColor: context.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => setState(() => _edit = null),
            ),
            Text(_isNew ? 'Новый район' : 'Изменить район',
                style: TextStyle(color: context.ink, fontSize: 20, fontWeight: FontWeight.w800)),
          ],
        ),
        Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.taxiSft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'Двигайте карту, чтобы булавка стояла в центре посёлка или города.',
            style: TextStyle(color: context.ink, fontSize: 13.5, height: 1.4),
          ),
        ),
        TextField(controller: _name, decoration: deco('Название, например: Кабанбай')),
        const SizedBox(height: 10),
        TextField(
          controller: _radius,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: deco('Радиус района, км'),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Район работает'),
          subtitle: const Text('Клиенты видят его и могут заказать'),
          value: _active,
          onChanged: (v) => setState(() => _active = v),
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: _busy ? null : _save,
          style: FilledButton.styleFrom(
            backgroundColor: context.taxi,
            minimumSize: const Size.fromHeight(50),
          ),
          child: Text(_busy ? 'Сохраняем…' : 'Сохранить'),
        ),
      ],
    );
  }
}
