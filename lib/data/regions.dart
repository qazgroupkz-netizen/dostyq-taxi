import 'package:latlong2/latlong.dart';

/// Район обслуживания: посёлок или город со своими ценами, местами и водителями.
class Region {
  final String id;
  final String name;
  final LatLng center;

  /// Радиус района: точки дальше считаются «вне района».
  final double radiusKm;

  /// Выключенный район не видят клиенты (например, пока нет водителей).
  final bool active;

  const Region({
    required this.id,
    required this.name,
    required this.center,
    this.radiusKm = 8,
    this.active = true,
  });

  bool contains(LatLng p) => Distance()(p, center) <= radiusKm * 1000;

  Region copyWith({String? name, LatLng? center, double? radiusKm, bool? active}) => Region(
        id: id,
        name: name ?? this.name,
        center: center ?? this.center,
        radiusKm: radiusKm ?? this.radiusKm,
        active: active ?? this.active,
      );
}

const defaultRegionId = 'dostyk';

// Встроенный список — пока в базе районов ничего нет. Центры из OpenStreetMap.
const builtInRegions = <Region>[
  Region(
    id: 'dostyk', name: 'Достык',
    center: LatLng(45.25606, 82.49278),
    radiusKm: 8, // вместе с Таможней · КПП
  ),
  Region(
    id: 'usharal', name: 'Ушарал',
    center: LatLng(46.17613, 80.95257),
    radiusKm: 6,
  ),
];
