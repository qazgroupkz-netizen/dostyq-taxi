import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/trips.dart';
import '../state.dart';
import '../theme.dart';

/// Межгород: рейсы района на ближайшие дни, места и посылки.
class IntercityPage extends StatefulWidget {
  const IntercityPage({super.key});
  @override
  State<IntercityPage> createState() => _IntercityPageState();
}

class _IntercityPageState extends State<IntercityPage> {
  late final Stream<List<Trip>> _trips =
      context.read<AppState>().trips.watchFrom(dateKey(DateTime.now()));

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    String name(String id) =>
        state.allRegions.where((r) => r.id == id).map((r) => r.name).firstOrNull ?? id;
    return StreamBuilder<List<Trip>>(
      stream: _trips,
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('Не удалось загрузить: ${snap.error}'));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final list = snap.data!
            .where((t) => t.from == state.regionId || t.to == state.regionId)
            .toList();
        final seats = list.fold<int>(0, (s, t) => s + (t.whole != null ? Trip.seatCount : t.seats.length));
        final parcels = list.fold<int>(0, (s, t) => s + t.parcels.length);
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('Межгород · ${state.region.name}',
                style: TextStyle(color: context.ink, fontSize: 26, fontWeight: FontWeight.w800)),
            Text('Рейсов: ${list.length} · занято мест: $seats · посылок: $parcels',
                style: TextStyle(color: context.muted, fontSize: 14)),
            const SizedBox(height: 16),
            if (list.isEmpty)
              Text('Рейсов пока нет. Водители создают их в приложении: «Мои рейсы» → «Новый рейс».',
                  style: TextStyle(color: context.muted, fontSize: 15)),
            for (final t in list)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.paper,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: context.lineC),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('${t.date.substring(8)}.${t.date.substring(5, 7)} · ${t.time}',
                            style: TextStyle(color: context.ink, fontSize: 17, fontWeight: FontWeight.w800)),
                        const SizedBox(width: 10),
                        Text('${name(t.from)} → ${name(t.to)}',
                            style: TextStyle(color: context.ink2, fontWeight: FontWeight.w600)),
                        const Spacer(),
                        Text(
                          t.whole != null ? 'вся машина' : 'мест ${t.seats.length} из ${Trip.seatCount}',
                          style: TextStyle(color: context.muted, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    SelectableText('${t.driverName} · ${t.car} · ${t.plate} · ${t.driverPhone}',
                        style: TextStyle(color: context.muted, fontSize: 13)),
                    if (t.whole != null)
                      SelectableText('Вся машина: ${t.whole!.name} ${t.whole!.phone}'),
                    for (final e in t.seats.entries)
                      SelectableText('Место ${e.key}: ${e.value.name} ${e.value.phone}'),
                    for (final p in t.parcels)
                      SelectableText(
                          'Посылка: ${p.what}${p.price > 0 ? ' (${p.price} ₸)' : ''} — от ${p.senderName} ${p.senderPhone}, получит ${p.toName} ${p.toPhone}'),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
