import 'package:cloud_firestore/cloud_firestore.dart';

/// Пассажир на месте или клиент, взявший всю машину.
class TripBooking {
  final String clientId;
  final String name;
  final String phone;
  const TripBooking({required this.clientId, required this.name, required this.phone});

  Map<String, Object> toMap() => {'clientId': clientId, 'name': name, 'phone': phone};

  static TripBooking? fromMap(Object? v) {
    if (v is! Map) return null;
    return TripBooking(
      clientId: v['clientId'] as String? ?? '',
      name: v['name'] as String? ?? '',
      phone: v['phone'] as String? ?? '',
    );
  }
}

class Parcel {
  final String id;
  final String clientId;
  final String senderName;
  final String senderPhone;
  final String what;
  final String toName;
  final String toPhone;
  final int price;
  const Parcel({
    required this.id,
    required this.clientId,
    required this.senderName,
    required this.senderPhone,
    required this.what,
    required this.toName,
    required this.toPhone,
    this.price = 0,
  });
}

/// Рейс между районами (например, Достык → Ушарал) с 4 местами.
class Trip {
  static const seatCount = 4;

  final String id;
  final String driverId;
  final String driverName;
  final String driverPhone;
  final String car;
  final String plate;
  final String from;
  final String to;
  final String date; // ГГГГ-ММ-ДД
  final String time; // ЧЧ:ММ
  final int seatPrice;
  final int wholePrice;
  final int parcelPrice;
  final String status; // open / cancelled

  /// Номер места (1..4) → пассажир.
  final Map<int, TripBooking> seats;
  final TripBooking? whole;
  final List<Parcel> parcels;

  const Trip({
    required this.id,
    required this.driverId,
    required this.driverName,
    required this.driverPhone,
    required this.car,
    required this.plate,
    required this.from,
    required this.to,
    required this.date,
    required this.time,
    required this.seatPrice,
    required this.wholePrice,
    this.parcelPrice = 0,
    this.status = 'open',
    this.seats = const {},
    this.whole,
    this.parcels = const [],
  });

  String get route => '$from>$to';
  int get freeSeats => whole != null ? 0 : seatCount - seats.length;
  bool get isEmpty => seats.isEmpty && whole == null;

  int? seatOf(String clientId) {
    for (final e in seats.entries) {
      if (e.value.clientId == clientId) return e.key;
    }
    return null;
  }
}

String dateKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

abstract class TripRepository {
  Stream<List<Trip>> watchDay(String route, String date);
  Stream<List<Trip>> watchDriver(String driverId);

  /// Рейсы с этой даты и позже (для админки).
  Stream<List<Trip>> watchFrom(String date);

  Future<void> create(Trip t);
  Future<void> cancel(String id);

  /// false — место уже заняли или машину взяли целиком.
  Future<bool> bookSeat(String id, int seat, TripBooking b);
  Future<void> cancelSeat(String id, int seat);
  Future<bool> bookWhole(String id, TripBooking b);
  Future<void> cancelWhole(String id);
  Future<void> addParcel(String id, Parcel p);
  Future<void> removeParcel(String id, String parcelId);
}

class FirestoreTripRepository implements TripRepository {
  final _db = FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _trips => _db.collection('trips');

  static Trip _fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? const {};
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
      id: d.id,
      driverId: m['driverId'] as String? ?? '',
      driverName: m['driverName'] as String? ?? '',
      driverPhone: m['driverPhone'] as String? ?? '',
      car: m['car'] as String? ?? '',
      plate: m['plate'] as String? ?? '',
      from: m['from'] as String? ?? '',
      to: m['to'] as String? ?? '',
      date: m['date'] as String? ?? '',
      time: m['time'] as String? ?? '',
      seatPrice: (m['seatPrice'] as num?)?.toInt() ?? 0,
      wholePrice: (m['wholePrice'] as num?)?.toInt() ?? 0,
      parcelPrice: (m['parcelPrice'] as num?)?.toInt() ?? 0,
      status: m['status'] as String? ?? 'open',
      seats: seats,
      whole: TripBooking.fromMap(m['whole']),
      parcels: parcels,
    );
  }

  static List<Trip> _sorted(QuerySnapshot<Map<String, dynamic>> q) {
    final list = q.docs.map(_fromDoc).where((t) => t.status != 'cancelled').toList();
    list.sort((a, b) => '${a.date} ${a.time}'.compareTo('${b.date} ${b.time}'));
    return list;
  }

  @override
  Stream<List<Trip>> watchDay(String route, String date) => _trips
      .where('route', isEqualTo: route)
      .where('date', isEqualTo: date)
      .snapshots()
      .map(_sorted);

  @override
  Stream<List<Trip>> watchDriver(String driverId) =>
      _trips.where('driverId', isEqualTo: driverId).snapshots().map(_sorted);

  @override
  Stream<List<Trip>> watchFrom(String date) =>
      _trips.where('date', isGreaterThanOrEqualTo: date).snapshots().map(_sorted);

  @override
  Future<void> create(Trip t) => _trips.add({
        'driverId': t.driverId,
        'driverName': t.driverName,
        'driverPhone': t.driverPhone,
        'car': t.car,
        'plate': t.plate,
        'from': t.from,
        'to': t.to,
        'route': t.route,
        'date': t.date,
        'time': t.time,
        'seatPrice': t.seatPrice,
        'wholePrice': t.wholePrice,
        'parcelPrice': t.parcelPrice,
        'status': 'open',
        'createdAt': FieldValue.serverTimestamp(),
      });

  @override
  Future<void> cancel(String id) => _trips.doc(id).update({'status': 'cancelled'});

  @override
  Future<bool> bookSeat(String id, int seat, TripBooking b) {
    final ref = _trips.doc(id);
    return _db.runTransaction((tx) async {
      final t = _fromDoc(await tx.get(ref));
      if (t.status != 'open' || t.whole != null || t.seats.containsKey(seat)) return false;
      tx.update(ref, {'seats.$seat': b.toMap()});
      return true;
    });
  }

  @override
  Future<void> cancelSeat(String id, int seat) =>
      _trips.doc(id).update({'seats.$seat': FieldValue.delete()});

  @override
  Future<bool> bookWhole(String id, TripBooking b) {
    final ref = _trips.doc(id);
    return _db.runTransaction((tx) async {
      final t = _fromDoc(await tx.get(ref));
      if (t.status != 'open' || !t.isEmpty) return false;
      tx.update(ref, {'whole': b.toMap()});
      return true;
    });
  }

  @override
  Future<void> cancelWhole(String id) => _trips.doc(id).update({'whole': FieldValue.delete()});

  @override
  Future<void> addParcel(String id, Parcel p) => _trips.doc(id).update({
        'parcels.${p.id}': {
          'clientId': p.clientId,
          'senderName': p.senderName,
          'senderPhone': p.senderPhone,
          'what': p.what,
          'toName': p.toName,
          'toPhone': p.toPhone,
          'price': p.price,
        },
      });

  @override
  Future<void> removeParcel(String id, String parcelId) =>
      _trips.doc(id).update({'parcels.$parcelId': FieldValue.delete()});
}
