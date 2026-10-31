import 'dart:typed_data';
import 'package:supabase/supabase.dart';
import '../drivers.dart';
import 'sb_client.dart';

class SupabaseDriverRepository implements DriverRepository {
  static DateTime? _time(Object? v) => v is String ? DateTime.tryParse(v)?.toLocal() : null;
  static String? _iso(DateTime? d) => d?.toUtc().toIso8601String();

  static DriverProfile _driver(String uid, Map<String, dynamic> m) => DriverProfile(
        uid: uid,
        name: m['name'] as String? ?? '',
        phone: m['phone'] as String? ?? '',
        carModel: m['car_model'] as String? ?? '',
        carColor: m['car_color'] as String? ?? '',
        plate: m['plate'] as String? ?? '',
        region: m['region'] as String? ?? 'dostyk',
        vehicle: m['vehicle'] as String? ?? 'car',
        approval: Approval.values.firstWhere((a) => a.name == m['approval'], orElse: () => Approval.none),
        rejectReason: m['reject_reason'] as String?,
        subscriptionUntil: _time(m['subscription_until']),
        submittedAt: _time(m['submitted_at']),
        ipUntil: _time(m['ip_until']),
        elicenseUntil: _time(m['elicense_until']),
        online: m['status'] == 'online',
        lat: (m['lat'] as num?)?.toDouble(),
        lng: (m['lng'] as num?)?.toDouble(),
      );

  @override
  Stream<DriverProfile> watchProfile(String uid) => sb
      .from('drivers')
      .stream(primaryKey: ['id'])
      .eq('id', uid)
      .map((rows) => rows.isEmpty ? DriverProfile(uid: uid) : _driver(uid, rows.first));

  // Фото документов — в хранилище файлов сервера: driver-docs/<uid>/<kind>.jpg.
  StorageFileApi get _files => sb.storage.from('driver-docs');

  @override
  Future<void> saveDoc(String uid, String kind, Uint8List jpeg) => _files.uploadBinary(
        '$uid/$kind.jpg',
        jpeg,
        fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'),
      );

  @override
  Future<Map<String, Uint8List>> loadDocs(String uid) async {
    final files = await _files.list(path: uid);
    final out = <String, Uint8List>{};
    for (final f in files) {
      if (!f.name.endsWith('.jpg')) continue;
      out[f.name.substring(0, f.name.length - 4)] = await _files.download('$uid/${f.name}');
    }
    return out;
  }

  // Статус «на проверке», подписку и одобрение сервер не даст поменять водителю (drivers_guard).
  @override
  Future<void> submit({
    required String uid,
    required String name,
    required String phone,
    required String carModel,
    required String carColor,
    required String plate,
    required String region,
    String vehicle = 'car',
    DateTime? ipUntil,
    DateTime? elicenseUntil,
  }) {
    final now = DateTime.now().toUtc().toIso8601String();
    return sb.from('drivers').upsert({
      'id': uid,
      'name': name,
      'phone': phone,
      'car_model': carModel,
      'car_color': carColor,
      'plate': plate,
      'region': region,
      'vehicle': vehicle,
      'ip_until': _iso(ipUntil),
      'elicense_until': _iso(elicenseUntil),
      'approval': Approval.pending.name,
      'consent_at': now,
      'submitted_at': now,
    });
  }

  @override
  Stream<List<DriverProfile>> watchAll() => sb
      .from('drivers')
      .stream(primaryKey: ['id'])
      .order('submitted_at', ascending: false)
      .map((rows) => [for (final m in rows) _driver(m['id'] as String, m)]);

  @override
  Future<void> approve(String uid, {required DateTime until}) => sb.from('drivers').update({
        'approval': Approval.approved.name,
        'reject_reason': null,
        'subscription_until': _iso(until),
        'approved_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', uid);

  @override
  Future<void> reject(String uid, String reason) => sb
      .from('drivers')
      .update({'approval': Approval.rejected.name, 'reject_reason': reason})
      .eq('id', uid);

  @override
  Future<void> setBlocked(String uid, bool blocked) => sb.from('drivers').update({
        'approval': blocked ? Approval.blocked.name : Approval.approved.name,
        if (blocked) 'status': 'offline',
      }).eq('id', uid);

  @override
  Future<void> setSubscriptionUntil(String uid, DateTime until) =>
      sb.from('drivers').update({'subscription_until': _iso(until)}).eq('id', uid);
}
