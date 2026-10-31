import '../incidents.dart';
import 'sb_client.dart';

class SupabaseIncidentRepository implements IncidentRepository {
  @override
  Future<void> report({
    required String region,
    required String kind,
    required String title,
    String body = '',
    String? orderId,
  }) =>
      sb.from('incidents').insert({
        'region': region,
        'kind': kind,
        'title': title,
        'body': body,
        'order_id': orderId,
      });

  @override
  Stream<List<Incident>> watchRegion(String region) => sb
      .from('incidents')
      .stream(primaryKey: ['id'])
      .eq('region', region)
      .order('created_at', ascending: false)
      .limit(200)
      .map((rows) => [
            for (final m in rows)
              Incident(
                id: m['id'] as String,
                kind: m['kind'] as String? ?? 'complaint',
                title: m['title'] as String? ?? '',
                body: m['body'] as String? ?? '',
                orderId: m['order_id'] as String?,
                authorName: m['author_name'] as String? ?? '',
                authorPhone: m['author_phone'] as String? ?? '',
                createdAt: DateTime.tryParse(m['created_at'] as String? ?? '')?.toLocal(),
                resolved: m['resolved_at'] != null,
              ),
          ]);

  @override
  Future<void> resolve(String id) =>
      sb.from('incidents').update({'resolved_at': DateTime.now().toUtc().toIso8601String()}).eq('id', id);
}
