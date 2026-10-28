import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

const dostykCenter = LatLng(45.2500, 82.4830);

const _jade = Color(0xFF0E7C66);

class TaxiMap extends StatefulWidget {
  final MapController? controller;
  final LatLng initialCenter;

  /// Булавка подачи зафиксирована в центре экрана; карта двигается под ней.
  final bool centerPin;
  final String? pinLabel;
  final ValueChanged<LatLng>? onCenterChanged;

  final LatLng? pickup;
  final LatLng? car;
  final LatLng? me;

  /// Карта сама переезжает к этой точке, когда она меняется.
  final LatLng? follow;
  final bool interactive;

  const TaxiMap({
    super.key,
    this.controller,
    this.initialCenter = dostykCenter,
    this.centerPin = false,
    this.pinLabel,
    this.onCenterChanged,
    this.pickup,
    this.car,
    this.me,
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

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
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
            onPositionChanged: (camera, _) {
              final cb = widget.onCenterChanged;
              if (cb == null) return;
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 350),
                  () => cb(camera.center));
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'kz.dostyq.taxi',
              tileDisplay: const TileDisplay.instantaneous(),
              keepBuffer: 4,
            ),
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
              if (widget.me != null)
                Marker(
                  point: widget.me!,
                  width: 22, height: 22,
                  child: const _MeDot(),
                ),
              if (widget.pickup != null && !widget.centerPin)
                Marker(
                  point: widget.pickup!,
                  width: 160, height: 86,
                  alignment: Alignment.topCenter,
                  child: _Pin(label: widget.pinLabel),
                ),
              if (widget.car != null)
                Marker(
                  point: widget.car!,
                  width: 48, height: 48,
                  child: const _CarMarker(),
                ),
            ]),
          ],
        )),
        if (widget.centerPin)
          IgnorePointer(
            child: Center(
              child: Transform.translate(
                offset: const Offset(0, -43),
                child: SizedBox(
                  width: 160, height: 86,
                  child: _Pin(label: widget.pinLabel),
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

class _Pin extends StatelessWidget {
  final String? label;
  const _Pin({this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (label != null && label!.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF14171F),
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(.2), blurRadius: 8),
              ],
            ),
            child: Text(label!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.5, fontWeight: FontWeight.w700,
                )),
          ),
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            color: _jade,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(.25), blurRadius: 8,
                  offset: const Offset(0, 3)),
            ],
          ),
          alignment: Alignment.center,
          child: Container(
            width: 10, height: 10,
            decoration: const BoxDecoration(
                color: Colors.white, shape: BoxShape.circle),
          ),
        ),
        Container(width: 3, height: 10, color: const Color(0xFF14171F)),
      ],
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
          BoxShadow(color: const Color(0xFF2F7BEA).withOpacity(.4),
              blurRadius: 10),
        ],
      ),
    );
  }
}
