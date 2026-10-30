import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Статус анкеты водителя.
enum Approval { none, pending, approved, rejected, blocked }

Approval _approvalOf(String? s) => Approval.values
    .firstWhere((a) => a.name == s, orElse: () => Approval.none);

/// Документы, без которых водителя не одобряют.
const driverDocKinds = <String, String>{
  'ip': 'ИП или платформенная занятость',
  'elicense': 'Уведомление E-license (такси)',
  'license': 'Водительские права',
  'techpass': 'Техпаспорт',
  'car': 'Фото машины',
};

class DriverProfile {
  final String uid;
  final String name;
  final String phone;
  final String carModel;
  final String carColor;
  final String plate;
  final String region;
  final Approval approval;
  final String? rejectReason;
  final DateTime? subscriptionUntil;
  final DateTime? submittedAt;

  const DriverProfile({
    required this.uid,
    this.name = '',
    this.phone = '',
    this.carModel = '',
    this.carColor = '',
    this.plate = '',
    this.region = 'dostyk',
    this.approval = Approval.none,
    this.rejectReason,
    this.subscriptionUntil,
    this.submittedAt,
  });

  String get car => [carColor, carModel].where((s) => s.isNotEmpty).join(' ');

  /// Сколько дней подписки осталось (0 — заканчивается сегодня, <0 — закончилась).
  int? get subscriptionDaysLeft {
    final u = subscriptionUntil;
    if (u == null) return null;
    final today = DateTime.now();
    final d0 = DateTime(today.year, today.month, today.day);
    final d1 = DateTime(u.year, u.month, u.day);
    return d1.difference(d0).inDays;
  }

  bool get subscriptionActive =>
      subscriptionUntil != null && subscriptionUntil!.isAfter(DateTime.now());

  bool get canWork => approval == Approval.approved && subscriptionActive;

  factory DriverProfile.fromMap(String uid, Map<String, dynamic> m) => DriverProfile(
        uid: uid,
        name: m['name'] as String? ?? '',
        phone: m['phone'] as String? ?? '',
        carModel: m['carModel'] as String? ?? '',
        carColor: m['carColor'] as String? ?? '',
        plate: m['plate'] as String? ?? '',
        region: m['region'] as String? ?? 'dostyk',
        approval: _approvalOf(m['approval'] as String?),
        rejectReason: m['rejectReason'] as String?,
        subscriptionUntil: (m['subscriptionUntil'] as Timestamp?)?.toDate(),
        submittedAt: (m['submittedAt'] as Timestamp?)?.toDate(),
      );
}

abstract class DriverRepository {
  Stream<DriverProfile> watchProfile(String uid);

  /// Сжатое фото документа (JPEG). Хранится отдельно от анкеты.
  Future<void> saveDoc(String uid, String kind, Uint8List jpeg);
  Future<Map<String, Uint8List>> loadDocs(String uid);

  Future<void> submit({
    required String uid,
    required String name,
    required String phone,
    required String carModel,
    required String carColor,
    required String plate,
    required String region,
  });

  // ─── Админ ────────────────────────────────────────────────────────────
  Stream<List<DriverProfile>> watchAll();
  Future<void> approve(String uid, {required DateTime until});
  Future<void> reject(String uid, String reason);
  Future<void> setBlocked(String uid, bool blocked);
  Future<void> setSubscriptionUntil(String uid, DateTime until);
}

class FirestoreDriverRepository implements DriverRepository {
  final _db = FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _drivers => _db.collection('drivers');
  CollectionReference<Map<String, dynamic>> get _docs => _db.collection('driverDocs');

  @override
  Stream<DriverProfile> watchProfile(String uid) => _drivers
      .doc(uid)
      .snapshots()
      .map((d) => DriverProfile.fromMap(uid, d.data() ?? const {}));

  @override
  Future<void> saveDoc(String uid, String kind, Uint8List jpeg) => _docs.doc('${uid}_$kind').set({
        'uid': uid,
        'kind': kind,
        'data': base64Encode(jpeg),
        'updatedAt': FieldValue.serverTimestamp(),
      });

  @override
  Future<Map<String, Uint8List>> loadDocs(String uid) async {
    final q = await _docs.where('uid', isEqualTo: uid).get();
    return {
      for (final d in q.docs)
        if (d.data()['data'] is String)
          d.data()['kind'] as String: base64Decode(d.data()['data'] as String),
    };
  }

  @override
  Future<void> submit({
    required String uid,
    required String name,
    required String phone,
    required String carModel,
    required String carColor,
    required String plate,
    required String region,
  }) =>
      _drivers.doc(uid).set({
        'name': name,
        'phone': phone,
        'carModel': carModel,
        'carColor': carColor,
        'plate': plate,
        'region': region,
        'approval': Approval.pending.name,
        'rejectReason': FieldValue.delete(),
        'consentAt': FieldValue.serverTimestamp(),
        'submittedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

  @override
  Stream<List<DriverProfile>> watchAll() => _drivers.snapshots().map((q) {
        final list = [
          for (final d in q.docs)
            if (d.data()['approval'] != null) DriverProfile.fromMap(d.id, d.data()),
        ];
        list.sort((a, b) => (b.submittedAt ?? DateTime(2000)).compareTo(a.submittedAt ?? DateTime(2000)));
        return list;
      });

  @override
  Future<void> approve(String uid, {required DateTime until}) => _drivers.doc(uid).update({
        'approval': Approval.approved.name,
        'rejectReason': FieldValue.delete(),
        'subscriptionUntil': Timestamp.fromDate(until),
        'approvedAt': FieldValue.serverTimestamp(),
      });

  @override
  Future<void> reject(String uid, String reason) => _drivers.doc(uid).update({
        'approval': Approval.rejected.name,
        'rejectReason': reason,
      });

  @override
  Future<void> setBlocked(String uid, bool blocked) => _drivers.doc(uid).update({
        'approval': blocked ? Approval.blocked.name : Approval.approved.name,
        if (blocked) 'status': 'offline',
      });

  @override
  Future<void> setSubscriptionUntil(String uid, DateTime until) =>
      _drivers.doc(uid).update({'subscriptionUntil': Timestamp.fromDate(until)});
}
