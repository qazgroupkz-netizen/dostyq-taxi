import 'dart:math';
import 'package:latlong2/latlong.dart';
import '../catalog.dart';
import '../places.dart';
import '../regions.dart';
import '../settings.dart';
import '../streets.dart';
import 'sb_client.dart';

String newId() {
  final r = Random.secure();
  return List.generate(20, (_) => 'abcdefghijklmnopqrstuvwxyz0123456789'[r.nextInt(36)]).join();
}

class SupabaseCatalogRepository implements CatalogRepository {
  @override
  Stream<List<Region>> watchRegions() =>
      sb.from('regions').stream(primaryKey: ['id']).order('name', ascending: true).map((rows) => [
            for (final m in rows)
              Region(
                id: m['id'] as String,
                name: m['name'] as String? ?? '',
                center: LatLng((m['lat'] as num).toDouble(), (m['lng'] as num).toDouble()),
                radiusKm: (m['radius_km'] as num?)?.toDouble() ?? 8,
                active: m['active'] as bool? ?? true,
              ),
          ]);

  @override
  Future<void> saveRegion(Region r) => sb.from('regions').upsert({
        'id': r.id,
        'name': r.name,
        'lat': r.center.latitude,
        'lng': r.center.longitude,
        'radius_km': r.radiusKm,
        'active': r.active,
      });

  @override
  Future<String> newRegionId() async => newId();

  @override
  Stream<TariffSettings> watchSettings(String regionId) => sb
      .from('settings')
      .stream(primaryKey: ['region_id'])
      .eq('region_id', regionId)
      .map((rows) => rows.isEmpty
          ? const TariffSettings()
          : TariffSettings.fromMap({
              ...Map<String, dynamic>.from(rows.first['data'] as Map? ?? const {}),
              'routes': rows.first['routes'],
            }));

  // upsert меняет только переданные столбцы — цены направлений (routes) не трогаются.
  @override
  Future<void> saveSettings(String regionId, TariffSettings s) =>
      sb.from('settings').upsert({'region_id': regionId, 'data': s.toMap()});

  @override
  Future<void> saveRoutePrice(String from, String to, RoutePrice p) async {
    final row = await sb.from('settings').select('routes').eq('region_id', from).maybeSingle();
    final routes = Map<String, dynamic>.from(row?['routes'] as Map? ?? const {});
    routes[to] = p.toMap();
    await sb.from('settings').upsert({'region_id': from, 'routes': routes});
  }

  @override
  Stream<List<Street>> watchStreets(String regionId) => sb
      .from('streets')
      .stream(primaryKey: ['region_id'])
      .eq('region_id', regionId)
      .map((rows) {
        final list = [
          for (final m in rows.isEmpty ? const [] : (rows.first['list'] as List? ?? const []))
            if (m is Map) Street.fromMap(Map<String, dynamic>.from(m)),
        ].where((s) => s.name.isNotEmpty).toList();
        list.sort((a, b) => a.name.compareTo(b.name));
        return list;
      });

  @override
  Future<void> saveStreets(String regionId, List<Street> list) => sb
      .from('streets')
      .upsert({'region_id': regionId, 'list': [for (final s in list) s.toMap()]});

  static Place _place(Map<String, dynamic> m) => Place(
        id: m['id'] as String,
        name: m['name'] as String? ?? '',
        sub: m['sub'] as String? ?? '',
        category: m['category'] as String? ?? 'other',
        point: LatLng((m['lat'] as num).toDouble(), (m['lng'] as num).toDouble()),
        synonyms: (m['synonyms'] as List?)?.whereType<String>().toList() ?? const [],
        chip: m['chip'] as bool? ?? false,
        group: m['group'] as String?,
        approx: m['approx'] as bool? ?? false,
        region: m['region'] as String? ?? defaultRegionId,
        price: (m['price'] as num?)?.toInt(),
      );

  @override
  Stream<List<Place>> watchPlaces() => sb
      .from('places')
      .stream(primaryKey: ['id'])
      .order('name', ascending: true)
      .map((rows) => rows.map(_place).where((p) => p.name.isNotEmpty).toList());

  @override
  Future<void> savePlace(Place p) => sb.from('places').upsert({
        'id': p.id,
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
        'price': p.price,
      });

  @override
  Future<void> deletePlace(String id) => sb.from('places').delete().eq('id', id);

  @override
  Future<String> newPlaceId() async => newId();
}
