import 'package:cloud_firestore/cloud_firestore.dart';

/// SOS, жалоба или отзыв — попадает в админку, раздел «SOS и жалобы».
class Incident {
  final String id;
  final String kind; // sos / complaint / review
  final String title;
  final String body;
  final String? orderId;
  final String authorName;
  final String authorPhone;
  final DateTime? createdAt;
  final bool resolved;
  const Incident({
    required this.id,
    required this.kind,
    this.title = '',
    this.body = '',
    this.orderId,
    this.authorName = '',
    this.authorPhone = '',
    this.createdAt,
    this.resolved = false,
  });
}

abstract class IncidentRepository {
  Future<void> report({
    required String region,
    required String kind,
    required String title,
    String body = '',
    String? orderId,
  });

  /// Для админки и менеджера.
  Stream<List<Incident>> watchRegion(String region);
  Future<void> resolve(String id);
}

class FirestoreIncidentRepository implements IncidentRepository {
  final _col = FirebaseFirestore.instance.collection('incidents');

  @override
  Future<void> report({
    required String region,
    required String kind,
    required String title,
    String body = '',
    String? orderId,
  }) =>
      _col.add({
        'region': region,
        'kind': kind,
        'title': title,
        'body': body,
        'orderId': orderId,
        'createdAt': FieldValue.serverTimestamp(),
        'resolved': false,
      });

  @override
  Stream<List<Incident>> watchRegion(String region) =>
      _col.where('region', isEqualTo: region).snapshots().map((q) => [
            for (final d in q.docs)
              Incident(
                id: d.id,
                kind: d.data()['kind'] as String? ?? 'complaint',
                title: d.data()['title'] as String? ?? '',
                body: d.data()['body'] as String? ?? '',
                orderId: d.data()['orderId'] as String?,
                createdAt: (d.data()['createdAt'] as Timestamp?)?.toDate(),
                resolved: d.data()['resolved'] as bool? ?? false,
              ),
          ]);

  @override
  Future<void> resolve(String id) => _col.doc(id).update({'resolved': true});
}
