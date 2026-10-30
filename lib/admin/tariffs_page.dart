import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../data/settings.dart';
import '../state.dart';
import '../theme.dart';

class TariffsPage extends StatefulWidget {
  const TariffsPage({super.key});
  @override
  State<TariffsPage> createState() => _TariffsPageState();
}

typedef _Field = (String key, String title, String hint, String unit);

const _priceFields = <_Field>[
  ('localPrice', 'Поездка по посёлку', 'Обычная цена', '₸'),
  ('farMeters', 'Дальняя поездка — от', 'Длина маршрута по дорогам', 'м'),
  ('farPrice', 'Дальняя поездка', 'Если маршрут длиннее порога выше', '₸'),
  ('kppPrice', 'Таможня · КПП', 'Туда или оттуда', '₸'),
  ('seatPrice', 'Межгород: место', 'Если у направления нет своей цены', '₸'),
  ('wholeCarPrice', 'Межгород: вся машина', 'Если у направления нет своей цены', '₸'),
  ('deliveryPrice', 'Доставка по посёлку', 'Без стоимости покупок', '₸'),
  ('cargoPrice', 'Грузовое — ориентир', 'Подсказка водителю при торге', '₸'),
  ('parcelPrice', 'Межгород: посылка', 'Если у направления нет своей цены', '₸'),
];

const _ruleFields = <_Field>[
  ('subscriptionWeek', 'Подписка водителя', 'В неделю', '₸'),
  ('subscriptionMonth', 'Подписка водителя', 'В месяц', '₸'),
  ('offerSeconds', 'Время на ответ водителя', 'Потом заказ уходит следующему', 'сек'),
  ('showAllMinutes', 'Показать всем и менеджеру через', 'Если никто не взял', 'мин'),
  ('freeWaitMinutes', 'Бесплатное ожидание', 'Когда машина на месте', 'мин'),
];

class _TariffsPageState extends State<TariffsPage> {
  final _ctrls = <String, TextEditingController>{};
  TariffSettings? _loaded;
  String? _region;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _fill(TariffSettings s) {
    final m = s.toMap();
    for (final e in m.entries) {
      (_ctrls[e.key] ??= TextEditingController()).text = '${e.value}';
    }
    _loaded = s;
  }

  bool get _dirty {
    final s = _loaded;
    if (s == null) return false;
    final m = s.toMap();
    return m.entries.any((e) => _ctrls[e.key]?.text.trim() != '${e.value}');
  }

  Future<void> _save() async {
    final m = <String, dynamic>{};
    for (final e in _ctrls.entries) {
      final v = int.tryParse(e.value.text.trim());
      if (v == null || v < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Проверьте поля: нужны целые числа')),
        );
        return;
      }
      m[e.key] = v;
    }
    setState(() => _saving = true);
    final s = TariffSettings.fromMap(m);
    try {
      final st = context.read<AppState>();
      await st.catalog.saveSettings(st.regionId, s);
      if (!mounted) return;
      _loaded = s;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сохранено. Приложения уже видят новые цены.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось сохранить: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final settings = st.settings;
    // Сменили район — показываем его цены, даже если поля успели поправить.
    if (_region != st.regionId) {
      _region = st.regionId;
      _loaded = null;
    }
    // Первые данные из базы или чужое сохранение, пока здесь ничего не правили.
    // Поля меняем после кадра: правка контроллера во время build ломает TextField.
    if (_loaded == null || (!_dirty && settings.toMap().toString() != _loaded!.toMap().toString())) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _fill(settings));
      });
    }
    final wide = MediaQuery.of(context).size.width >= 1100;

    final cards = [
      _card(context, 'Цены для клиента', _priceFields),
      _card(context, 'Водители и заказы', _ruleFields),
    ];

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Тарифы · ${context.watch<AppState>().region.name}',
                      style: TextStyle(
                        color: context.ink, fontSize: 28, fontWeight: FontWeight.w800,
                      )),
                  Text('Изменения сразу видны в приложениях клиента и водителя',
                      style: TextStyle(color: context.muted, fontSize: 14)),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save_outlined),
              label: Text(_saving ? 'Сохраняем…' : 'Сохранить'),
              style: FilledButton.styleFrom(
                backgroundColor: context.taxi,
                minimumSize: const Size(140, 52),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: cards[0]),
              const SizedBox(width: 16),
              Expanded(child: cards[1]),
            ],
          )
        else ...[
          cards[0],
          const SizedBox(height: 16),
          cards[1],
        ],
        const SizedBox(height: 16),
        _routesCard(context, st),
      ],
    );
  }

  Widget _routesCard(BuildContext context, AppState st) {
    final others = st.allRegions.where((r) => r.id != st.regionId).toList();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.paper,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.lineC),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Межгород — цены по направлениям',
              style: TextStyle(color: context.ink, fontSize: 18, fontWeight: FontWeight.w800)),
          Text('Из района «${st.region.name}». Цена берётся в момент создания рейса водителем.',
              style: TextStyle(color: context.muted, fontSize: 12.5)),
          const SizedBox(height: 8),
          if (others.isEmpty)
            Text('Других районов пока нет', style: TextStyle(color: context.muted)),
          for (final r in others)
            _RouteRow(
              key: ValueKey('${st.regionId}>${r.id} ${st.settings.routeTo(r.id).toMap()}'),
              from: st.regionId,
              to: r.id,
              name: r.name,
              price: st.settings.routeTo(r.id),
              custom: st.settings.routes.containsKey(r.id),
            ),
        ],
      ),
    );
  }

  Widget _card(BuildContext context, String title, List<_Field> fields) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.paper,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.lineC),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(color: context.ink, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          for (final (key, name, hint, unit) in fields)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: TextStyle(
                              color: context.ink, fontSize: 15, fontWeight: FontWeight.w600,
                            )),
                        Text(hint, style: TextStyle(color: context.muted, fontSize: 12.5)),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 150,
                    child: TextField(
                      controller: _ctrls[key] ??= TextEditingController(),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      textAlign: TextAlign.right,
                      onChanged: (_) => setState(() {}),
                      style: TextStyle(
                        color: context.ink, fontSize: 16, fontWeight: FontWeight.w700,
                      ),
                      decoration: InputDecoration(
                        suffixText: unit,
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
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Одно направление: место, вся машина, посылка + «Сохранить».
class _RouteRow extends StatefulWidget {
  final String from;
  final String to;
  final String name;
  final RoutePrice price;
  final bool custom;
  const _RouteRow({
    super.key,
    required this.from,
    required this.to,
    required this.name,
    required this.price,
    required this.custom,
  });
  @override
  State<_RouteRow> createState() => _RouteRowState();
}

class _RouteRowState extends State<_RouteRow> {
  late final _seat = TextEditingController(text: '${widget.price.seat}');
  late final _whole = TextEditingController(text: '${widget.price.whole}');
  late final _parcel = TextEditingController(text: '${widget.price.parcel}');
  bool _saving = false;

  @override
  void dispose() {
    _seat.dispose();
    _whole.dispose();
    _parcel.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final seat = int.tryParse(_seat.text.trim());
    final whole = int.tryParse(_whole.text.trim());
    final parcel = int.tryParse(_parcel.text.trim());
    final messenger = ScaffoldMessenger.of(context);
    if (seat == null || whole == null || parcel == null) {
      messenger.showSnackBar(const SnackBar(content: Text('Нужны целые числа')));
      return;
    }
    setState(() => _saving = true);
    try {
      await context.read<AppState>().catalog.saveRoutePrice(
          widget.from, widget.to, RoutePrice(seat: seat, whole: whole, parcel: parcel));
      messenger.showSnackBar(SnackBar(content: Text('Цены направления «${widget.name}» сохранены')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Не удалось сохранить: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field(TextEditingController c, String label) => SizedBox(
        width: 130,
        child: TextField(
          controller: c,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textAlign: TextAlign.right,
          style: TextStyle(color: context.ink, fontSize: 16, fontWeight: FontWeight.w700),
          decoration: InputDecoration(
            labelText: label,
            suffixText: '₸',
            isDense: true,
            filled: true,
            fillColor: context.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 200,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('→ ${widget.name}',
                    style: TextStyle(color: context.ink, fontSize: 15, fontWeight: FontWeight.w700)),
                Text(widget.custom ? 'своя цена' : 'общая цена района',
                    style: TextStyle(color: context.muted, fontSize: 12.5)),
              ],
            ),
          ),
          _field(_seat, 'Место'),
          _field(_whole, 'Вся машина'),
          _field(_parcel, 'Посылка'),
          FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(backgroundColor: context.taxi, minimumSize: const Size(110, 48)),
            child: Text(_saving ? '…' : 'Сохранить'),
          ),
        ],
      ),
    );
  }
}
