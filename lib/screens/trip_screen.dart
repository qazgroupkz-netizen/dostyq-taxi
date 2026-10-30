import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state.dart';
import '../theme.dart';

String _seat(BuildContext c) => formatPrice(c.read<AppState>().settings.seatPrice);
String _whole(BuildContext c) => formatPrice(c.read<AppState>().settings.wholeCarPrice);

// ════════════════════════════════════════════════════════════════
//  Экран рейсов Достык → Ушарал
// ════════════════════════════════════════════════════════════════

class TripScreen extends StatefulWidget {
  /// true = выбор целой машины, false = выбор места
  final bool wholeCarMode;
  const TripScreen({super.key, this.wholeCarMode = false});

  @override
  State<TripScreen> createState() => _TripScreenState();
}

class _TripScreenState extends State<TripScreen> {
  int _dateIndex = 0;
  _MockTrip? _selected;

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: context.bg,
      body: Column(
        children: [
          // ── Шапка
          Container(
            color: context.paper,
            padding: EdgeInsets.fromLTRB(16, topPad + 14, 16, 14),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                      color: context.surface,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.arrow_back_ios_new_rounded,
                        color: context.ink, size: 18),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.wholeCarMode
                            ? 'Вся машина до Ушарала'
                            : 'Рейсы Достык → Ушарал',
                        style: TextStyle(
                          color: context.ink,
                          fontSize: 18, fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        widget.wholeCarMode
                            ? '${_whole(context)} · 160 км'
                            : '${_seat(context)} / место · 160 км',
                        style: TextStyle(color: context.muted, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Даты
          Container(
            color: context.paper,
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
            child: SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemCount: _dates.length,
                itemBuilder: (_, i) {
                  final sel = i == _dateIndex;
                  return GestureDetector(
                    onTap: () => setState(() {
                      _dateIndex = i;
                      _selected = null;
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 10),
                      decoration: BoxDecoration(
                        color: sel ? context.taxi : context.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _dates[i],
                        style: TextStyle(
                          color: sel ? context.onTaxi : context.ink,
                          fontSize: 14, fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          const SizedBox(height: 1),

          // ── Список рейсов
          Expanded(
            child: _selected == null
                ? _TripList(
                    trips: _tripsForDay(_dateIndex),
                    wholeCarMode: widget.wholeCarMode,
                    onSelect: (t) => setState(() => _selected = t),
                  )
                : _SeatPicker(
                    trip: _selected!,
                    wholeCarMode: widget.wholeCarMode,
                    onBack: () => setState(() => _selected = null),
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Список рейсов ────────────────────────────────────────────────
class _TripList extends StatelessWidget {
  final List<_MockTrip> trips;
  final bool wholeCarMode;
  final void Function(_MockTrip) onSelect;
  const _TripList({
    required this.trips,
    required this.wholeCarMode,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    if (trips.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.directions_car_outlined, color: context.muted, size: 48),
            const SizedBox(height: 12),
            Text('Рейсов на этот день нет',
                style: TextStyle(color: context.muted, fontSize: 16)),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemCount: trips.length,
      itemBuilder: (_, i) => _TripCard(
        trip: trips[i],
        wholeCarMode: wholeCarMode,
        onTap: () => onSelect(trips[i]),
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  final _MockTrip trip;
  final bool wholeCarMode;
  final VoidCallback onTap;
  const _TripCard({
    required this.trip,
    required this.wholeCarMode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final free = trip.seats.where((s) => !s).length;
    final isFull = free == 0 && !wholeCarMode;

    return Material(
      color: context.paper,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: isFull ? null : onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Время
              Container(
                width: 64,
                alignment: Alignment.center,
                child: Text(
                  trip.time,
                  style: TextStyle(
                    color: isFull ? context.muted : context.ink,
                    fontSize: 22, fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // Инфо
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(trip.driver,
                        style: TextStyle(
                          color: isFull ? context.muted : context.ink,
                          fontSize: 15, fontWeight: FontWeight.w700,
                        )),
                    const SizedBox(height: 2),
                    Text('${trip.car} · ${trip.plate}',
                        style: TextStyle(
                            color: context.muted, fontSize: 13)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Места
              if (!wholeCarMode)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isFull ? context.surface : context.taxiSft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isFull ? 'Мест нет' : '$free / 4',
                    style: TextStyle(
                      color: isFull ? context.muted : context.accent,
                      fontSize: 14, fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: context.taxiSft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _whole(context),
                    style: TextStyle(
                      color: context.accent,
                      fontSize: 14, fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Выбор места ─────────────────────────────────────────────────
class _SeatPicker extends StatefulWidget {
  final _MockTrip trip;
  final bool wholeCarMode;
  final VoidCallback onBack;
  const _SeatPicker({
    required this.trip,
    required this.wholeCarMode,
    required this.onBack,
  });

  @override
  State<_SeatPicker> createState() => _SeatPickerState();
}

class _SeatPickerState extends State<_SeatPicker> {
  int _pickedSeat = -1;
  bool _booked = false;

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;

    if (_booked) {
      return _BookedSuccess(trip: trip, seat: _pickedSeat,
          wholeCarMode: widget.wholeCarMode);
    }

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              children: [
                // Карточка рейса
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: context.paper,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(trip.time,
                              style: TextStyle(
                                color: context.ink,
                                fontSize: 26, fontWeight: FontWeight.w800,
                              )),
                          Text('Достык → Ушарал',
                              style: TextStyle(
                                  color: context.muted, fontSize: 14)),
                        ],
                      ),
                      const Spacer(),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(trip.driver,
                              style: TextStyle(
                                color: context.ink,
                                fontSize: 15, fontWeight: FontWeight.w700,
                              )),
                          Text(trip.car,
                              style: TextStyle(
                                  color: context.muted, fontSize: 13)),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Схема машины
                Text(
                  widget.wholeCarMode
                      ? 'Вы занимаете всю машину'
                      : 'Выберите место',
                  style: TextStyle(
                    color: context.ink,
                    fontSize: 16, fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),

                _CarDiagram(
                  seats: trip.seats,
                  picked: _pickedSeat,
                  wholeCarMode: widget.wholeCarMode,
                  onPick: (i) => setState(() => _pickedSeat = i),
                ),
              ],
            ),
          ),
        ),

        // Кнопка
        Padding(
          padding: EdgeInsets.fromLTRB(
              16, 8, 16, MediaQuery.of(context).padding.bottom + 16),
          child: Column(
            children: [
              if (!widget.wholeCarMode && _pickedSeat < 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Нажмите на свободное место',
                    style: TextStyle(color: context.muted, fontSize: 13),
                  ),
                ),
              _BookBtn(
                label: widget.wholeCarMode
                    ? 'Забронировать машину · ${_whole(context)}'
                    : 'Забронировать место · ${_seat(context)}',
                enabled: widget.wholeCarMode || _pickedSeat >= 0,
                onTap: () => setState(() => _booked = true),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Схема машины ─────────────────────────────────────────────────
class _CarDiagram extends StatelessWidget {
  final List<bool> seats;
  final int picked;
  final bool wholeCarMode;
  final void Function(int) onPick;
  const _CarDiagram({
    required this.seats,
    required this.picked,
    required this.wholeCarMode,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    // Машина: ряд водителя (1 место) + 3 пассажирских ряда (место 0,1,2,3)
    // Раскладка: водитель слева-спереди, пассажир спереди (место 0)
    //            сзади: места 1, 2, 3

    return Container(
      width: 220,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.paper,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.lineC),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Нос машины
          Container(
            width: 120, height: 20,
            decoration: BoxDecoration(
              color: context.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(60)),
            ),
          ),
          const SizedBox(height: 10),

          // Ряд 1: водитель + место 0 (переднее)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _SeatCircle(
                label: '🚗',
                isDriver: true,
                booked: false,
                picked: false,
                wholeMode: wholeCarMode,
                onTap: () {},
              ),
              const SizedBox(width: 24),
              _SeatCircle(
                label: '1',
                isDriver: false,
                booked: seats[0],
                picked: picked == 0,
                wholeMode: wholeCarMode,
                onTap: () { if (!seats[0]) onPick(0); },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Разделитель
          Container(height: 1, color: context.lineC),
          const SizedBox(height: 16),

          // Ряд 2: места 1, 2 (задние)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _SeatCircle(
                label: '2',
                isDriver: false,
                booked: seats[1],
                picked: picked == 1,
                wholeMode: wholeCarMode,
                onTap: () { if (!seats[1]) onPick(1); },
              ),
              const SizedBox(width: 24),
              _SeatCircle(
                label: '3',
                isDriver: false,
                booked: seats[2],
                picked: picked == 2,
                wholeMode: wholeCarMode,
                onTap: () { if (!seats[2]) onPick(2); },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Ряд 3: место 3 (по центру сзади)
          _SeatCircle(
            label: '4',
            isDriver: false,
            booked: seats[3],
            picked: picked == 3,
            wholeMode: wholeCarMode,
            onTap: () { if (!seats[3]) onPick(3); },
          ),
          const SizedBox(height: 10),

          // Задний бампер
          Container(
            width: 140, height: 14,
            decoration: BoxDecoration(
              color: context.surface,
              borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SeatCircle extends StatelessWidget {
  final String label;
  final bool isDriver, booked, picked, wholeMode;
  final VoidCallback onTap;
  const _SeatCircle({
    required this.label,
    required this.isDriver,
    required this.booked,
    required this.picked,
    required this.wholeMode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    final bool active = !isDriver && !booked;

    if (isDriver) {
      bg = context.surface;
      fg = context.muted;
    } else if (wholeMode) {
      bg = context.taxiSft;
      fg = context.accent;
    } else if (booked) {
      bg = context.dSoft;
      fg = context.danger;
    } else if (picked) {
      bg = context.taxi;
      fg = context.onTaxi;
    } else {
      bg = context.taxiSft;
      fg = context.accent;
    }

    return GestureDetector(
      onTap: active && !wholeMode ? onTap : null,
      child: Container(
        width: 60, height: 60,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          border: picked && !wholeMode
              ? Border.all(color: context.taxi, width: 3)
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          isDriver ? label : (booked ? '✗' : label),
          style: TextStyle(
            color: fg,
            fontSize: isDriver ? 22 : 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

// ── Подтверждение брони ──────────────────────────────────────────
class _BookedSuccess extends StatelessWidget {
  final _MockTrip trip;
  final int seat;
  final bool wholeCarMode;
  const _BookedSuccess({
    required this.trip,
    required this.seat,
    required this.wholeCarMode,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88, height: 88,
              decoration: BoxDecoration(
                color: context.taxiSft,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_rounded, color: context.accent, size: 44),
            ),
            const SizedBox(height: 20),
            Text(
              wholeCarMode ? 'Машина забронирована!' : 'Место забронировано!',
              style: TextStyle(
                color: context.ink,
                fontSize: 22, fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              wholeCarMode
                  ? '${trip.time} · ${trip.driver}\nСтоимость: ${_whole(context)}'
                  : '${trip.time} · Место ${seat + 1}\n${trip.driver} · ${trip.car}',
              style: TextStyle(
                color: context.muted, fontSize: 15, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: context.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'Оплата наличными водителю\nпри посадке',
                style: TextStyle(
                  color: context.ink, fontSize: 14, height: 1.4),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: _BookBtn(
                label: 'Готово',
                enabled: true,
                onTap: () {
                  // Возвращаемся на главный экран
                  Navigator.of(context).popUntil((r) => r.isFirst);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookBtn extends StatelessWidget {
  final String label;
  final bool enabled;
  final VoidCallback onTap;
  const _BookBtn({required this.label, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.45,
        child: Container(
          height: 58,
          decoration: BoxDecoration(
            color: context.taxi,
            borderRadius: BorderRadius.circular(18),
            boxShadow: enabled ? [
              BoxShadow(
                color: context.taxi.withOpacity(.4),
                blurRadius: 24, offset: const Offset(0, 10),
              ),
            ] : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: context.onTaxi,
              fontSize: 17, fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  Мок-данные рейсов
// ════════════════════════════════════════════════════════════════

class _MockTrip {
  final String time, driver, car, plate;
  final List<bool> seats; // true = занято
  const _MockTrip({
    required this.time,
    required this.driver,
    required this.car,
    required this.plate,
    required this.seats,
  });
}

const _dates = [
  'Сегодня', 'Завтра', '30 окт', '31 окт', '1 ноя', '2 ноя',
];

final _tripsDay0 = [
  _MockTrip(time: '07:00', driver: 'Ерлан А.',
      car: 'Toyota Camry', plate: '045 AKZ 18',
      seats: [false, false, false, false]),
  _MockTrip(time: '09:30', driver: 'Марат С.',
      car: 'Hyundai Sonata', plate: '123 AKZ 18',
      seats: [true, false, false, true]),
  _MockTrip(time: '12:00', driver: 'Дамир К.',
      car: 'Kia K5', plate: '456 AKZ 18',
      seats: [true, true, false, false]),
  _MockTrip(time: '15:00', driver: 'Асхат Н.',
      car: 'Toyota Camry', plate: '789 AKZ 18',
      seats: [false, false, false, false]),
  _MockTrip(time: '18:00', driver: 'Рустем О.',
      car: 'Hyundai Elantra', plate: '012 AKZ 18',
      seats: [true, false, true, false]),
];

final _tripsDay1 = [
  _MockTrip(time: '08:00', driver: 'Ерлан А.',
      car: 'Toyota Camry', plate: '045 AKZ 18',
      seats: [false, false, false, false]),
  _MockTrip(time: '14:00', driver: 'Нурлан Б.',
      car: 'Toyota Corolla', plate: '321 AKZ 18',
      seats: [true, true, true, false]),
  _MockTrip(time: '17:30', driver: 'Марат С.',
      car: 'Hyundai Sonata', plate: '123 AKZ 18',
      seats: [false, false, false, false]),
];

final _tripsDay2 = <_MockTrip>[];

List<_MockTrip> _tripsForDay(int i) {
  if (i == 0) return _tripsDay0;
  if (i == 1) return _tripsDay1;
  return _tripsDay2;
}
