import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' show MapController;
import 'package:latlong2/latlong.dart' show Distance;
import 'package:provider/provider.dart';
import '../data/places.dart';
import '../data/regions.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/taxi_map.dart';

class PlacesPage extends StatefulWidget {
  const PlacesPage({super.key});
  @override
  State<PlacesPage> createState() => _PlacesPageState();
}

class _PlacesPageState extends State<PlacesPage> {
  final _map = MapController();
  final _name = TextEditingController();
  final _sub = TextEditingController();
  final _syn = TextEditingController();
  final _search = TextEditingController();

  /// Редактируемое место; isNew — ещё не сохранено.
  Place? _edit;
  bool _isNew = false;
  String _category = 'other';
  bool _chip = false;
  bool _approx = false;
  bool _busy = false;
  String? _shownRegion;

  @override
  void dispose() {
    _name.dispose();
    _sub.dispose();
    _syn.dispose();
    _search.dispose();
    super.dispose();
  }

  void _open(Place p, {bool isNew = false}) {
    setState(() {
      _edit = p;
      _isNew = isNew;
      _name.text = p.name;
      _sub.text = p.sub;
      _syn.text = p.synonyms.join(', ');
      _category = placeCategories.containsKey(p.category) ? p.category : 'other';
      _chip = p.chip;
      _approx = p.approx;
    });
    _map.move(p.point, _map.camera.zoom < 16 ? 17 : _map.camera.zoom);
  }

  Future<void> _new() async {
    final id = await context.read<AppState>().catalog.newPlaceId();
    if (!mounted) return;
    _open(
      Place(id: id, name: '', sub: '', category: 'shop', point: _map.camera.center,
          region: context.read<AppState>().regionId),
      isNew: true,
    );
  }

  void _snack(String t) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  Future<void> _save() async {
    final p = _edit;
    if (p == null) return;
    if (_name.text.trim().isEmpty) {
      _snack('Введите название');
      return;
    }
    final center = _map.camera.center;
    final moved = Distance()(center, p.point) > 2;
    final updated = p.copyWith(
      name: _name.text.trim(),
      sub: _sub.text.trim(),
      category: _category,
      point: center,
      synonyms: _syn.text
          .split(',')
          .map((s) => s.trim().toLowerCase())
          .where((s) => s.isNotEmpty)
          .toList(),
      chip: _chip,
      group: _category == 'school' ? 'school' : null,
      // Поставили точку руками — значит, место уточнено.
      approx: moved ? false : _approx,
    );
    setState(() => _busy = true);
    try {
      await context.read<AppState>().catalog.savePlace(updated);
      if (!mounted) return;
      setState(() {
        _edit = updated;
        _isNew = false;
        _approx = updated.approx;
      });
      _snack('Сохранено. Место уже видно в приложении.');
    } catch (e) {
      _snack('Не удалось сохранить: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final p = _edit;
    if (p == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить место?'),
        content: Text('«${p.name}» пропадёт из поиска и с карты.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Удалить')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await context.read<AppState>().catalog.deletePlace(p.id);
      if (!mounted) return;
      setState(() => _edit = null);
      _snack('Удалено');
    } catch (e) {
      _snack('Не удалось удалить: $e');
    }
  }

  Future<void> _importBuiltIn() async {
    setState(() => _busy = true);
    try {
      final catalog = context.read<AppState>().catalog;
      for (final p in dostykPlaces) {
        await catalog.savePlace(p);
      }
      _snack('Загружено ${dostykPlaces.length} мест. Теперь их можно править.');
    } catch (e) {
      _snack('Не удалось загрузить: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    // Встроенный список есть только у Достыка; другие районы заполняются с нуля.
    final showImport = state.allPlacesFromDb.isEmpty && state.regionId == defaultRegionId;
    final fromDb = !showImport;
    if (_shownRegion != state.regionId) {
      final first = _shownRegion == null;
      _shownRegion = state.regionId;
      if (!first) {
        _edit = null;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _map.move(state.region.center, 15);
        });
      }
    }
    final q = _search.text.trim();
    final list = q.isEmpty ? state.places : searchPlaces(q, state.places);
    final wide = MediaQuery.of(context).size.width >= 1100;

    final map = ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: TaxiMap(
        controller: _map,
        initialCenter: state.region.center,
        centerPin: _edit != null,
        pinLabel: _edit == null
            ? null
            : (_name.text.trim().isEmpty ? 'Новое место' : _name.text.trim()),
        places: [
          for (final p in state.places)
            if (p.id != _edit?.id) p,
        ],
        onPlaceTap: _open,
      ),
    );

    final listPanel = _panel(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showImport) ...[
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
                  Text(
                    'В базе пока нет мест — приложение показывает встроенный список. '
                    'Загрузите его в базу, чтобы править.',
                    style: TextStyle(color: context.ink, fontSize: 14, height: 1.4),
                  ),
                  const SizedBox(height: 10),
                  FilledButton(
                    onPressed: _busy ? null : _importBuiltIn,
                    style: FilledButton.styleFrom(backgroundColor: context.taxi),
                    child: Text('Загрузить ${dostykPlaces.length} мест в базу'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Проверить поиск: балница, мектеп…',
                    prefixIcon: const Icon(Icons.search_rounded),
                    isDense: true,
                    filled: true,
                    fillColor: context.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: fromDb && !_busy ? _new : null,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Новое'),
                style: FilledButton.styleFrom(backgroundColor: context.taxi),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final p in list)
            ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              selected: p.id == _edit?.id,
              leading: CircleAvatar(
                backgroundColor: p.color.withOpacity(.14),
                child: Icon(p.icon, color: p.color, size: 20),
              ),
              title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(p.approx ? '${p.sub} · уточнить точку' : p.sub,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: p.approx ? const Color(0xFFD97A00) : null)),
              trailing: p.chip ? const Icon(Icons.push_pin_outlined, size: 18) : null,
              onTap: fromDb ? () => _open(p) : null,
            ),
        ],
      ),
    );

    final editor = _edit == null
        ? null
        : _panel(context, _editorForm(context));

    if (wide) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 380,
              child: SingleChildScrollView(child: editor ?? listPanel),
            ),
            const SizedBox(width: 16),
            Expanded(child: map),
          ],
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        SizedBox(height: 360, child: map),
        const SizedBox(height: 12),
        editor ?? listPanel,
      ],
    );
  }

  Widget _panel(BuildContext context, Widget child) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.paper,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: context.lineC),
        ),
        child: child,
      );

  Widget _editorForm(BuildContext context) {
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
              tooltip: 'К списку',
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => setState(() => _edit = null),
            ),
            Expanded(
              child: Text(_isNew ? 'Новое место' : 'Изменить место',
                  style: TextStyle(
                    color: context.ink, fontSize: 20, fontWeight: FontWeight.w800,
                  )),
            ),
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
            'Двигайте карту справа, чтобы булавка стояла точно на месте. '
            'Точка сохранится вместе с остальным.',
            style: TextStyle(color: context.ink, fontSize: 13.5, height: 1.4),
          ),
        ),
        if (_approx)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('Сейчас точка примерная — передвиньте и сохраните.',
                style: TextStyle(color: const Color(0xFFD97A00), fontSize: 13.5)),
          ),
        TextField(
          controller: _name,
          onChanged: (_) => setState(() {}),
          decoration: deco('Название, например: Магазин «Айгуль»'),
        ),
        const SizedBox(height: 10),
        TextField(controller: _sub, decoration: deco('Подпись: адрес или уточнение')),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: _category,
          decoration: deco('Тип'),
          items: [
            for (final e in placeCategories.entries)
              DropdownMenuItem(
                value: e.key,
                child: Row(children: [
                  Icon(e.value.icon, color: e.value.color, size: 18),
                  const SizedBox(width: 8),
                  Text(e.value.label),
                ]),
              ),
          ],
          onChanged: (v) => setState(() => _category = v ?? 'other'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _syn,
          decoration: deco('Другие названия через запятую: аурухана, больничка'),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Кнопка под «Куда едем?»'),
          subtitle: const Text('Быстрый выбор на главном экране'),
          value: _chip,
          onChanged: (v) => setState(() => _chip = v),
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
        if (!_isNew) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _busy ? null : _delete,
            icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFD93F44)),
            label: const Text('Удалить', style: TextStyle(color: Color(0xFFD93F44))),
          ),
        ],
      ],
    );
  }
}
