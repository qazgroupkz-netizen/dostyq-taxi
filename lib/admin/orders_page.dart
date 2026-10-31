import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/orders.dart';
import '../state.dart';
import '../theme.dart';
import 'admin_ui.dart';
import 'order_ui.dart';

/// Заказы района: фильтр по статусу и периоду, поиск, таблица (на телефоне — карточки).
class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});
  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  Stream<List<TaxiOrder>>? _orders;
  String? _region;
  bool _todayOnly = true;
  String _filter = 'all';
  late final _search = TextEditingController(text: adminSearch.value);
  late String _q = adminSearch.value.trim().toLowerCase();

  // Поиск из шапки: показываем все дни, чтобы нашёлся и старый заказ.
  void _fromHeader() => setState(() {
        _search.text = adminSearch.value;
        _q = adminSearch.value.trim().toLowerCase();
        if (_q.isNotEmpty) _todayOnly = false;
      });

  @override
  void initState() {
    super.initState();
    if (_q.isNotEmpty) _todayOnly = false;
    adminSearch.addListener(_fromHeader);
  }

  @override
  void dispose() {
    adminSearch.removeListener(_fromHeader);
    _search.dispose();
    super.dispose();
  }

  static const _active = {'searching', 'accepted', 'arrived', 'riding'};

  bool _match(TaxiOrder o) {
    final ok = switch (_filter) {
      'active' => _active.contains(o.status),
      'done' => o.status == 'done',
      'cancelled' => o.status == 'cancelled',
      _ => true,
    };
    if (!ok) return false;
    if (_q.isEmpty) return true;
    final hay = [shortNo(o), o.from, o.to, o.driverName ?? '', o.driverPlate ?? '', o.clientName, o.clientPhone]
        .join(' ')
        .toLowerCase();
    return hay.contains(_q);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (_region != state.regionId) {
      _region = state.regionId;
      _orders = state.orders.watchRegion(state.regionId);
    }
    return StreamBuilder<List<TaxiOrder>>(
      stream: _orders,
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('Не удалось загрузить: ${snap.error}'));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final now = DateTime.now();
        final start = DateTime(now.year, now.month, now.day);
        final period = snap.data!.where((o) => !_todayOnly || (o.createdAt ?? now).isAfter(start)).toList();
        final done = period.where((o) => o.status == 'done').toList();
        final sum = done.fold<int>(0, (s, o) => s + o.price);
        final cancelled = period.where((o) => o.status == 'cancelled').length;
        final list = period.where(_match).take(300).toList();

        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            AdminHead(
              title: 'Заказы',
              sub: '${_todayOnly ? 'Сегодня' : 'Все заказы'} · ${state.region.name}',
              trailing: FilterChips<bool>(
                items: const {true: 'Сегодня', false: 'Все дни'},
                value: _todayOnly,
                onChanged: (v) => setState(() => _todayOnly = v),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _stat(context, 'Всего', '${period.length}'),
                _stat(context, 'Выполнено', '${done.length}'),
                _stat(context, 'Отменено', '$cancelled'),
                _stat(context, 'Сумма выполненных', formatPrice(sum)),
              ],
            ),
            const SizedBox(height: 16),
            AdminCard(
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(18),
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        FilterChips<String>(
                          items: const {
                            'all': 'Все',
                            'active': 'Сейчас',
                            'done': 'Выполнены',
                            'cancelled': 'Отменены',
                          },
                          value: _filter,
                          onChanged: (v) => setState(() => _filter = v),
                        ),
                        SizedBox(
                          width: 320,
                          child: SearchBox(
                            controller: _search,
                            hint: 'Номер, водитель, место, телефон',
                            onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
                          ),
                        ),
                      ],
                    ),
                  ),
                  LayoutBuilder(
                    builder: (context, c) => c.maxWidth >= 900 ? _table(context, list) : _cards(context, list),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _cards(BuildContext context, List<TaxiOrder> list) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        child: list.isEmpty
            ? Text('Ничего не найдено', style: TextStyle(color: context.muted))
            : Column(
                children: [
                  for (final o in list)
                    Padding(padding: const EdgeInsets.only(bottom: 8), child: OrderRow(order: o)),
                ],
              ),
      );

  Widget _table(BuildContext context, List<TaxiOrder> list) {
    final line = BorderSide(color: context.lineC);
    TextStyle t([double size = 13.5, FontWeight w = FontWeight.w500]) =>
        TextStyle(color: context.ink, fontSize: size, fontWeight: w);
    return Table(
      columnWidths: const {
        0: FixedColumnWidth(76),
        1: FixedColumnWidth(118),
        2: FlexColumnWidth(3),
        3: FixedColumnWidth(120),
        4: FlexColumnWidth(2),
        5: FlexColumnWidth(2),
        6: FixedColumnWidth(140),
        7: FixedColumnWidth(100),
        8: FixedColumnWidth(96),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      border: TableBorder(top: line, horizontalInside: line),
      children: [
        TableRow(children: [
          thCell(context, '№'),
          thCell(context, 'Время'),
          thCell(context, 'Маршрут'),
          thCell(context, 'Услуга'),
          thCell(context, 'Клиент'),
          thCell(context, 'Водитель'),
          thCell(context, 'Статус'),
          thCell(context, 'Сумма', right: true),
          thCell(context, 'Оплата'),
        ]),
        if (list.isEmpty)
          TableRow(children: [
            tdCell(Text('Ничего не найдено', style: TextStyle(color: context.muted))),
            for (var i = 0; i < 8; i++) const SizedBox.shrink(),
          ]),
        for (final o in list)
          TableRow(children: [
            tdCell(Text(shortNo(o), style: TextStyle(color: context.muted, fontWeight: FontWeight.w700, fontSize: 13))),
            tdCell(Text(dayTime(o.createdAt), style: t(13))),
            tdCell(Text('${o.from.isEmpty ? '—' : o.from} → ${o.to.isEmpty ? '—' : o.to}',
                maxLines: 2, overflow: TextOverflow.ellipsis, style: t(13.5, FontWeight.w600))),
            tdCell(Text(serviceName(o.tariff), style: t(13))),
            tdCell(SelectableText(
              [o.clientName, o.clientPhone].where((s) => s.isNotEmpty).join('\n'),
              style: TextStyle(color: context.ink2, fontSize: 12.5),
            )),
            tdCell(Text(
              o.driverName == null ? '—' : '${o.driverName}${o.driverPlate == null ? '' : '\n${o.driverPlate}'}',
              style: TextStyle(color: context.ink2, fontSize: 12.5),
            )),
            tdCell(OrderPill(status: o.status)),
            tdCell(Text(o.status == 'cancelled' ? '—' : formatPrice(o.price), style: t(13.5, FontWeight.w700)),
                right: true),
            tdCell(Text(o.payment == 'kaspi' ? 'Kaspi' : 'Наличные', style: t(13))),
          ]),
      ],
    );
  }

  Widget _stat(BuildContext context, String label, String value) => AdminCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: TextStyle(color: context.muted, fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(color: context.ink, fontSize: 22, fontWeight: FontWeight.w800)),
          ],
        ),
      );
}
