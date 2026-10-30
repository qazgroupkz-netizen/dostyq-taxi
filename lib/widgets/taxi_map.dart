import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../data/places.dart';

const dostykCenter = LatLng(45.25606, 82.49278);

const _jade = Color(0xFF0E7C66);
const _ink = Color(0xFF111317);

class TaxiMap extends StatefulWidget {
  final MapController? controller;
  final LatLng initialCenter;

  /// Булавка зафиксирована в центре экрана; карта двигается под ней.
  final bool centerPin;

  /// Плашка над булавкой подачи, например «~3 мин».
  final String? pinLabel;

  /// Подпись под булавкой в центре (адрес); прячется, пока карта движется.
  final String? pinCaption;
  final ValueChanged<LatLng>? onCenterChanged;

  final LatLng? pickup;
  final LatLng? dest;
  final String? destLabel;
  final List<LatLng>? route;
  final LatLng? car;
  final List<LatLng> idleCars;
  final LatLng? me;
  final List<Place> places;
  final ValueChanged<Place>? onPlaceTap;

  /// Карта сама переезжает к этой точке, когда она меняется.
  final LatLng? follow;
  final bool interactive;

  const TaxiMap({
    super.key,
    this.controller,
    this.initialCenter = dostykCenter,
    this.centerPin = false,
    this.pinLabel,
    this.pinCaption,
    this.onCenterChanged,
    this.pickup,
    this.dest,
    this.destLabel,
    this.route,
    this.car,
    this.idleCars = const [],
    this.me,
    this.places = const [],
    this.onPlaceTap,
    this.follow,
    this.interactive = true,
  });

  @override
  State<TaxiMap> createState() => _TaxiMapState();
}

class _TaxiMapState extends State<TaxiMap> {
  late final MapController _controller = widget.controller ?? MapController();
  Timer? _debounce;
  bool _ready = false;
  bool _moving = false;

  @override
  void didUpdateWidget(TaxiMap old) {
    super.didUpdateWidget(old);
    final f = widget.follow;
    if (_ready && f != null && f != old.follow) {
      _controller.move(f, _controller.camera.zoom);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onPosition(MapCamera camera, bool hasGesture) {
    if (hasGesture && !_moving && widget.centerPin) setState(() => _moving = true);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted && _moving) setState(() => _moving = false);
      widget.onCenterChanged?.call(camera.center);
    });
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final route = widget.route;
    return Stack(
      children: [
        RepaintBoundary(child: FlutterMap(
          mapController: _controller,
          options: MapOptions(
            initialCenter: widget.follow ?? widget.initialCenter,
            initialZoom: 15,
            minZoom: 4,
            maxZoom: 18,
            backgroundColor: const Color(0xFFE9ECE4),
            interactionOptions: InteractionOptions(
              flags: widget.interactive
                  ? InteractiveFlag.all & ~InteractiveFlag.rotate
                  : InteractiveFlag.none,
            ),
            onMapReady: () => _ready = true,
            onPositionChanged: _onPosition,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'kz.dostyq.taxi',
              tileDisplay: const TileDisplay.instantaneous(),
              keepBuffer: 4,
            ),
            if (route != null && route.length > 1)
              PolylineLayer(polylines: [
                Polyline(points: route, color: Colors.white, strokeWidth: 10),
                Polyline(points: route, color: _jade, strokeWidth: 6),
              ]),
            if (widget.car != null && widget.pickup != null)
              PolylineLayer(polylines: [
                Polyline(
                  points: [widget.car!, widget.pickup!],
                  color: _jade.withOpacity(.85),
                  strokeWidth: 4,
                  pattern: StrokePattern.dashed(segments: const [10, 7]),
                ),
              ]),
            MarkerLayer(markers: [
              for (final p in widget.places)
                Marker(
                  point: p.point,
                  width: 30, height: 30,
                  child: _PlaceMarker(
                    place: p,
                    onTap: widget.onPlaceTap == null
                        ? null
                        : () => widget.onPlaceTap!(p),
                  ),
                ),
              for (final c in widget.idleCars)
                Marker(point: c, width: 30, height: 30, child: const _IdleCar()),
              if (widget.me != null)
                Marker(point: widget.me!, width: 22, height: 22, child: const _MeDot()),
              if (widget.dest != null)
                Marker(
                  point: widget.dest!,
                  width: 180, height: 90,
                  alignment: Alignment.topCenter,
                  child: _DestPin(label: widget.destLabel),
                ),
              if (widget.pickup != null && !widget.centerPin)
                Marker(
                  point: widget.pickup!,
                  width: 180, height: 90,
                  alignment: Alignment.topCenter,
                  child: _Pin(label: widget.pinLabel),
                ),
              if (widget.car != null)
                Marker(point: widget.car!, width: 48, height: 48, child: const _CarMarker()),
            ]),
          ],
        )),
        if (widget.centerPin)
          IgnorePointer(
            child: Center(
              // Середина блока (низ булавки) — ровно в центре карты; при движении приподнимаем.
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 150),
                offset: Offset(0, _moving ? -0.08 : 0),
                child: SizedBox(
                  width: 240, height: 180,
                  child: Column(
                    children: [
                      SizedBox(height: 90, child: _Pin(label: widget.pinLabel)),
                      SizedBox(
                        height: 90,
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 150),
                            opacity: _moving || widget.pinCaption == null ? 0 : 1,
                            child: _Caption(text: widget.pinCaption ?? ''),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        Positioned(
          left: 8, top: top + 70,
          child: IgnorePointer(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.75),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('© OpenStreetMap',
                  style: TextStyle(fontSize: 10, color: Color(0xFF5E6571))),
            ),
          ),
        ),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  final String text;
  final bool dark;
  const _Bubble({required this.text, this.dark = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: dark ? _ink : Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.2), blurRadius: 8)],
      ),
      child: Text(text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: dark ? Colors.white : _ink,
            fontSize: 12.5, fontWeight: FontWeight.w700,
          )),
    );
  }
}

class _Pin extends StatelessWidget {
  final String? label;
  const _Pin({this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (label != null && label!.isNotEmpty) _Bubble(text: label!, dark: true),
        Container(
          width: 30, height: 30,
          decoration: BoxDecoration(
            color: _ink,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(.25), blurRadius: 8,
                  offset: const Offset(0, 3)),
            ],
          ),
          alignment: Alignment.center,
          child: Container(
            width: 11, height: 11,
            decoration: const BoxDecoration(color: _jade, shape: BoxShape.circle),
          ),
        ),
        Container(width: 3, height: 14, color: _ink),
      ],
    );
  }
}

class _DestPin extends StatelessWidget {
  final String? label;
  const _DestPin({this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (label != null && label!.isNotEmpty) _Bubble(text: label!),
        Container(
          width: 24, height: 24,
          decoration: BoxDecoration(
            color: _jade,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: _ink, width: 3),
          ),
        ),
        Container(width: 3, height: 18, color: _ink),
      ],
    );
  }
}

class _Caption extends StatelessWidget {
  final String text;
  const _Caption({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.95),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.15), blurRadius: 6)],
      ),
      child: Text(text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: _ink, fontSize: 12.5, fontWeight: FontWeight.w600)),
    );
  }
}

class _PlaceMarker extends StatelessWidget {
  final Place place;
  final VoidCallback? onTap;
  const _PlaceMarker({required this.place, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Container(
            width: 26, height: 26,
            decoration: BoxDecoration(
              color: place.color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.5),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(.2), blurRadius: 4)],
            ),
            child: Icon(place.icon, color: Colors.white, size: 14),
          ),
          Positioned(
            left: 30, top: 6,
            child: IgnorePointer(
              child: Text(place.name,
                  softWrap: false,
                  style: const TextStyle(
                    color: Color(0xFF2A2E35),
                    fontSize: 12, fontWeight: FontWeight.w700,
                    shadows: [
                      Shadow(color: Colors.white, blurRadius: 3),
                      Shadow(color: Colors.white, blurRadius: 3),
                    ],
                  )),
            ),
          ),
        ],
      ),
    );
  }
}

class _IdleCar extends StatelessWidget {
  const _IdleCar();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.2), blurRadius: 4)],
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.local_taxi_rounded, color: _jade, size: 18),
    );
  }
}

class _CarMarker extends StatelessWidget {
  const _CarMarker();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: _jade, width: 3),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(.25), blurRadius: 10,
              offset: const Offset(0, 3)),
        ],
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.local_taxi_rounded, color: _jade, size: 26),
    );
  }
}

class _MeDot extends StatelessWidget {
  const _MeDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2F7BEA),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(color: const Color(0xFF2F7BEA).withOpacity(.4), blurRadius: 10),
        ],
      ),
    );
  }
}
