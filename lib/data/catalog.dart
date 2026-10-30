import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';
import 'places.dart';
import 'regions.dart';
import 'settings.dart';

/// Районы, настройки (цены, правила) и ориентиры, которые ведёт админ.
abstract class CatalogRepository {
  /// Пустой список — в базе районов ещё нет.
  Stream<List<Region>> watchRegions();
  Future<void> saveRegion(Region r);
  Future<String> newRegionId();

  Stream<TariffSettings> watchSettings(String regionId);
  Future<void> saveSettings(String regionId, TariffSettings s);
  Future<void> saveRoutePrice(String from, String to, RoutePrice p);

  /// Все места всех районов; пустой список — в базе мест ещё нет.
  Stream<List<Place>> watchPlaces();
  Future<void> savePlace(Place p);
  Future<void> deletePlace(String id);
  Future<String> newPlaceId();
}

class FirestoreCatalogRepository implements CatalogRepository {
  final _db = FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _settings => _db.collection('settings');
  CollectionReference<Map<String, dynamic>> get _places => _db.collection('places');
  CollectionReference<Map<String, dynamic>> get _regions => _db.collection('regions');

  @override
  Stream<List<Region>> watchRegions() => _regions.snapshots().map((q) {
        final list = [
          for (final d in q.docs)
            Region(
              id: d.id,
              name: d.data()['name'] as String? ?? d.id,
              center: LatLng(
                (d.data()['lat'] as num?)?.toDouble() ?? 0,
                (d.data()['lng'] as num?)?.toDouble() ?? 0,
              ),
              radiusKm: (d.data()['radiusKm'] as num?)?.toDouble() ?? 8,
              active: d.data()['active'] as bool? ?? true,
            ),
        ];
        list.sort((a, b) => a.name.compareTo(b.name));
        return list;
      });

  @override
  Future<void> saveRegion(Region r) => _regions.doc(r.id).set({
        'name': r.name,
        'lat': r.center.latitude,
        'lng': r.center.longitude,
        'radiusKm': r.radiusKm,
        'active': r.active,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  @override
  Future<String> newRegionId() async => _regions.doc().id;

  // Цены Достыка сначала жили в settings/main — читаем их, пока нет settings/dostyk.
  @override
  Stream<TariffSettings> watchSettings(String regionId) =>
      _settings.doc(regionId).snapshots().asyncMap((d) async {
        var m = d.data();
        if (m == null && regionId == defaultRegionId) {
          m = (await _settings.doc('main').get()).data();
        }
        return TariffSettings.fromMap(m ?? const {});
      });

  @override
  Future<void> saveSettings(String regionId, TariffSettings s) =>
      _settings.doc(regionId).set({
        ...s.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

  @override
  Future<void> saveRoutePrice(String from, String to, RoutePrice p) =>
      _settings.doc(from).set({
        'routes': {to: p.toMap()},
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
      // Места, добавленные до появления районов, — в Достыке.
      region: m['region'] as String? ?? defaultRegionId,
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
        'region': p.region,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  @override
  Future<void> deletePlace(String id) => _places.doc(id).delete();

  @override
  Future<String> newPlaceId() async => _places.doc().id;
}
