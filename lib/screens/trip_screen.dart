import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/regions.dart';
import '../data/trips.dart';
import '../i18n.dart';
import '../state.dart';
import '../theme.dart';

// Подписи переводятся при показе: tr(_weekdays[i]).
const _weekdays = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

/// Рейсы между районами: места по одному или вся машина, посылки.
class TripScreen extends StatefulWidget {
  final bool wholeCarMode;
  const TripScreen({super.key, this.wholeCarMode = false});

  @override
  State<TripScreen> createState() => _TripScreenState();
}

class _TripScreenState extends State<TripScreen> {
  int _day = 0;
  String? _to;
  Stream<List<Trip>>? _stream;
  String? _streamKey;

  DateTime get _date => DateTime.now().add(Duration(days: _day));

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final others = state.regions.where((r) => r.id != state.regionId).toList();
    if (others.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(tr('Межгород'))),
        body: Center(child: Text(tr('Пока нет других районов для поездки'))),
      );
    }
    final to = others.any((r) => r.id == _to) ? _to! : others.first.id;
    final toName = others.firstWhere((r) => r.id == to).name;
    final route = '${state.regionId}>$to';
    final key = '$route ${dateKey(_date)}';
    if (_streamKey != key) {
      _streamKey = key;
      _stream = state.trips.watchDay(route, dateKey(_date));
    }
    final s = state.settings.routeTo(to);

    return Scaffold(
      backgroundColor: context.bg,
      appBar: AppBar(
        backgroundColor: context.paper,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.wholeCarMode ? tr('Вся машина') : tr('Рейсы'),
                style: TextStyle(color: context.ink, fontSize: 18, fontWeight: FontWeight.w800)),
            Text(
              widget.wholeCarMode
                  ? '${formatPrice(s.whole)} · ${state.region.name} → $toName'
                  : trf('{price} за место · {from} → {to}', {'price': formatPrice(s.seat), 'from': state.region.name, 'to': toName}),
              style: TextStyle(color: context.muted, fontSize: 13),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Container(
            color: context.paper,
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              children: [
                if (others.length > 1)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final Region r in others)
                          ChoiceChip(
                            label: Text(
                                '${r.name} · ${formatPrice(widget.wholeCarMode ? state.settings.routeTo(r.id).whole : state.settings.routeTo(r.id).seat)}'),
                            selected: r.id == to,
                            showCheckmark: false,
                            selectedColor: context.taxi,
                            labelStyle: TextStyle(
                              color: r.id == to ? context.onTaxi : context.ink,
                              fontWeight: FontWeight.w700,
                            ),
                            onSelected: (_) => setState(() => _to = r.id),
                          ),
                      ],
                    ),
                  ),
                SizedBox(
                  height: 64,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: 7,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final d = DateTime.now().add(Duration(days: i));
                      final sel = i == _day;
                      return GestureDetector(
                        onTap: () => setState(() => _day = i),
                        child: Container(
                          width: 72,
                          decoration: BoxDecoration(
                            color: sel ? context.taxi : context.surface,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                i == 0 ? tr('Сегодня') : i == 1 ? tr('Завтра') : tr(_weekdays[d.weekday - 1]),
                                style: TextStyle(
                                  color: sel ? context.onTaxi : context.muted,
                                  fontSize: 12, fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text('${d.day}',
                                  style: TextStyle(
                                    color: sel ? context.onTaxi : context.ink,
                                    fontSize: 20, fontWeight: FontWeight.w800,
                                  )),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Trip>>(
              stream: _stream,
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(child: Text(trf('Не удалось загрузить рейсы: {e}', {'e': '${snap.error}'})));
                }
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                final trips = snap.data!;
                if (trips.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        tr('На этот день рейсов пока нет.\nВыберите другой день — водители добавляют рейсы заранее.'),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: context.muted, fontSize: 15, height: 1.5),
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: trips.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _TripCard(trip: trips[i], wholeMode: widget.wholeCarMode),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

TripBooking _me(AppState state) => TripBooking(
      clientId: state.uid ?? '',
      name: state.userName,
      phone: FirebaseAuth.instance.currentUser?.phoneNumber ?? '',
    );

class _TripCard extends StatelessWidget {
  final Trip trip;
  final bool wholeMode;
  const _TripCard({required this.trip, required this.wholeMode});

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final uid = state.uid ?? '';
    final mySeat = trip.seatOf(uid);
    final myWhole = trip.whole?.clientId == uid;
    final available = wholeMode ? trip.isEmpty : trip.freeSeats > 0;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _TripSheet(tripId: trip.id, initial: trip, wholeMode: wholeMode),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.paper,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: mySeat != null || myWhole ? context.jLine : context.lineC, width: 1.5),
        ),
        child: Row(
          children: [
            Text(trip.time,
                style: TextStyle(color: context.ink, fontSize: 26, fontWeight: FontWeight.w800)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(trip.driverName,
                      style: TextStyle(color: context.ink, fontSize: 16, fontWeight: FontWeight.w700)),
                  Text('${trip.car} · ${trip.plate}',
                      style: TextStyle(color: context.muted, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(
                    myWhole
                        ? tr('Вы забронировали всю машину')
                        : mySeat != null
                            ? trf('Ваше место № {n}', {'n': mySeat})
                            : trip.whole != null
                                ? tr('Машина занята целиком')
                                : trf('Свободно мест: {free} из {all}', {'free': trip.freeSeats, 'all': Trip.seatCount}),
                    style: TextStyle(
                      color: mySeat != null || myWhole
                          ? context.accent
                          : available ? context.ink2 : context.danger,
                      fontSize: 13.5, fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: context.muted),
          ],
        ),
      ),
    );
  }
}

/// Подробности рейса: схема мест, бронь, вся машина, посылка.
class _TripSheet extends StatefulWidget {
  final String tripId;
  final Trip initial;
  final bool wholeMode;
  const _TripSheet({required this.tripId, required this.initial, required this.wholeMode});

  @override
  State<_TripSheet> createState() => _TripSheetState();
}

class _TripSheetState extends State<_TripSheet> {
  int _parcelPrice(AppState state, Trip t) =>
      t.parcelPrice > 0 ? t.parcelPrice : state.settings.routeTo(t.to).parcel;

  int? _picked;
  bool _busy = false;
  late final Stream<List<Trip>> _day = context
      .read<AppState>()
      .trips
      .watchDay(widget.initial.route, widget.initial.date);

  void _snack(String t) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  Future<void> _run(Future<bool> Function() f, String ok, String fail) async {
    setState(() => _busy = true);
    try {
      final done = await f();
      if (!mounted) return;
      _snack(tr(done ? ok : fail));
      if (done) setState(() => _picked = null);
    } catch (e) {
      if (mounted) _snack(trf('Ошибка: {e}', {'e': e}));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _parcel(Trip t) async {
    final state = context.read<AppState>();
    final what = TextEditingController();
    final toName = TextEditingController();
    final toPhone = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(trf('Передать посылку · {price}', {'price': formatPrice(_parcelPrice(state, t))})),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: what, decoration: InputDecoration(labelText: tr('Что передаёте'))),
              TextField(controller: toName, decoration: InputDecoration(labelText: tr('Кто получит (имя)'))),
              TextField(
                controller: toPhone,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(labelText: tr('Телефон получателя')),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('Отмена'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('Отправить'))),
        ],
      ),
    );
    if (ok != true || what.text.trim().isEmpty || toPhone.text.trim().isEmpty) return;
    final me = _me(state);
    await _run(() async {
      await state.trips.addParcel(
        t.id,
        Parcel(
          id: '${me.clientId}_${DateTime.now().millisecondsSinceEpoch}',
          clientId: me.clientId,
          senderName: me.name,
          senderPhone: me.phone,
          what: what.text.trim(),
          toName: toName.text.trim(),
          toPhone: toPhone.text.trim(),
          price: _parcelPrice(state, t),
        ),
      );
      return true;
    }, 'Посылка добавлена. Водитель заберёт её перед рейсом.', '');
  }

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final uid = state.uid ?? '';
    return StreamBuilder<List<Trip>>(
      stream: _day,
      builder: (context, snap) {
        final t = snap.data?.firstWhere((x) => x.id == widget.tripId, orElse: () => widget.initial) ??
            widget.initial;
        final mySeat = t.seatOf(uid);
        final myWhole = t.whole?.clientId == uid;
        final myParcels = t.parcels.where((p) => p.clientId == uid).toList();

        return Container(
          decoration: BoxDecoration(
            color: context.paper,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).padding.bottom + 16),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('${t.time} · ${t.driverName}',
                    style: TextStyle(color: context.ink, fontSize: 22, fontWeight: FontWeight.w800)),
                Text('${t.car} · ${t.plate}', style: TextStyle(color: context.muted, fontSize: 14)),
                if (mySeat != null || myWhole)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: SelectableText(trf('Телефон водителя: {phone}', {'phone': t.driverPhone}),
                        style: TextStyle(color: context.ink, fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                const SizedBox(height: 16),
                if (!widget.wholeMode) ...[
                  _SeatMap(
                    trip: t,
                    uid: uid,
                    picked: _picked,
                    onPick: mySeat == null && t.whole == null
                        ? (n) => setState(() => _picked = _picked == n ? null : n)
                        : null,
                  ),
                  const SizedBox(height: 16),
                ],
                if (myWhole)
                  OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () => _run(() async {
                              await state.trips.cancelWhole(t.id);
                              return true;
                            }, 'Бронь машины отменена', ''),
                    child: Text(tr('Отменить бронь всей машины')),
                  )
                else if (mySeat != null)
                  OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () => _run(() async {
                              await state.trips.cancelSeat(t.id, mySeat);
                              return true;
                            }, 'Бронь места отменена', ''),
                    child: Text(trf('Отменить бронь места № {n}', {'n': mySeat})),
                  )
                else if (widget.wholeMode)
                  FilledButton(
                    onPressed: _busy || !t.isEmpty
                        ? null
                        : () => _run(() => state.trips.bookWhole(t.id, _me(state)),
                            'Машина ваша! Водитель позвонит накануне.',
                            'На этот рейс уже есть пассажиры — выберите другой'),
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
                    child: Text(t.isEmpty
                        ? trf('Забронировать всю машину · {price}', {'price': formatPrice(t.wholePrice)})
                        : tr('На рейсе уже есть пассажиры')),
                  )
                else
                  FilledButton(
                    onPressed: _busy || _picked == null
                        ? null
                        : () => _run(() => state.trips.bookSeat(t.id, _picked!, _me(state)),
                            'Место забронировано. Водитель позвонит накануне.',
                            'Это место уже заняли — выберите другое'),
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
                    child: Text(_picked == null
                        ? tr('Нажмите на свободное место')
                        : trf('Забронировать место № {n} · {price}', {'n': _picked!, 'price': formatPrice(t.seatPrice)})),
                  ),
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: _busy ? null : () => _parcel(t),
                  icon: const Icon(Icons.inventory_2_outlined),
                  label: Text(trf('Передать посылку с этим рейсом · {price}', {'price': formatPrice(_parcelPrice(state, t))})),
                ),
                for (final p in myParcels)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.inventory_2_rounded),
                    title: Text(p.what),
                    subtitle: Text(trf('Получит: {name} {phone}', {'name': p.toName, 'phone': p.toPhone}) + (p.price > 0 ? ' · ${formatPrice(p.price)}' : '')),
                    trailing: IconButton(
                      icon: const Icon(Icons.close_rounded),
                      tooltip: tr('Убрать посылку'),
                      onPressed: () => state.trips.removeParcel(t.id, p.id),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Схема машины: водитель и место 1 спереди, места 2–4 сзади.
class _SeatMap extends StatelessWidget {
  final Trip trip;
  final String uid;
  final int? picked;
  final ValueChanged<int>? onPick;
  const _SeatMap({required this.trip, required this.uid, required this.picked, this.onPick});

  Widget _seat(BuildContext context, int n) {
    final b = trip.seats[n];
    final mine = b?.clientId == uid;
    final taken = (b != null && !mine) || trip.whole != null;
    final sel = picked == n;
    final Color bg = mine || sel ? context.taxi : taken ? context.line2C : context.surface;
    return GestureDetector(
      onTap: taken || mine || onPick == null ? null : () => onPick!(n),
      child: Container(
        width: 64, height: 64,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: sel ? context.ink : Colors.transparent, width: 2),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(taken || mine ? Icons.person_rounded : Icons.event_seat_outlined,
                color: mine || sel ? context.onTaxi : context.muted),
            Text(mine ? tr('Вы') : '$n',
                style: TextStyle(
                  color: mine || sel ? context.onTaxi : context.ink,
                  fontWeight: FontWeight.w700,
                )),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.bg,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: context.lineC, width: 2),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  color: context.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.trip_origin_rounded, color: context.muted),
                    Text(tr('Водитель'), style: TextStyle(color: context.muted, fontSize: 10.5)),
                  ],
                ),
              ),
              _seat(context, 1),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [_seat(context, 2), _seat(context, 3), _seat(context, 4)],
          ),
        ],
      ),
    );
  }
}
