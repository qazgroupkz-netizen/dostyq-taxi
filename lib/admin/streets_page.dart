import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/streets.dart';
import '../services/geo_api.dart';
import '../state.dart';
import '../theme.dart';

/// Улицы района: загрузка из таблицы, правка, точки на карте для поиска «Абая 12».
class StreetsPage extends StatefulWidget {
  const StreetsPage({super.key});
  @override
  State<StreetsPage> createState() => _StreetsPageState();
}

class _StreetsPageState extends State<StreetsPage> {
  Stream<List<Street>>? _stream;
  String? _region;
  List<Street> _list = const [];
  String? _progress;

  Future<void> _save(List<Street> list) async {
    final st = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await st.catalog.saveStreets(st.regionId, list);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Не удалось сохранить: $e')));
    }
  }

  Future<void> _import() async {
    final text = TextEditingController();
    var replace = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('Загрузить улицы'),
          content: SizedBox(
            width: 560,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Скопируйте строки из Excel или файла streets-template.csv и вставьте сюда.\n'
                    'Столбцы: Название; По-казахски; Другие названия через запятую; Сколько домов'),
                const SizedBox(height: 10),
                TextField(
                  controller: text,
                  maxLines: 12,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Абая;Абай;абай;108\nТауелсиздик;Тәуелсіздік;независимости;74',
                  ),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: replace,
                  onChanged: (v) => setSt(() => replace = v ?? false),
                  title: const Text('Заменить весь список (иначе — добавить к текущему)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Загрузить')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final added = parseStreets(text.text);
    if (added.isEmpty) return;
    // Совпадающие названия обновляем, точку на карте сохраняем.
    final byName = {for (final s in replace ? const <Street>[] : _list) s.name.toLowerCase(): s};
    for (final s in added) {
      final old = byName[s.name.toLowerCase()];
      byName[s.name.toLowerCase()] = s.withPoint(old?.point);
    }
    await _save(byName.values.toList());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Загружено улиц: ${added.length}. Теперь нажмите «Найти на карте».')),
    );
  }

  /// Ищем середину каждой улицы без точки в OpenStreetMap — по одной в секунду.
  Future<void> _locate() async {
    final st = context.read<AppState>();
    final center = st.region.center;
    final city = st.region.name;
    final list = [..._list];
    var found = 0;
    var missing = 0;
    for (var i = 0; i < list.length; i++) {
      if (!mounted) return;
      if (list[i].point != null) continue;
      setState(() => _progress = 'Ищем «${list[i].name}» (${i + 1} из ${list.length})…');
      final p = await GeoApi.search('${list[i].name}, $city', center) ??
          (list[i].nameKz.isNotEmpty ? await GeoApi.search('${list[i].nameKz}, $city', center) : null);
      if (p != null) {
        list[i] = list[i].withPoint(p);
        found++;
      } else {
        missing++;
      }
    }
    await _save(list);
    if (!mounted) return;
    setState(() => _progress = null);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Найдено на карте: $found. Не найдено: $missing — '
          'их клиент укажет на карте сам.'),
      duration: const Duration(seconds: 6),
    ));
  }

  Future<void> _editStreet(Street s) async {
    final name = TextEditingController(text: s.name);
    final kz = TextEditingController(text: s.nameKz);
    final syn = TextEditingController(text: s.synonyms.join(', '));
    final houses = TextEditingController(text: s.houses > 0 ? '${s.houses}' : '');
    final res = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Улица'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Название')),
              TextField(controller: kz, decoration: const InputDecoration(labelText: 'По-казахски')),
              TextField(
                controller: syn,
                decoration: const InputDecoration(labelText: 'Другие названия через запятую'),
              ),
              TextField(
                controller: houses,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Сколько домов'),
              ),
              if (s.point != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text('Точка на карте есть. Сбросьте её, если она неверная — '
                      'потом нажмите «Найти на карте».'),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'delete'),
            child: Text('Удалить', style: TextStyle(color: context.danger)),
          ),
          if (s.point != null)
            TextButton(onPressed: () => Navigator.pop(ctx, 'reset'), child: const Text('Сбросить точку')),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(ctx, 'save'), child: const Text('Сохранить')),
        ],
      ),
    );
    if (res == null) return;
    final list = [..._list]..remove(s);
    if (res != 'delete' && name.text.trim().isNotEmpty) {
      list.add(Street(
        name: name.text.trim(),
        nameKz: kz.text.trim(),
        synonyms: syn.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
        houses: int.tryParse(houses.text.trim()) ?? 0,
        point: res == 'reset' ? null : s.point,
      ));
    }
    await _save(list);
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    if (_region != st.regionId) {
      _region = st.regionId;
      _stream = st.catalog.watchStreets(st.regionId);
    }
    return StreamBuilder<List<Street>>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('Не удалось загрузить: ${snap.error}'));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        _list = snap.data!;
        final noPoint = _list.where((s) => s.point == null).length;
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('Улицы · ${st.region.name}',
                    style: TextStyle(color: context.ink, fontSize: 26, fontWeight: FontWeight.w800)),
                const SizedBox(width: 10),
                FilledButton.icon(
                  onPressed: _progress == null ? _import : null,
                  icon: const Icon(Icons.upload_rounded),
                  label: const Text('Загрузить из таблицы'),
                  style: FilledButton.styleFrom(backgroundColor: context.taxi, minimumSize: const Size(0, 48)),
                ),
                OutlinedButton.icon(
                  onPressed: _progress == null && noPoint > 0 ? _locate : null,
                  icon: const Icon(Icons.travel_explore_rounded),
                  label: Text('Найти на карте ($noPoint)'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                ),
                OutlinedButton.icon(
                  onPressed: _progress == null
                      ? () => _editStreet(const Street(name: ''))
                      : null,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Добавить улицу'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Клиент пишет «абая 12» — приложение находит улицу и ставит точку. '
              'Улицы без точки на карте тоже находятся, но клиента попросят уточнить место на карте.',
              style: TextStyle(color: context.muted, fontSize: 14),
            ),
            if (_progress != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  children: [
                    const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_progress!)),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            if (_list.isEmpty)
              Text('Улиц пока нет. Нажмите «Загрузить из таблицы».',
                  style: TextStyle(color: context.muted, fontSize: 15)),
            for (final s in _list)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: context.paper,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: context.lineC),
                ),
                child: ListTile(
                  onTap: _progress == null ? () => _editStreet(s) : null,
                  leading: Icon(
                    s.point != null ? Icons.check_circle_rounded : Icons.help_outline_rounded,
                    color: s.point != null ? AdminC.ok : context.muted,
                  ),
                  title: Text(s.name, style: TextStyle(color: context.ink, fontWeight: FontWeight.w700)),
                  subtitle: Text(
                    [
                      if (s.nameKz.isNotEmpty) s.nameKz,
                      if (s.synonyms.isNotEmpty) s.synonyms.join(', '),
                      if (s.houses > 0) 'домов: ${s.houses}',
                      s.point != null ? 'есть на карте' : 'нет точки на карте',
                    ].join(' · '),
                    style: TextStyle(color: context.muted),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
