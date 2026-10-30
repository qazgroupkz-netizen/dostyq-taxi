import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/orders.dart';
import '../state.dart';
import '../theme.dart';
import 'order_ui.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});
  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  Stream<List<TaxiOrder>>? _orders;
  String? _region;
  bool _todayOnly = true;

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
        final list = snap.data!
            .where((o) => !_todayOnly || (o.createdAt ?? now).isAfter(start))
            .take(200)
            .toList();
        final done = list.where((o) => o.status == 'done').toList();
        final sum = done.fold<int>(0, (s, o) => s + o.price);
        final cancelled = list.where((o) => o.status == 'cancelled').length;

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Заказы · ${state.region.name}',
                      style: TextStyle(color: context.ink, fontSize: 26, fontWeight: FontWeight.w800)),
                ),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('Сегодня')),
                    ButtonSegment(value: false, label: Text('Все')),
                  ],
                  selected: {_todayOnly},
                  onSelectionChanged: (s) => setState(() => _todayOnly = s.first),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _stat(context, 'Всего', '${list.length}'),
                _stat(context, 'Выполнено', '${done.length}'),
                _stat(context, 'Отменено', '$cancelled'),
                _stat(context, 'Сумма выполненных', formatPrice(sum)),
              ],
            ),
            const SizedBox(height: 16),
            if (list.isEmpty)
              Text('Заказов нет', style: TextStyle(color: context.muted, fontSize: 15))
            else
              for (final o in list)
                Padding(padding: const EdgeInsets.only(bottom: 8), child: OrderRow(order: o)),
          ],
        );
      },
    );
  }

  Widget _stat(BuildContext context, String label, String value) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: context.paper,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.lineC),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: context.muted, fontSize: 12.5)),
            Text(value,
                style: TextStyle(color: context.ink, fontSize: 20, fontWeight: FontWeight.w800)),
          ],
        ),
      );
}
