import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/trips.dart';
import '../services/sound.dart';
import '../state.dart';
import '../theme.dart';

const _weekdays = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

String _dayTitle(String key) {
  final p = key.split('-');
  if (p.length != 3) return key;
  final d = DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
  final today = DateTime.now();
  final t0 = DateTime(today.year, today.month, today.day);
  final diff = d.difference(t0).inDays;
  final name = diff == 0 ? 'Сегодня' : diff == 1 ? 'Завтра' : _weekdays[d.weekday - 1];
  return '$name, ${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}';
}

/// Рейсы водителя между районами: создать рейс, видеть брони и посылки.
class DriverTripsScreen extends StatefulWidget {
  const DriverTripsScreen({super.key});
  @override
  State<DriverTripsScreen> createState() => _DriverTripsScreenState();
}

class _DriverTripsScreenState extends State<DriverTripsScreen> {
  late final Stream<List<Trip>> _mine =
      context.read<AppState>().trips.watchDriver(context.read<AppState>().uid ?? '');
  int _seen = -1;

  int _bookings(List<Trip> list) =>
      list.fold(0, (s, t) => s + t.seats.length + (t.whole == null ? 0 : 1) + t.parcels.length);

  Future<void> _create() async {
    final state = context.read<AppState>();
    final others = state.regions.where((r) => r.id != state.regionId).toList();
    if (others.isEmpty) return;
    var to = others.first.id;
    var day = 0;
    TimeOfDay time = const TimeOfDay(hour: 8, minute: 0);
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Новый рейс', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                Text('${state.region.name} →', style: const TextStyle(fontSize: 15)),
                DropdownButton<String>(
                  value: to,
                  isExpanded: true,
                  items: [for (final r in others) DropdownMenuItem(value: r.id, child: Text(r.name))],
                  onChanged: (v) => setSt(() => to = v ?? to),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (var i = 0; i < 7; i++)
                      ChoiceChip(
                        label: Text(_dayTitle(dateKey(DateTime.now().add(Duration(days: i))))),
                        selected: day == i,
                        onSelected: (_) => setSt(() => day = i),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    final t = await showTimePicker(context: ctx, initialTime: time);
                    if (t != null) setSt(() => time = t);
                  },
                  icon: const Icon(Icons.schedule_rounded),
                  label: Text('Время выезда: ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}'),
                ),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                  child: const Text('Создать рейс'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (ok != true) return;
    final d = state.myDriver;
    await state.trips.create(Trip(
      id: '',
      driverId: state.uid ?? '',
      driverName: (d?.name.isNotEmpty ?? false) ? d!.name : state.userName,
      driverPhone: FirebaseAuth.instance.currentUser?.phoneNumber ?? '',
      car: d?.car ?? '',
      plate: d?.plate ?? '',
      from: state.regionId,
      to: to,
      date: dateKey(DateTime.now().add(Duration(days: day))),
      time: '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
      seatPrice: state.settings.seatPrice,
      wholePrice: state.settings.wholeCarPrice,
    ));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Рейс создан. Клиенты уже видят его.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    String name(String id) =>
        state.allRegions.where((r) => r.id == id).map((r) => r.name).firstOrNull ?? id;
    return Scaffold(
      backgroundColor: context.bg,
      appBar: AppBar(title: const Text('Мои рейсы')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        backgroundColor: context.taxi,
        foregroundColor: context.onTaxi,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Новый рейс'),
      ),
      body: StreamBuilder<List<Trip>>(
        stream: _mine,
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('Ошибка: ${snap.error}'));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final today = dateKey(DateTime.now());
          final list = snap.data!.where((t) => t.date.compareTo(today) >= 0).toList();
          // Новая бронь или посылка — сигнал водителю.
          final count = _bookings(list);
          if (_seen >= 0 && count > _seen) playAlert();
          _seen = count;
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text('Рейсов нет. Нажмите «Новый рейс», чтобы клиенты могли бронировать места.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.muted, fontSize: 15, height: 1.5)),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final t = list[i];
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.paper,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: context.lineC),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text('${_dayTitle(t.date)} · ${t.time}',
                              style: TextStyle(color: context.ink, fontSize: 18, fontWeight: FontWeight.w800)),
                        ),
                        TextButton(
                          onPressed: () async {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Отменить рейс?'),
                                content: const Text('Позвоните пассажирам — они увидят, что рейса нет.'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Нет')),
                                  TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Отменить')),
                                ],
                              ),
                            );
                            if (ok == true) await state.trips.cancel(t.id);
                          },
                          child: Text('Отменить', style: TextStyle(color: context.danger)),
                        ),
                      ],
                    ),
                    Text('${name(t.from)} → ${name(t.to)}', style: TextStyle(color: context.muted)),
                    const SizedBox(height: 10),
                    if (t.whole != null)
                      _row(context, Icons.local_taxi_rounded, 'Вся машина: ${t.whole!.name}', t.whole!.phone)
                    else ...[
                      for (var n = 1; n <= Trip.seatCount; n++)
                        _row(
                          context,
                          t.seats[n] == null ? Icons.event_seat_outlined : Icons.person_rounded,
                          t.seats[n] == null ? 'Место $n — свободно' : 'Место $n: ${t.seats[n]!.name}',
                          t.seats[n]?.phone ?? '',
                        ),
                    ],
                    if (t.parcels.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text('Посылки', style: TextStyle(color: context.ink, fontWeight: FontWeight.w700)),
                      for (final p in t.parcels)
                        _row(context, Icons.inventory_2_outlined,
                            '${p.what} — от ${p.senderName} ${p.senderPhone}',
                            'получит ${p.toName} ${p.toPhone}'),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _row(BuildContext context, IconData icon, String title, String sub) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: context.muted),
            const SizedBox(width: 8),
            Expanded(
              child: SelectableText(sub.isEmpty ? title : '$title · $sub',
                  style: TextStyle(color: context.ink, fontSize: 14)),
            ),
          ],
        ),
      );
}
