import '../data/auth.dart';
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
      phone: authRepo.current?.phone ?? '',
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

enum _SeatKind { free, taken, mine, picked, driver }

/// Машина сверху: капот впереди, водитель с рулём и место 1, сзади места 2–4.
class _SeatMap extends StatelessWidget {
  final Trip trip;
  final String uid;
  final int? picked;
  final ValueChanged<int>? onPick;
  const _SeatMap({required this.trip, required this.uid, required this.picked, this.onPick});

  static const _w = 220.0;
  static const _h = 340.0;

  _SeatKind _kind(int n) {
    final b = trip.seats[n];
    if (b?.clientId == uid) return _SeatKind.mine;
    if (b != null || trip.whole != null) return _SeatKind.taken;
    return picked == n ? _SeatKind.picked : _SeatKind.free;
  }

  Widget _seat(BuildContext context, int n, double left, double top) {
    final k = _kind(n);
    final tappable = (k == _SeatKind.free || k == _SeatKind.picked) && onPick != null;
    return Positioned(
      left: left,
      top: top,
      child: Semantics(
        button: tappable,
        label: trf('Место № {n}', {'n': n}),
        child: GestureDetector(
          onTap: tappable ? () => onPick!(n) : null,
          child: _SeatTile(kind: k, label: k == _SeatKind.mine ? tr('Вы') : '$n'),
        ),
      ),
    );
  }

  Widget _legend(BuildContext context, _SeatKind k, String text) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: _SeatTile.fill(context, k),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: _SeatTile.edge(context, k), width: 1.5),
            ),
          ),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(color: context.muted, fontSize: 13)),
        ],
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: context.bg,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        children: [
          Text(tr('Перед машины'), style: TextStyle(color: context.muted, fontSize: 12)),
          Icon(Icons.keyboard_arrow_up_rounded, color: context.muted, size: 18),
          SizedBox(
            width: _w,
            height: _h,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _CarPainter(
                      body: context.surface,
                      line: context.lineC,
                      glass: context.ink.withOpacity(.10),
                      wheel: context.ink,
                    ),
                  ),
                ),
                // Водитель: руль перед креслом.
                Positioned(
                  left: 48,
                  top: 128,
                  child: CustomPaint(size: const Size(40, 14), painter: _WheelPainter(context.ink)),
                ),
                const Positioned(
                  left: 42,
                  top: 146,
                  child: _SeatTile(kind: _SeatKind.driver, label: ''),
                ),
                _seat(context, 1, 122, 146),
                _seat(context, 2, 30, 226),
                _seat(context, 3, 85, 226),
                _seat(context, 4, 140, 226),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              _legend(context, _SeatKind.free, tr('Свободно')),
              _legend(context, _SeatKind.taken, tr('Занято')),
              _legend(context, _SeatKind.mine, tr('Ваше место')),
            ],
          ),
        ],
      ),
    );
  }
}

/// Кресло сверху: спинка и сиденье, внутри номер места, «Вы» или значок.
class _SeatTile extends StatelessWidget {
  final _SeatKind kind;
  final String label;
  const _SeatTile({required this.kind, required this.label});

  static Color fill(BuildContext c, _SeatKind k) => switch (k) {
        _SeatKind.free => c.paper,
        _SeatKind.taken || _SeatKind.driver => c.line2C,
        _SeatKind.mine || _SeatKind.picked => c.taxi,
      };

  static Color edge(BuildContext c, _SeatKind k) => switch (k) {
        _SeatKind.free => c.lineC,
        _SeatKind.picked => c.ink,
        _SeatKind.mine => c.taxi,
        _SeatKind.taken || _SeatKind.driver => c.line2C,
      };

  @override
  Widget build(BuildContext context) {
    final onYellow = kind == _SeatKind.mine || kind == _SeatKind.picked;
    final fg = onYellow ? context.onTaxi : kind == _SeatKind.free ? context.ink : context.muted;
    final Widget inner = switch (kind) {
      _SeatKind.driver => Text(tr('Водитель'), style: TextStyle(color: fg, fontSize: 9.5, fontWeight: FontWeight.w600)),
      _SeatKind.taken => Icon(Icons.person_rounded, color: fg, size: 22),
      _SeatKind.picked => Icon(Icons.check_rounded, color: fg, size: 24),
      _ => Text(label, style: TextStyle(color: fg, fontSize: 18, fontWeight: FontWeight.w800)),
    };
    return SizedBox(
      width: 50,
      height: 64,
      child: CustomPaint(
        painter: _SeatPainter(fill(context, kind), edge(context, kind)),
        child: Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Center(child: inner),
        ),
      ),
    );
  }
}

class _SeatPainter extends CustomPainter {
  final Color fill;
  final Color edge;
  _SeatPainter(this.fill, this.edge);

  @override
  void paint(Canvas canvas, Size s) {
    final f = Paint()..color = fill;
    final e = Paint()
      ..color = edge
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    // Спинка сзади (внизу схемы), сиденье впереди.
    final back = RRect.fromRectAndRadius(Rect.fromLTWH(3, s.height - 14, s.width - 6, 12), const Radius.circular(6));
    final seat = RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, s.width, s.height - 12), const Radius.circular(12));
    canvas.drawRRect(back, f);
    canvas.drawRRect(back, e);
    canvas.drawRRect(seat, f);
    canvas.drawRRect(seat, e);
  }

  @override
  bool shouldRepaint(_SeatPainter old) => old.fill != fill || old.edge != edge;
}

class _WheelPainter extends CustomPainter {
  final Color color;
  _WheelPainter(this.color);

  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawRRect(RRect.fromRectAndRadius(Offset.zero & s, Radius.circular(s.height / 2)), p);
    canvas.drawLine(Offset(s.width / 2, 2), Offset(s.width / 2, s.height - 2), p);
  }

  @override
  bool shouldRepaint(_WheelPainter old) => old.color != color;
}

/// Кузов сверху: капот, лобовое и заднее стекло, зеркала, колёса.
class _CarPainter extends CustomPainter {
  final Color body;
  final Color line;
  final Color glass;
  final Color wheel;
  _CarPainter({required this.body, required this.line, required this.glass, required this.wheel});

  @override
  void paint(Canvas canvas, Size s) {
    final w = Paint()..color = wheel;
    for (final y in [62.0, 262.0]) {
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(8, y, 16, 46), const Radius.circular(6)), w);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(s.width - 24, y, 16, 46), const Radius.circular(6)), w);
    }
    final mirror = Paint()..color = line;
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(4, 118, 18, 10), const Radius.circular(5)), mirror);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(s.width - 22, 118, 18, 10), const Radius.circular(5)), mirror);

    final car = RRect.fromRectAndCorners(
      Rect.fromLTWH(18, 4, s.width - 36, s.height - 8),
      topLeft: const Radius.circular(58),
      topRight: const Radius.circular(58),
      bottomLeft: const Radius.circular(38),
      bottomRight: const Radius.circular(38),
    );
    canvas.drawRRect(car, Paint()..color = body);
    canvas.drawRRect(
      car,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    final g = Paint()..color = glass;
    final windshield = Path()
      ..moveTo(44, 120)
      ..quadraticBezierTo(s.width / 2, 86, s.width - 44, 120)
      ..lineTo(s.width - 52, 98)
      ..quadraticBezierTo(s.width / 2, 72, 52, 98)
      ..close();
    canvas.drawPath(windshield, g);
    final rear = Path()
      ..moveTo(48, 302)
      ..quadraticBezierTo(s.width / 2, 314, s.width - 48, 302)
      ..lineTo(s.width - 54, 318)
      ..quadraticBezierTo(s.width / 2, 328, 54, 318)
      ..close();
    canvas.drawPath(rear, g);
    // Линия капота.
    canvas.drawLine(
      Offset(s.width / 2, 18),
      Offset(s.width / 2, 66),
      Paint()
        ..color = line
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_CarPainter old) =>
      old.body != body || old.line != line || old.glass != glass || old.wheel != wheel;
}
