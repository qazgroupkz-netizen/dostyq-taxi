import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';
import 'places.dart';
import 'settings.dart';

/// Настройки (цены, правила) и ориентиры, которые ведёт админ.
abstract class CatalogRepository {
  Stream<TariffSettings> watchSettings();
  Future<void> saveSettings(TariffSettings s);

  /// Пустой список — в базе мест ещё нет.
  Stream<List<Place>> watchPlaces();
  Future<void> savePlace(Place p);
  Future<void> deletePlace(String id);
  Future<String> newPlaceId();
}

class FirestoreCatalogRepository implements CatalogRepository {
  final _db = FirebaseFirestore.instance;
  DocumentReference<Map<String, dynamic>> get _settings =>
      _db.collection('settings').doc('main');
  CollectionReference<Map<String, dynamic>> get _places => _db.collection('places');

  @override
  Stream<TariffSettings> watchSettings() =>
      _settings.snapshots().map((d) => TariffSettings.fromMap(d.data() ?? const {}));

  @override
  Future<void> saveSettings(TariffSettings s) => _settings.set({
        ...s.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

  static Place _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data();
    return Place(
      id: d.id,
      name: m['name'] as String? ?? '',
      sub: m['sub'] as String? ?? '',
      category: m['category'] as String? ?? 'other',
      point: LatLng((m['lat'] as num?)?.toDouble() ?? 0, (m['lng'] as num?)?.toDouble() ?? 0),
      synonyms: (m['synonyms'] as List?)?.whereType<String>().toList() ?? const [],
      chip: m['chip'] as bool? ?? false,
      group: m['group'] as String?,
      approx: m['approx'] as bool? ?? false,
    );
  }

  @override
  Stream<List<Place>> watchPlaces() => _places.snapshots().map((q) {
        final list = q.docs.map(_fromDoc).where((p) => p.name.isNotEmpty).toList();
        list.sort((a, b) => a.name.compareTo(b.name));
        return list;
      });

  @override
  Future<void> savePlace(Place p) => _places.doc(p.id).set({
        'name': p.name,
        'sub': p.sub,
        'category': p.category,
        'lat': p.point.latitude,
        'lng': p.point.longitude,
        'synonyms': p.synonyms,
        'chip': p.chip,
        'group': p.group,
        'approx': p.approx,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  @override
  Future<void> deletePlace(String id) => _places.doc(id).delete();

  @override
  Future<String> newPlaceId() async => _places.doc().id;
}
