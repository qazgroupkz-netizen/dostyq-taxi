import '../trips.dart';
import 'sb_client.dart';

class SupabaseTripRepository implements TripRepository {
  static Trip _trip(Map<String, dynamic> m) {
    final seats = <int, TripBooking>{};
    final rawSeats = m['seats'];
    if (rawSeats is Map) {
      for (final e in rawSeats.entries) {
        final n = int.tryParse('${e.key}');
        final b = TripBooking.fromMap(e.value);
        if (n != null && b != null) seats[n] = b;
      }
    }
    final parcels = <Parcel>[];
    final rawParcels = m['parcels'];
    if (rawParcels is Map) {
      for (final e in rawParcels.entries) {
        final p = e.value;
        if (p is! Map) continue;
        parcels.add(Parcel(
          id: '${e.key}',
          clientId: p['clientId'] as String? ?? '',
          senderName: p['senderName'] as String? ?? '',
          senderPhone: p['senderPhone'] as String? ?? '',
          what: p['what'] as String? ?? '',
          toName: p['toName'] as String? ?? '',
          toPhone: p['toPhone'] as String? ?? '',
          price: (p['price'] as num?)?.toInt() ?? 0,
        ));
      }
    }
    return Trip(
      id: m['id'] as String,
      driverId: m['driver_id'] as String? ?? '',
      driverName: m['driver_name'] as String? ?? '',
      driverPhone: m['driver_phone'] as String? ?? '',
      car: m['car'] as String? ?? '',
      plate: m['plate'] as String? ?? '',
      from: m['from_region'] as String? ?? '',
      to: m['to_region'] as String? ?? '',
      date: m['date'] as String? ?? '',
      time: m['time'] as String? ?? '',
      seatPrice: (m['seat_price'] as num?)?.toInt() ?? 0,
      wholePrice: (m['whole_price'] as num?)?.toInt() ?? 0,
      parcelPrice: (m['parcel_price'] as num?)?.toInt() ?? 0,
      status: m['status'] as String? ?? 'open',
      seats: seats,
      whole: TripBooking.fromMap(m['whole']),
      parcels: parcels,
    );
  }

  static List<Trip> _sorted(List<Map<String, dynamic>> rows) {
    final list = rows.map(_trip).where((t) => t.status != 'cancelled').toList();
    list.sort((a, b) => '${a.date} ${a.time}'.compareTo('${b.date} ${b.time}'));
    return list;
  }

  // Realtime фильтрует только по одному полю — дату и направление проверяем здесь.
  @override
  Stream<List<Trip>> watchDay(String route, String date) {
    final parts = route.split('>');
    return sb
        .from('trips')
        .stream(primaryKey: ['id'])
        .eq('date', date)
        .map((rows) => _sorted([
              for (final m in rows)
                if (m['from_region'] == parts.first && m['to_region'] == parts.last) m,
            ]));
  }

  @override
  Stream<List<Trip>> watchDriver(String driverId) =>
      sb.from('trips').stream(primaryKey: ['id']).eq('driver_id', driverId).map(_sorted);

  @override
  Stream<List<Trip>> watchFrom(String date) =>
      sb.from('trips').stream(primaryKey: ['id']).gte('date', date).map(_sorted);

  @override
  Future<void> create(Trip t) => sb.from('trips').insert({
        'driver_id': t.driverId,
        'driver_name': t.driverName,
        'driver_phone': t.driverPhone,
        'car': t.car,
        'plate': t.plate,
        'from_region': t.from,
        'to_region': t.to,
        'date': t.date,
        'time': t.time,
        'seat_price': t.seatPrice,
        'whole_price': t.wholePrice,
        'parcel_price': t.parcelPrice,
      });

  @override
  Future<void> cancel(String id) => sb.from('trips').update({'status': 'cancelled'}).eq('id', id);

  @override
  Future<bool> bookSeat(String id, int seat, TripBooking b) async =>
      await sb.rpc('book_seat', params: {
        'p_trip': id,
        'p_seat': seat,
        'p_name': b.name,
        'p_phone': b.phone,
      }) ==
      true;

  @override
  Future<void> cancelSeat(String id, int seat) =>
      sb.rpc('cancel_seat', params: {'p_trip': id, 'p_seat': seat});

  @override
  Future<bool> bookWhole(String id, TripBooking b) async =>
      await sb.rpc('book_whole', params: {'p_trip': id, 'p_name': b.name, 'p_phone': b.phone}) ==
      true;

  @override
  Future<void> cancelWhole(String id) => sb.rpc('cancel_whole', params: {'p_trip': id});

  // Номер посылки и её цену назначает сервер (цена — из рейса).
  @override
  Future<void> addParcel(String id, Parcel p) => sb.rpc('add_parcel', params: {
        'p_trip': id,
        'p_sender_name': p.senderName,
        'p_sender_phone': p.senderPhone,
        'p_what': p.what,
        'p_to_name': p.toName,
        'p_to_phone': p.toPhone,
      });

  @override
  Future<void> removeParcel(String id, String parcelId) =>
      sb.rpc('remove_parcel', params: {'p_trip': id, 'p_parcel': parcelId});
}
