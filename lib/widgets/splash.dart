import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';
import '../i18n.dart';

const _ink = Color(0xFF14171F);
const _taxi = Color(0xFFFFD12E);

/// Заставка как в прототипе (#splash): квадрат с пружинкой, знак «қошқар мүйіз» рисуется линией,
/// блик, надпись и подпись, расходящиеся круги. Первый запуск — 3 с, потом 2 с; касание — сразу.
class SplashOverlay extends StatefulWidget {
  const SplashOverlay({super.key});
  @override
  State<SplashOverlay> createState() => _SplashOverlayState();
}

class _SplashOverlayState extends State<SplashOverlay> with TickerProviderStateMixin {
  // Появление: 0–2 с, все этапы — доли этого времени.
  late final _intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000));
  late final _ring = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
  late final _dots = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
  late final _drift = AnimationController(vsync: this, duration: const Duration(seconds: 9));
  late final _fade = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
  bool _gone = false;

  @override
  void initState() {
    super.initState();
    _intro.forward();
    _dots.repeat();
    _drift.repeat(reverse: true);
    Future.delayed(const Duration(milliseconds: 1100), () {
      if (mounted) _ring.repeat();
    });
    _scheduleHide();
  }

  Future<void> _scheduleHide() async {
    var first = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      first = !(prefs.getBool('alakol-seen') ?? false);
      await prefs.setBool('alakol-seen', true);
    } catch (_) {}
    await Future.delayed(Duration(milliseconds: first ? 3000 : 2000));
    _hide();
  }

  void _hide() {
    if (!mounted || _fade.isAnimating || _fade.isCompleted) return;
    _fade.forward().whenComplete(() {
      if (mounted) setState(() => _gone = true);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // «Уменьшить движение» в настройках телефона — сразу конечный кадр.
    if (MediaQuery.of(context).disableAnimations) _intro.value = 1;
  }

  @override
  void dispose() {
    _intro.dispose();
    _ring.dispose();
    _dots.dispose();
    _drift.dispose();
    _fade.dispose();
    super.dispose();
  }

  /// Часть появления от a до b секунд, 0..1.
  Animation<double> _phase(double a, double b, [Curve curve = Curves.easeOut]) => CurvedAnimation(
        parent: _intro,
        curve: Interval(a / 2, b / 2, curve: curve),
      );

  @override
  Widget build(BuildContext context) {
    if (_gone) return const SizedBox.shrink();
    final pop = _phase(0, .7, const Cubic(.3, 1.6, .5, 1));
    final popFade = _phase(0, .7, Curves.easeOut);
    final stem = _phase(.35, .65);
    final horn = _phase(.6, 1.15);
    final shine = _phase(.95, 1.95);
    final name = _phase(.9, 1.4);
    final sub = _phase(1.05, 1.55);
    final dots = _phase(1.2, 1.7);

    return FadeTransition(
      opacity: ReverseAnimation(_fade),
      // Заставка лежит поверх навигатора, вне Scaffold — шрифт Onest берём из темы.
      child: DefaultTextStyle(
        style: (Theme.of(context).textTheme.bodyMedium ?? const TextStyle())
            .copyWith(decoration: TextDecoration.none),
        child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _hide,
        child: Semantics(
          label: kBrand,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(.2, -.1),
                    radius: 1.1,
                    colors: [Color(0xFFFFE15A), Color(0xFFFFD12E), Color(0xFFF2B705), Color(0xFFD99A00)],
                    stops: [0, .38, .75, 1],
                  ),
                ),
              ),
              AnimatedBuilder(
                animation: _drift,
                builder: (_, __) => CustomPaint(painter: _PatternPainter(Curves.easeInOut.transform(_drift.value))),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0, -.08),
                    radius: .55,
                    colors: [Color(0xF2FFE878), Color(0x8CFFD63C), Color(0x00FFD63C)],
                    stops: [0, .45, .75],
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: FractionallySizedBox(
                  heightFactor: .34,
                  widthFactor: 1,
                  child: CustomPaint(painter: _LandPainter()),
                ),
              ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _logo(pop, popFade, stem, horn, shine),
                    const SizedBox(height: 20),
                    _rise(
                      name,
                      const Text(kBrand,
                          style: TextStyle(
                            color: _ink, fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: 26 * .16,
                            decoration: TextDecoration.none,
                          )),
                    ),
                    const SizedBox(height: 8),
                    _rise(
                      sub,
                      Text(tr('Алакөл ауданы · такси и доставка'),
                          style: TextStyle(
                            color: _ink.withOpacity(.8), fontSize: 14, fontWeight: FontWeight.w500,
                            letterSpacing: 14 * .02, decoration: TextDecoration.none,
                          )),
                    ),
                    const SizedBox(height: 26),
                    _rise(dots, _dotsRow()),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _logo(Animation<double> pop, Animation<double> popFade, Animation<double> stem,
      Animation<double> horn, Animation<double> shine) {
    return AnimatedBuilder(
      animation: Listenable.merge([_intro, _ring]),
      builder: (_, __) {
        final ringsOn = _ring.isAnimating;
        return Opacity(
          opacity: popFade.value.clamp(0.0, 1.0),
          child: Transform.rotate(
            angle: (1 - pop.value) * -12 * pi / 180,
            child: Transform.scale(
              scale: .3 + .7 * pop.value,
              child: SizedBox(
                width: 92,
                height: 92,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Два круга по очереди: каждый расширяется и тает.
                    if (ringsOn) ...[
                      _ringAt(_ring.value),
                      _ringAt((_ring.value + .5) % 1),
                    ],
                    Container(
                      decoration: BoxDecoration(
                        color: _ink,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: _ink.withOpacity(.9), width: 1.5),
                        boxShadow: const [
                          BoxShadow(color: Color(0x73000000), offset: Offset(0, 18), blurRadius: 40, spreadRadius: -12),
                        ],
                      ),
                    ),
                    Center(
                      child: CustomPaint(
                        size: const Size(58, 58),
                        painter: _MarkPainter(stem: stem.value, horn: horn.value),
                      ),
                    ),
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: CustomPaint(painter: _ShinePainter(shine.value)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _ringAt(double t) {
    final e = Curves.easeOut.transform(t);
    return Positioned(
      left: -2, top: -2, right: -2, bottom: -2,
      child: Transform.scale(
        scale: 1 + .45 * e,
        child: Opacity(
          opacity: .5 * (1 - e),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: _ink, width: 2),
            ),
          ),
        ),
      ),
    );
  }

  Widget _rise(Animation<double> a, Widget child) => AnimatedBuilder(
        animation: a,
        builder: (_, c) => Opacity(
          opacity: a.value,
          child: Transform.translate(offset: Offset(0, 10 * (1 - a.value)), child: c),
        ),
        child: child,
      );

  Widget _dotsRow() => AnimatedBuilder(
        animation: _dots,
        builder: (_, __) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Builder(builder: (_) {
                // Как @keyframes spDot: пик на 40% цикла, задержка 0.2 с на каждую точку.
                final t = (_dots.value - i * .2 / 1.2) % 1;
                final k = t < .4 ? t / .4 : (1 - t) / .6;
                final up = Curves.easeInOut.transform(k.clamp(0.0, 1.0));
                return Transform.translate(
                  offset: Offset(0, -3 * up),
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: _ink.withOpacity(.35 + .65 * up),
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              }),
            ],
          ],
        ),
      );
}

/// Знак «қошқар мүйіз» (viewBox 24×24 из прототипа): сначала ножка, потом оба рога.
class _MarkPainter extends CustomPainter {
  final double stem;
  final double horn;
  _MarkPainter({required this.stem, required this.horn});

  static final _stemPath = Path()
    ..moveTo(12, 21)
    ..lineTo(12, 12);
  static final _left = Path()
    ..moveTo(12, 12)
    ..cubicTo(12, 7, 5.5, 5.8, 4.4, 9.4)
    ..cubicTo(3.6, 12.0, 6.4, 13.5, 8.0, 12.0);
  static final _right = Path()
    ..moveTo(12, 12)
    ..cubicTo(12, 7, 18.5, 5.8, 19.6, 9.4)
    ..cubicTo(20.4, 12.0, 17.6, 13.5, 16.0, 12.0);

  static void _drawPart(Canvas canvas, Path path, double t, Paint p) {
    if (t <= 0) return;
    for (final m in path.computeMetrics()) {
      canvas.drawPath(m.extractPath(0, m.length * t.clamp(0.0, 1.0)), p);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    final p = Paint()
      ..color = _taxi
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    _drawPart(canvas, _stemPath, stem, p);
    _drawPart(canvas, _left, horn, p);
    _drawPart(canvas, _right, horn, p);
  }

  @override
  bool shouldRepaint(_MarkPainter old) => old.stem != stem || old.horn != horn;
}

/// Блик по квадрату: полоса под углом 115° проходит справа налево.
class _ShinePainter extends CustomPainter {
  final double t;
  _ShinePainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0 || t >= 1) return;
    final w = size.width * 2.5;
    final left = 2.1 * size.width * (1 - 2 * t);
    final rect = Rect.fromLTWH(left, 0, w, size.height);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment(-1, -.45),
          end: Alignment(1, .45),
          colors: [Color(0x00FFFFFF), Color(0x59FFFFFF), Color(0x00FFFFFF)],
          stops: [.3, .48, .62],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_ShinePainter old) => old.t != t;
}

/// Фон: орнамент из завитков (плитка 120 в масштабе 1.35), медленно «дышит».
class _PatternPainter extends CustomPainter {
  final double drift;
  _PatternPainter(this.drift);

  static final Path _tile = () {
    final horn = Path()
      ..moveTo(60, 52)
      ..cubicTo(60, 34, 46, 24, 36, 30)
      ..cubicTo(27, 35, 30, 47, 39, 46)
      ..cubicTo(44, 45, 45, 39, 41, 37);
    final edge = Path()
      ..moveTo(0, 60)
      ..cubicTo(14, 60, 22, 52, 22, 44)
      ..cubicTo(22, 37, 14, 35, 11, 41);
    final tile = Path();
    for (var k = 0; k < 4; k++) {
      final m = Matrix4.identity()
        ..translate(60.0, 60.0)
        ..rotateZ(k * pi / 2)
        ..translate(-60.0, -60.0);
      tile.addPath(horn.transform(m.storage), Offset.zero);
      tile.addPath(edge.transform(m.storage), Offset.zero);
    }
    return tile;
  }();

  static final Path _diamonds = () {
    Path d(double x, double y, double r) => Path()
      ..moveTo(x, y - r)
      ..lineTo(x + r * .75, y)
      ..lineTo(x, y + r)
      ..lineTo(x - r * .75, y)
      ..close();
    return Path()
      ..addPath(d(60, 60, 12), Offset.zero)
      ..addPath(d(0, 0, 8), Offset.zero)
      ..addPath(d(120, 0, 8), Offset.zero)
      ..addPath(d(0, 120, 8), Offset.zero)
      ..addPath(d(120, 120, 8), Offset.zero);
  }();

  @override
  void paint(Canvas canvas, Size size) {
    const color = Color(0x218C5A00); // rgba(140,90,0,.13)
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()..color = color;
    // spDrift: scale 1.04→1.1, сдвиг −1%→1%.
    final scale = 1.04 + .06 * drift;
    final shift = Offset(size.width, size.height) * ((drift * 2 - 1) * .01);
    canvas.save();
    canvas.translate(size.width / 2 + shift.dx, size.height / 2 + shift.dy);
    canvas.scale(scale);
    canvas.translate(-size.width / 2, -size.height / 2);
    const k = 1.35;
    const step = 120 * k;
    for (var y = -step; y < size.height + step; y += step) {
      for (var x = -step; x < size.width + step; x += step) {
        canvas.save();
        canvas.translate(x, y);
        canvas.scale(k);
        canvas.drawPath(_tile, stroke);
        canvas.drawPath(_diamonds, fill);
        canvas.restore();
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PatternPainter old) => old.drift != drift;
}

/// Горы и озеро Алаколь внизу (viewBox 430×260, растягивается по ширине).
class _LandPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 430, size.height / 260);
    void poly(List<double> pts, Color c) {
      final p = Path()..moveTo(pts[0], pts[1]);
      for (var i = 2; i < pts.length; i += 2) {
        p.lineTo(pts[i], pts[i + 1]);
      }
      canvas.drawPath(p..close(), Paint()..color = c);
    }

    poly([0, 150, 40, 118, 70, 132, 118, 84, 150, 110, 190, 70, 232, 112, 262, 96, 300, 124, 344, 80,
      384, 112, 430, 92, 430, 260, 0, 260], const Color(0x8C8A5A00));
    poly([190, 70, 204, 84, 196, 86, 186, 78], const Color(0x40FFFFFF));
    poly([344, 80, 356, 92, 348, 93], const Color(0x40FFFFFF));
    poly([118, 84, 128, 94, 121, 95], const Color(0x40FFFFFF));

    Path wave(double y0, List<List<double>> curves) {
      final p = Path()..moveTo(0, y0);
      for (final c in curves) {
        p.cubicTo(c[0], c[1], c[2], c[3], c[4], c[5]);
      }
      return p
        ..lineTo(430, 260)
        ..lineTo(0, 260)
        ..close();
    }

    canvas.drawPath(
      wave(168, [
        [60, 156, 110, 176, 170, 166],
        [240, 154, 300, 176, 360, 164],
        [390, 158, 410, 160, 430, 164],
      ]),
      Paint()..color = const Color(0x8C2BB3C9),
    );
    canvas.drawPath(
      wave(196, [
        [50, 186, 100, 204, 160, 196],
        [230, 186, 290, 206, 350, 196],
        [385, 190, 410, 192, 430, 196],
      ]),
      Paint()..color = const Color(0x805FD0E0),
    );
    canvas.drawPath(
      wave(226, [
        [60, 216, 120, 234, 190, 226],
        [260, 218, 320, 236, 430, 224],
      ]),
      Paint()..color = const Color(0xBF1B7F95),
    );
  }

  @override
  bool shouldRepaint(_LandPainter old) => false;
}
