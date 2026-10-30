import 'package:latlong2/latlong.dart';
import 'places.dart';

/// Улица района. Точка — середина улицы, если админ её определил.
class Street {
  final String name;
  final String nameKz;
  final List<String> synonyms;
  final int houses;
  final LatLng? point;

  const Street({
    required this.name,
    this.nameKz = '',
    this.synonyms = const [],
    this.houses = 0,
    this.point,
  });

  Street withPoint(LatLng? p) =>
      Street(name: name, nameKz: nameKz, synonyms: synonyms, houses: houses, point: p);

  factory Street.fromMap(Map<String, dynamic> m) {
    final lat = (m['lat'] as num?)?.toDouble();
    final lng = (m['lng'] as num?)?.toDouble();
    return Street(
      name: m['name'] as String? ?? '',
      nameKz: m['kz'] as String? ?? '',
      synonyms: (m['syn'] as List?)?.whereType<String>().toList() ?? const [],
      houses: (m['houses'] as num?)?.toInt() ?? 0,
      point: lat != null && lng != null ? LatLng(lat, lng) : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        if (nameKz.isNotEmpty) 'kz': nameKz,
        if (synonyms.isNotEmpty) 'syn': synonyms,
        if (houses > 0) 'houses': houses,
        if (point != null) 'lat': point!.latitude,
        if (point != null) 'lng': point!.longitude,
      };

  /// Для поиска улица выглядит как место: без точки — в центре района, «примерно».
  Place toPlace(String region, LatLng center) => Place(
        id: 'street:$name',
        name: 'ул. $name',
        sub: houses > 0 ? 'улица · $houses домов' : 'улица',
        category: 'street',
        point: point ?? center,
        synonyms: [name, if (nameKz.isNotEmpty) nameKz, ...synonyms],
        approx: point == null,
        region: region,
      );
}

/// Список улиц из таблицы: «Название;По-казахски;Другие названия через запятую;Сколько домов».
/// Понимает «;», табуляцию (копия из Excel) и строку заголовка.
List<Street> parseStreets(String text) {
  final out = <Street>[];
  for (final raw in text.split(RegExp(r'\r?\n'))) {
    final line = raw.trim();
    if (line.isEmpty) continue;
    final cols = line.split(RegExp(r'[;\t]')).map((c) => c.trim()).toList();
    final name = cols[0];
    if (name.isEmpty || name.toLowerCase() == 'название') continue;
    out.add(Street(
      name: name,
      nameKz: cols.length > 1 ? cols[1] : '',
      synonyms: cols.length > 2
          ? cols[2].split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList()
          : const [],
      houses: cols.length > 3 ? int.tryParse(cols[3]) ?? 0 : 0,
    ));
  }
  return out;
}

/// Номер дома из запроса: «абая 12» → «12», «абая 12а» → «12а».
String? houseNumber(String query) =>
    RegExp(r'(\d+\s?[а-яa-z]?)\s*$', caseSensitive: false).firstMatch(query.trim())?.group(1);
