import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class RouteInfo {
  final List<LatLng> points;
  final double meters;
  final double seconds;

  /// false — сервис маршрутов не ответил, линия по прямой и время примерное.
  final bool byRoads;

  const RouteInfo(this.points, this.meters, this.seconds, {this.byRoads = true});

  int get minutes => (seconds / 60).ceil().clamp(1, 9999);
}

class GeoApi {
  // Браузер не даёт сайту менять User-Agent, там Nominatim узнаёт нас по адресу сайта.
  static const _headers = kIsWeb
      ? <String, String>{}
      : {'User-Agent': 'ALAKOL-TAXI/1.0 (kz.dostyq.taxi)'};

  static DateTime _lastNominatim = DateTime.fromMillisecondsSinceEpoch(0);
  static final _addrCache = <String, String?>{};

  /// Улица и дом по координатам. null — адрес не найден.
  static Future<String?> reverse(LatLng p) async {
    final key = '${p.latitude.toStringAsFixed(5)},${p.longitude.toStringAsFixed(5)}';
    if (_addrCache.containsKey(key)) return _addrCache[key];
    await _waitTurn();
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'lat': '${p.latitude}',
        'lon': '${p.longitude}',
        'format': 'jsonv2',
        'zoom': '18',
        'addressdetails': '1',
        'accept-language': 'ru',
      });
      final res = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final j = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final a = (j['address'] as Map?) ?? const {};
      final road = (a['road'] ?? a['pedestrian'] ?? a['footway']) as String?;
      final house = a['house_number'] as String?;
      final name = j['name'] as String?;
      String? label;
      if (road != null) {
        label = house != null ? '$road, $house' : road;
      } else if (name != null && name.isNotEmpty) {
        label = name;
      }
      _addrCache[key] = label;
      return label;
    } catch (_) {
      return null;
    }
  }

  // Правило Nominatim: не чаще 1 запроса в секунду.
  static Future<void> _waitTurn() async {
    final now = DateTime.now();
    final next = _lastNominatim.add(const Duration(milliseconds: 1100));
    final slot = next.isAfter(now) ? next : now;
    _lastNominatim = slot;
    if (slot.isAfter(now)) await Future<void>.delayed(slot.difference(now));
  }

  /// Точка по адресу рядом с [near] (в пределах ~10 км). null — не нашли.
  static Future<LatLng?> search(String query, LatLng near) async {
    await _waitTurn();
    try {
      const d = 0.1;
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': query,
        'format': 'jsonv2',
        'limit': '1',
        'viewbox': '${near.longitude - d},${near.latitude + d},${near.longitude + d},${near.latitude - d}',
        'bounded': '1',
        'accept-language': 'ru',
      });
      final res = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final list = jsonDecode(utf8.decode(res.bodyBytes)) as List;
      if (list.isEmpty) return null;
      final j = list.first as Map<String, dynamic>;
      return LatLng(double.parse('${j['lat']}'), double.parse('${j['lon']}'));
    } catch (_) {
      return null;
    }
  }

  static Future<RouteInfo> route(LatLng from, LatLng to) async {
    try {
      final uri = Uri.https(
        'router.project-osrm.org',
        '/route/v1/driving/${from.longitude},${from.latitude};${to.longitude},${to.latitude}',
        {'overview': 'full', 'geometries': 'geojson'},
      );
      final res = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final j = jsonDecode(res.body) as Map<String, dynamic>;
        final routes = j['routes'] as List?;
        if (j['code'] == 'Ok' && routes != null && routes.isNotEmpty) {
          final r = routes.first as Map<String, dynamic>;
          final coords = (r['geometry']['coordinates'] as List)
              .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
              .toList();
          return RouteInfo(coords, (r['distance'] as num).toDouble(),
              (r['duration'] as num).toDouble());
        }
      }
    } catch (_) {}
    final m = Distance()(from, to) * 1.3;
    return RouteInfo([from, to], m, m / 7, byRoads: false);
  }
}
