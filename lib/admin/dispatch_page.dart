import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart' show Marker;
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../data/drivers.dart';
import '../data/orders.dart';
import '../data/places.dart';
import '../services/sound.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/taxi_map.dart';
import 'order_ui.dart';

const _active = {'searching', 'accepted', 'arrived', 'riding'};

class DispatchPage extends StatefulWidget {
  const DispatchPage({super.key});
  @override
  State<DispatchPage> createState() => _DispatchPageState();
}

class _DispatchPageState extends State<DispatchPage> {
  late final Stream<List<DriverProfile>> _drivers = context.read<AppState>().drivers.watchAll();
  Stream<List<TaxiOrder>>? _orders;
  String? _region;
  Timer? _tick;
  final _alerted = <String>{};

  @override
  void initState() {
    super.initState();
    // Обновляем «ждёт N мин» и подсвечиваем заказы, которые никто не взял.
    _tick = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  int _waited(TaxiOrder o) =>
      o.createdAt == null ? 0 : DateTime.now().difference(o.createdAt!).inMinutes;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (_region != state.regionId) {
      _region = state.regionId;
      _orders = state.orders.watchRegion(state.regionId);
    }
    final wide = MediaQuery.of(context).size.width >= 1100;

    return StreamBuilder<List<DriverProfile>>(
      stream: _drivers,
      builder: (context, dSnap) {
        final drivers = (dSnap.data ?? const <DriverProfile>[])
            .where((d) => d.region == state.regionId && d.approval == Approval.approved)
            .toList();
        return StreamBuilder<List<TaxiOrder>>(
          stream: _orders,
          builder: (context, oSnap) {
            if (oSnap.hasError) {
              return Center(child: Text('Не удалось загрузить заказы: ${oSnap.error}'));
            }
            final orders = oSnap.data ?? const <TaxiOrder>[];
            final active = orders.where((o) => _active.contains(o.status)).toList();
            final waiting = active.where((o) => o.status == 'searching').toList();
            final overdue = waiting
                .where((o) => _waited(o) >= state.settings.showAllMinutes)
                .toList();
            for (final o in overdue) {
              if (_alerted.add(o.id)) playAlert();
            }
            final online = drivers.where((d) => d.online && d.lat != null).toList();

            final left = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _CallOrderForm(),
                const SizedBox(height: 16),
                _section(
                  context,
                  'Ждут водителя (${waiting.length})',
                  overdue.isEmpty
                      ? 'Через ${state.settings.showAllMinutes} мин без водителя заказ подсвечивается красным'
                      : 'Красные — никто не взял за ${state.settings.showAllMinutes} мин. Позвоните водителю и назначьте',
                  [
                    for (final o in waiting)
                      OrderRow(
                        order: o,
                        highlight: overdue.contains(o),
                        trailing: Row(
                          children: [
                            Text('ждёт ${_waited(o)} мин',
                                style: TextStyle(color: context.muted, fontSize: 12.5)),
                            const Spacer(),
                            TextButton(
                              onPressed: () => _cancel(context, o),
                              child: Text('Отменить', style: TextStyle(color: context.danger)),
                            ),
                            const SizedBox(width: 4),
                            FilledButton(
                              onPressed: () => _assign(context, o, drivers),
                              style: FilledButton.styleFrom(backgroundColor: context.taxi),
                              child: const Text('Назначить'),
                            ),
                          ],
                        ),
                      ),
                  ],
                  empty: 'Все заказы разобраны',
                ),
              ],
            );

            final map = ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: TaxiMap(
                initialCenter: state.region.center,
                idleCars: [for (final d in online) LatLng(d.lat!, d.lng!)],
                extraMarkers: [
                  for (final o in waiting)
                    if (o.fromLat != null)
                      Marker(
                        point: LatLng(o.fromLat!, o.fromLng!),
                        width: 26, height: 26,
                        child: Container(
                          decoration: BoxDecoration(
                            color: overdue.contains(o) ? context.danger : const Color(0xFFD97A00),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                          ),
                        ),
                      ),
                ],
              ),
            );

            final right = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: 360, child: map),
                const SizedBox(height: 8),
                Text(
                  'На линии: ${online.length} из ${drivers.length} водителей · '
                  'оранжевые точки — заказы ждут, красные — ждут слишком долго',
                  style: TextStyle(color: context.muted, fontSize: 12.5),
                ),
                const SizedBox(height: 16),
                _section(
                  context,
                  'Едут сейчас (${active.length - waiting.length})',
                  null,
                  [
                    for (final o in active.where((o) => o.status != 'searching'))
                      OrderRow(
                        order: o,
                        trailing: Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => _cancel(context, o),
                            child: Text('Отменить', style: TextStyle(color: context.danger)),
                          ),
                        ),
                      ),
                  ],
                  empty: 'Сейчас никто не едет',
                ),
              ],
            );

            if (wide) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 440, child: left),
                    const SizedBox(width: 16),
                    Expanded(child: right),
                  ],
                ),
              );
            }
            return ListView(
              padding: const EdgeInsets.all(12),
              children: [left, const SizedBox(height: 16), right],
            );
          },
        );
      },
    );
  }

  Widget _section(BuildContext context, String title, String? sub, List<Widget> items,
      {required String empty}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.paper,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.lineC),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: TextStyle(color: context.ink, fontSize: 18, fontWeight: FontWeight.w800)),
          if (sub != null)
            Text(sub, style: TextStyle(color: context.muted, fontSize: 13)),
          const SizedBox(height: 10),
          if (items.isEmpty)
            Text(empty, style: TextStyle(color: context.muted, fontSize: 14))
          else
            for (final w in items) Padding(padding: const EdgeInsets.only(bottom: 8), child: w),
        ],
      ),
    );
  }

  Future<void> _cancel(BuildContext context, TaxiOrder o) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Отменить заказ?'),
        content: Text('${o.from} → ${o.to}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Нет')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Отменить')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await context.read<AppState>().orders.setStatus(o.id, 'cancelled');
  }

  Future<void> _assign(BuildContext context, TaxiOrder o, List<DriverProfile> drivers) async {
    final pickup = o.fromLat == null ? null : LatLng(o.fromLat!, o.fromLng!);
    double? dist(DriverProfile d) =>
        pickup == null || d.lat == null ? null : Distance()(pickup, LatLng(d.lat!, d.lng!));
    final list = [...drivers.where((d) => d.canWork)]
      ..sort((a, b) {
        if (a.online != b.online) return a.online ? -1 : 1;
        return (dist(a) ?? 1e9).compareTo(dist(b) ?? 1e9);
      });
    final picked = await showDialog<DriverProfile>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Кому отдать заказ?'),
        children: [
          if (list.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Нет одобренных водителей с активной подпиской в этом районе'),
            ),
          for (final d in list)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, d),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.local_taxi_rounded,
                    color: d.online ? ctx.taxi : ctx.muted),
                title: Text('${d.name} · ${d.plate}'),
                subtitle: Text([
                  d.online ? 'на линии' : 'не на линии',
                  if (dist(d) != null) formatDistance(dist(d)!),
                  d.phone,
                ].join(' · ')),
              ),
            ),
        ],
      ),
    );
    if (picked == null || !context.mounted) return;
    final ok = await context.read<AppState>().orders.accept(
          o.id,
          driverId: picked.uid,
          driverName: picked.name,
          car: picked.car,
          plate: picked.plate,
        );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? 'Заказ передан водителю ${picked.name}. Он увидит его в приложении.'
          : 'Заказ уже взял другой водитель или его отменили'),
    ));
  }
}

/// Заказ по звонку: телефон клиента, откуда, куда — и «Передать водителям».
class _CallOrderForm extends StatefulWidget {
  const _CallOrderForm();
  @override
  State<_CallOrderForm> createState() => _CallOrderFormState();
}

class _CallOrderFormState extends State<_CallOrderForm> {
  final _phone = TextEditingController();
  final _name = TextEditingController();
  final _price = TextEditingController();
  TextEditingController? _fromCtrl;
  TextEditingController? _toCtrl;
  Place? _from;
  Place? _to;
  String _payment = 'cash';
  bool _priceTouched = false;
  bool _sending = false;
  int _formKey = 0;

  @override
  void dispose() {
    _phone.dispose();
    _name.dispose();
    _price.dispose();
    super.dispose();
  }

  int _suggestPrice(AppState state) {
    final s = state.settings;
    if (_from?.category == 'kpp' || _to?.category == 'kpp') return s.kppPrice;
    if (_from != null && _to != null &&
        Distance()(_from!.point, _to!.point) * 1.3 > s.farMeters) {
      return s.farPrice;
    }
    return s.localPrice;
  }

  Future<void> _send() async {
    final state = context.read<AppState>();
    final digits = _phone.text.replaceAll(RegExp(r'\D'), '');
    final from = _fromCtrl?.text.trim() ?? '';
    final to = _toCtrl?.text.trim() ?? '';
    final price = int.tryParse(_price.text.trim()) ?? _suggestPrice(state);
    if (digits.length < 10 || from.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Нужны телефон клиента (10 цифр) и «Откуда»')),
      );
      return;
    }
    setState(() => _sending = true);
    try {
      final fromPlace = _from != null && _from!.name == from ? _from : null;
      final toPlace = _to != null && _to!.name == to ? _to : null;
      await state.orders.create(
        clientId: 'manager:${state.uid}',
        clientName: _name.text.trim().isEmpty ? 'Клиент по звонку' : _name.text.trim(),
        clientPhone: '+7${digits.substring(digits.length - 10)}',
        from: from,
        fromGeo: fromPlace == null
            ? null
            : (lat: fromPlace.point.latitude, lng: fromPlace.point.longitude),
        to: to,
        toGeo: toPlace == null
            ? null
            : (lat: toPlace.point.latitude, lng: toPlace.point.longitude),
        region: state.regionId,
        tariff: 'local',
        price: price,
        payment: _payment,
        createdBy: 'manager',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заявка передана водителям. Ищем машину.')),
      );
      setState(() {
        _phone.clear();
        _name.clear();
        _price.clear();
        _from = null;
        _to = null;
        _priceTouched = false;
        _formKey++; // пересоздаём поля «Откуда/Куда»
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Не удалось: $e')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  InputDecoration _deco(BuildContext context, String label, {String? prefix}) => InputDecoration(
        labelText: label,
        prefixText: prefix,
        isDense: true,
        filled: true,
        fillColor: context.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      );

  Widget _placeField(BuildContext context, String label, bool isFrom) {
    final places = context.watch<AppState>().places;
    return Autocomplete<Place>(
      key: ValueKey('$label$_formKey'),
      displayStringForOption: (p) => p.name,
      optionsBuilder: (v) {
        final q = v.text.trim();
        if (q.isEmpty) return places;
        return searchPlaces(q, places);
      },
      onSelected: (p) => setState(() {
        if (isFrom) {
          _from = p;
        } else {
          _to = p;
        }
        if (!_priceTouched) {
          _price.text = '${_suggestPrice(context.read<AppState>())}';
        }
      }),
      fieldViewBuilder: (context, ctrl, focus, onSubmit) {
        if (isFrom) {
          _fromCtrl = ctrl;
        } else {
          _toCtrl = ctrl;
        }
        return TextField(
          controller: ctrl,
          focusNode: focus,
          decoration: _deco(context, label),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (!_priceTouched && _price.text.isEmpty) {
      _price.text = '${_suggestPrice(state)}';
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.paper,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.lineC),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Заказ по звонку',
              style: TextStyle(color: context.ink, fontSize: 18, fontWeight: FontWeight.w800)),
          Text('Клиент позвонил — введите номер, откуда и куда',
              style: TextStyle(color: context.muted, fontSize: 13)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: _deco(context, 'Телефон', prefix: '+7 '),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: _name, decoration: _deco(context, 'Имя (необяз.)'))),
            ],
          ),
          const SizedBox(height: 10),
          _placeField(context, 'Откуда: место или адрес', true),
          const SizedBox(height: 10),
          _placeField(context, 'Куда', false),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _price,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => _priceTouched = true,
                  decoration: _deco(context, 'Цена').copyWith(suffixText: '₸'),
                ),
              ),
              const SizedBox(width: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'cash', label: Text('Наличные')),
                  ButtonSegment(value: 'kaspi', label: Text('Kaspi')),
                ],
                selected: {_payment},
                onSelectionChanged: (s) => setState(() => _payment = s.first),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: _sending ? null : _send,
            style: FilledButton.styleFrom(
              backgroundColor: context.taxi,
              minimumSize: const Size.fromHeight(54),
            ),
            child: Text(_sending ? 'Передаём…' : 'Передать водителям',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
