import 'package:cloud_firestore/cloud_firestore.dart';

class TaxiOrder {
  final String id;
  final String status;
  final String clientId;
  final String clientName;
  final String from;
  final String to;
  final String tariff;
  final int price;
  final String payment;
  final String? driverId;
  final String? driverName;
  final bool clientComingOut;
  final DateTime? createdAt;

  const TaxiOrder({
    required this.id,
    required this.status,
    required this.clientId,
    required this.clientName,
    required this.from,
    required this.to,
    required this.tariff,
    required this.price,
    required this.payment,
    this.driverId,
    this.driverName,
    this.clientComingOut = false,
    this.createdAt,
  });
}

abstract class OrderRepository {
  Future<String> create({
    required String clientId,
    required String clientName,
    required String from,
    required String to,
    required String tariff,
    required int price,
    required String payment,
  });

  Stream<TaxiOrder?> watch(String id);

  Stream<List<TaxiOrder>> watchSearching();

  /// false — заказ уже забрал другой водитель или клиент отменил.
  Future<bool> accept(String id, {required String driverId, required String driverName});

  Future<void> setStatus(String id, String status);

  Future<void> update(String id, Map<String, Object?> fields);

  Future<String> userName(String uid);
}

class FirestoreOrderRepository implements OrderRepository {
  final _db = FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _orders => _db.collection('orders');

  static TaxiOrder _fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? const {};
    String label(Object? v) => v is Map ? (v['label'] as String? ?? '') : '';
    return TaxiOrder(
      id: d.id,
      status: m['status'] as String? ?? 'searching',
      clientId: m['clientId'] as String? ?? '',
      clientName: m['clientName'] as String? ?? '',
      from: label(m['from']),
      to: label(m['to']),
      tariff: m['service'] as String? ?? 'local',
      price: (m['price'] as num?)?.toInt() ?? 0,
      payment: m['payment'] as String? ?? 'cash',
      driverId: m['driverId'] as String?,
      driverName: m['driverName'] as String?,
      clientComingOut: m['clientComingOut'] as bool? ?? false,
      createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  @override
  Future<String> create({
    required String clientId,
    required String clientName,
    required String from,
    required String to,
    required String tariff,
    required int price,
    required String payment,
  }) async {
    final ref = await _orders.add({
      'clientId': clientId,
      'clientName': clientName,
      'from': {'label': from},
      'to': {'label': to},
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
  Future<void> update(String id, Map<String, Object?> fields) =>
      _orders.doc(id).update(fields);

  @override
  Future<String> userName(String uid) async {
    final d = await _db.collection('users').doc(uid).get();
    return d.data()?['name'] as String? ?? '';
  }
}
