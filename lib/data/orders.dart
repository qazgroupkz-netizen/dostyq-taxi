import 'package:cloud_firestore/cloud_firestore.dart';

class TaxiOrder {
  final String id;
  final String status;
  final String clientId;
  final String clientName;
  final String from;
  final double? fromLat;
  final double? fromLng;
  final String to;
  final String tariff;
  final int price;
  final String payment;
  final String? driverId;
  final String? driverName;
  final bool clientComingOut;
  final List<String> declinedBy;
  final DateTime? createdAt;

  const TaxiOrder({
    required this.id,
    required this.status,
    required this.clientId,
    required this.clientName,
    required this.from,
    this.fromLat,
    this.fromLng,
    required this.to,
    required this.tariff,
    required this.price,
    required this.payment,
    this.driverId,
    this.driverName,
    this.clientComingOut = false,
    this.declinedBy = const [],
    this.createdAt,
  });
}

typedef Geo = ({double lat, double lng});

abstract class OrderRepository {
  Future<String> create({
    required String clientId,
    required String clientName,
    required String from,
    Geo? fromGeo,
    required String to,
    Geo? toGeo,
    required String tariff,
    required int price,
    required String payment,
  });

  Stream<TaxiOrder?> watch(String id);

  Stream<List<TaxiOrder>> watchSearching();

  /// false — заказ уже забрал другой водитель или клиент отменил.
  Future<bool> accept(String id, {required String driverId, required String driverName});

  Future<void> setStatus(String id, String status);

  /// Водитель отказался от принятого заказа: заказ снова ищет машину, ему больше не предлагается.
  Future<void> release(String id, String driverId);

  Future<void> update(String id, Map<String, Object?> fields);

  Future<String> userName(String uid);

  Future<void> updateDriverLocation(String uid, Geo geo);

  Future<void> setDriverOnline(String uid, bool online);

  Stream<Geo?> watchDriverLocation(String uid);

  /// Координаты водителей на линии, обновлявшихся за последние 10 минут.
  Stream<List<Geo>> watchOnlineDrivers();
}

class FirestoreOrderRepository implements OrderRepository {
  final _db = FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _orders => _db.collection('orders');

  static TaxiOrder _fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? const {};
    String label(Object? v) => v is Map ? (v['label'] as String? ?? '') : '';
    double? coord(Object? v, String k) =>
        v is Map ? (v[k] as num?)?.toDouble() : null;
    return TaxiOrder(
      id: d.id,
      status: m['status'] as String? ?? 'searching',
      clientId: m['clientId'] as String? ?? '',
      clientName: m['clientName'] as String? ?? '',
      from: label(m['from']),
      fromLat: coord(m['from'], 'lat'),
      fromLng: coord(m['from'], 'lng'),
      to: label(m['to']),
      tariff: m['service'] as String? ?? 'local',
      price: (m['price'] as num?)?.toInt() ?? 0,
      payment: m['payment'] as String? ?? 'cash',
      driverId: m['driverId'] as String?,
      driverName: m['driverName'] as String?,
      clientComingOut: m['clientComingOut'] as bool? ?? false,
      declinedBy: (m['declinedBy'] as List?)?.whereType<String>().toList() ?? const [],
      createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  @override
  Future<String> create({
    required String clientId,
    required String clientName,
    required String from,
    Geo? fromGeo,
    required String to,
    Geo? toGeo,
    required String tariff,
    required int price,
    required String payment,
  }) async {
    final ref = await _orders.add({
      'clientId': clientId,
      'clientName': clientName,
      'from': {
        'label': from,
        if (fromGeo != null) 'lat': fromGeo.lat,
        if (fromGeo != null) 'lng': fromGeo.lng,
      },
      'to': {
        'label': to,
        if (toGeo != null) 'lat': toGeo.lat,
        if (toGeo != null) 'lng': toGeo.lng,
      },
      'service': tariff,
      'price': price,
      'payment': payment,
      'status': 'searching',
      'createdBy': 'app',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  @override
  Stream<TaxiOrder?> watch(String id) =>
      _orders.doc(id).snapshots().map((d) => d.exists ? _fromDoc(d) : null);

  @override
  Stream<List<TaxiOrder>> watchSearching() => _orders
      .where('status', isEqualTo: 'searching')
      .snapshots()
      .map((q) {
        final list = q.docs.map(_fromDoc).toList();
        list.sort((a, b) => (a.createdAt ?? DateTime.now())
            .compareTo(b.createdAt ?? DateTime.now()));
        return list;
      });

  @override
  Future<bool> accept(String id,
      {required String driverId, required String driverName}) {
    final ref = _orders.doc(id);
    return _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (snap.data()?['status'] != 'searching') return false;
      tx.update(ref, {
        'status': 'accepted',
        'driverId': driverId,
        'driverName': driverName,
        'acceptedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    });
  }

  @override
  Future<void> setStatus(String id, String status) => _orders.doc(id).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  @override
  Future<void> release(String id, String driverId) => _orders.doc(id).update({
        'status': 'searching',
        'driverId': FieldValue.delete(),
        'driverName': FieldValue.delete(),
        'clientComingOut': false,
        'declinedBy': FieldValue.arrayUnion([driverId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

  @override
  Future<void> update(String id, Map<String, Object?> fields) =>
      _orders.doc(id).update(fields);

  @override
  Future<String> userName(String uid) async {
    final d = await _db.collection('users').doc(uid).get();
    return d.data()?['name'] as String? ?? '';
  }

  CollectionReference<Map<String, dynamic>> get _drivers => _db.collection('drivers');

  @override
  Future<void> updateDriverLocation(String uid, Geo geo) =>
      _drivers.doc(uid).set({
        'location': {
          'lat': geo.lat,
          'lng': geo.lng,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      }, SetOptions(merge: true));

  @override
  Future<void> setDriverOnline(String uid, bool online) =>
      _drivers.doc(uid).set({'status': online ? 'online' : 'offline'},
          SetOptions(merge: true));

  @override
  Stream<Geo?> watchDriverLocation(String uid) =>
      _drivers.doc(uid).snapshots().map((d) {
        final loc = d.data()?['location'];
        if (loc is! Map) return null;
        final lat = (loc['lat'] as num?)?.toDouble();
        final lng = (loc['lng'] as num?)?.toDouble();
        if (lat == null || lng == null) return null;
        return (lat: lat, lng: lng);
      });

  @override
  Stream<List<Geo>> watchOnlineDrivers() => _drivers
          .where('status', isEqualTo: 'online')
          .snapshots()
          .map((q) {
        final fresh = DateTime.now().subtract(const Duration(minutes: 10));
        final out = <Geo>[];
        for (final d in q.docs) {
          final loc = d.data()['location'];
          if (loc is! Map) continue;
          final at = (loc['updatedAt'] as Timestamp?)?.toDate();
          if (at != null && at.isBefore(fresh)) continue;
          final lat = (loc['lat'] as num?)?.toDouble();
          final lng = (loc['lng'] as num?)?.toDouble();
          if (lat != null && lng != null) out.add((lat: lat, lng: lng));
        }
        return out;
      });
}
