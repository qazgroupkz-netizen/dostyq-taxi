import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/drivers.dart';
import '../data/orders.dart';
import '../state.dart';
import '../theme.dart';

/// Аналитика района: заказы по дням и часам, лучшие водители, подписки.
class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});
  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  Stream<List<TaxiOrder>>? _orders;
  late final Stream<List<DriverProfile>> _drivers = context.read<AppState>().drivers.watchAll();
  String? _region;
  int _days = 7;

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
        final today = DateTime(now.year, now.month, now.day);
        final from = today.subtract(Duration(days: _days - 1));
        final list = snap.data!.where((o) => o.createdAt != null && !o.createdAt!.isBefore(from)).toList();
        final done = list.where((o) => o.status == 'done').toList();
        final cancelled = list.where((o) => o.status == 'cancelled').length;
        final sum = done.fold<int>(0, (s, o) => s + o.price);
        final byManager = list.where((o) => o.createdBy == 'manager').length;

        // Заказы по дням.
        final perDay = List<int>.filled(_days, 0);
        for (final o in list) {
          final d = DateTime(o.createdAt!.year, o.createdAt!.month, o.createdAt!.day);
          final i = d.difference(from).inDays;
          if (i >= 0 && i < _days) perDay[i]++;
        }
        // Заказы по часам — когда нужно больше водителей на линии.
        final perHour = List<int>.filled(24, 0);
        for (final o in list) {
          perHour[o.createdAt!.hour]++;
        }
        // Лучшие водители по выполненным заказам.
        final top = <String, (int, int)>{};
        for (final o in done) {
          final n = o.driverName ?? '—';
          final v = top[n] ?? (0, 0);
          top[n] = (v.$1 + 1, v.$2 + o.price);
        }
        final topList = top.entries.toList()..sort((a, b) => b.value.$1.compareTo(a.value.$1));

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Аналитика · ${state.region.name}',
                      style: TextStyle(color: context.ink, fontSize: 26, fontWeight: FontWeight.w800)),
                ),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 1, label: Text('Сегодня')),
                    ButtonSegment(value: 7, label: Text('7 дней')),
                    ButtonSegment(value: 30, label: Text('30 дней')),
                  ],
                  selected: {_days},
                  onSelectionChanged: (s) => setState(() => _days = s.first),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _stat(context, 'Заказов', '${list.length}'),
                _stat(context, 'Выполнено', '${done.length}'),
                _stat(context, 'Отменено', '$cancelled'),
                _stat(context, 'Выполнено, %',
                    list.isEmpty ? '—' : '${(done.length * 100 / list.length).round()}%'),
                _stat(context, 'Оборот водителей', formatPrice(sum)),
                _stat(context, 'Средний чек', done.isEmpty ? '—' : formatPrice(sum ~/ done.length)),
                _stat(context, 'Через менеджера', '$byManager'),
              ],
            ),
            const SizedBox(height: 16),
            if (_days > 1)
              _card(
                context,
                'Заказы по дням',
                _Bars(
                  values: perDay,
                  label: (i) {
                    final d = from.add(Duration(days: i));
                    return '${d.day}.${d.month.toString().padLeft(2, '0')}';
                  },
                  every: _days > 7 ? 5 : 1,
                ),
              ),
            if (_days > 1) const SizedBox(height: 16),
            _card(context, 'Заказы по часам', _Bars(values: perHour, label: (i) => '$i', every: 3)),
            const SizedBox(height: 16),
            _card(
              context,
              'Лучшие водители',
              topList.isEmpty
                  ? Text('Пока нет выполненных заказов', style: TextStyle(color: context.muted))
                  : Column(
                      children: [
                        for (final e in topList.take(10))
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(e.key,
                                      style: TextStyle(color: context.ink, fontWeight: FontWeight.w600)),
                                ),
                                Text('${e.value.$1} заказ. · ${formatPrice(e.value.$2)}',
                                    style: TextStyle(color: context.muted)),
                              ],
                            ),
                          ),
                      ],
                    ),
            ),
            const SizedBox(height: 16),
            _subscriptions(context, state),
          ],
        );
      },
    );
  }

  /// Финансы сервиса — подписки водителей района.
  Widget _subscriptions(BuildContext context, AppState state) => StreamBuilder<List<DriverProfile>>(
        stream: _drivers,
        builder: (context, snap) {
          final all = (snap.data ?? const <DriverProfile>[])
              .where((d) => d.region == state.regionId && d.approval == Approval.approved)
              .toList();
          final active = all.where((d) => d.subscriptionActive).toList();
          final soon = active.where((d) => (d.subscriptionDaysLeft ?? 99) <= 3).toList();
          final expired = all.where((d) => !d.subscriptionActive).toList();
          final month = state.settings.subscriptionMonth;
          return _card(
            context,
            'Подписки водителей',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _stat(context, 'Одобрено водителей', '${all.length}'),
                    _stat(context, 'Подписка активна', '${active.length}'),
                    _stat(context, 'Заканчивается ≤ 3 дн.', '${soon.length}'),
                    _stat(context, 'Закончилась', '${expired.length}'),
                    _stat(context, 'Если все платят помесячно', '${formatPrice(all.length * month)} / мес'),
                  ],
                ),
                if (soon.isNotEmpty || expired.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text('Позвонить и напомнить об оплате:',
                      style: TextStyle(color: context.ink, fontWeight: FontWeight.w700)),
                  for (final d in [...soon, ...expired])
                    SelectableText(
                      '${d.name} · ${d.phone} · '
                      '${d.subscriptionActive ? 'осталось ${d.subscriptionDaysLeft} дн.' : 'закончилась'}',
                      style: TextStyle(color: context.ink2),
                    ),
                ],
              ],
            ),
          );
        },
      );

  Widget _card(BuildContext context, String title, Widget child) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: context.paper,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: context.lineC),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(color: context.ink, fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            child,
          ],
        ),
      );

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
            Text(value, style: TextStyle(color: context.ink, fontSize: 20, fontWeight: FontWeight.w800)),
          ],
        ),
      );
}

/// Простая столбчатая диаграмма: число над столбцом, подпись снизу.
class _Bars extends StatelessWidget {
  final List<int> values;
  final String Function(int i) label;
  final int every;
  const _Bars({required this.values, required this.label, this.every = 1});

  @override
  Widget build(BuildContext context) {
    final max = values.fold<int>(0, (a, b) => a > b ? a : b);
    return SizedBox(
      height: 170,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < values.length; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (values[i] > 0)
                      Text('${values[i]}', style: TextStyle(color: context.muted, fontSize: 11)),
                    Container(
                      height: max == 0 ? 2 : 2 + 120 * values[i] / max,
                      decoration: BoxDecoration(
                        color: values[i] == 0 ? context.lineC : AdminC.yellow,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 14,
                      child: i % every == 0
                          ? FittedBox(
                              child: Text(label(i), style: TextStyle(color: context.muted, fontSize: 11)))
                          : null,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
