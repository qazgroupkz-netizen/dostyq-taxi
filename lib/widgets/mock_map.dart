import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../theme.dart';

// Имитация карты — нарисована через CustomPainter
// На этапе 4 заменится на настоящий flutter_map + OpenStreetMap

class MockMap extends StatelessWidget {
  const MockMap({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: CustomPaint(
        painter: _MapPainter(isDark: context.isDark),
      ),
    );
  }
}

class _MapPainter extends CustomPainter {
  final bool isDark;
  _MapPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size sz) {
    final bg      = isDark ? const Color(0xFF13161B) : const Color(0xFFEEF0EB);
    final field   = isDark ? const Color(0xFF141A16) : const Color(0xFFE4EBDD);
    final road    = isDark ? const Color(0xFF2B3139) : const Color(0xFFFFFFFF);
    final roadCase= isDark ? const Color(0xFF20252B) : const Color(0xFFD7DBD4);
    final house   = isDark ? const Color(0xFF252A32) : const Color(0xFFD8DBD2);
    final green   = isDark ? const Color(0xFF16281E) : const Color(0xFFD2E6CF);
    final label   = isDark ? const Color(0xFF8C94A0) : const Color(0xFF6E7480);

    final p = Paint();

    // Фон
    canvas.drawRect(Rect.fromLTWH(0, 0, sz.width, sz.height), p..color = bg);

    // Поля / кварталы
    final blocks = [
      Rect.fromLTWH(0, 0, sz.width * .45, sz.height * .22),
      Rect.fromLTWH(sz.width * .52, 0, sz.width * .48, sz.height * .22),
      Rect.fromLTWH(0, sz.height * .29, sz.width * .32, sz.height * .2),
      Rect.fromLTWH(sz.width * .38, sz.height * .29, sz.width * .28, sz.height * .2),
      Rect.fromLTWH(sz.width * .72, sz.height * .29, sz.width * .28, sz.height * .2),
      Rect.fromLTWH(0, sz.height * .56, sz.width * .45, sz.height * .2),
      Rect.fromLTWH(sz.width * .52, sz.height * .56, sz.width * .48, sz.height * .2),
      Rect.fromLTWH(0, sz.height * .82, sz.width, sz.height * .18),
    ];
    for (final b in blocks) {
      canvas.drawRect(b, p..color = field);
    }

    // Зелёные участки
    final greens = [
      Rect.fromLTWH(sz.width * .15, sz.height * .32, sz.width * .12, sz.height * .14),
      Rect.fromLTWH(sz.width * .6, sz.height * .08, sz.width * .1, sz.height * .1),
    ];
    final rr = RRect.fromRectAndRadius;
    for (final g in greens) {
      canvas.drawRRect(rr(g, const Radius.circular(4)), p..color = green);
    }

    // Дорожная сетка — горизонтальные улицы
    final hRoads = [.22, .27, .49, .54, .76, .81];
    for (final y in hRoads) {
      final ry = sz.height * y;
      canvas.drawLine(Offset(0, ry), Offset(sz.width, ry),
          p..color = roadCase..strokeWidth = 18..strokeCap = StrokeCap.butt);
      canvas.drawLine(Offset(0, ry), Offset(sz.width, ry),
          p..color = road..strokeWidth = 14..strokeCap = StrokeCap.butt);
    }

    // Вертикальные улицы
    final vRoads = [.33, .38, .68, .73];
    for (final x in vRoads) {
      final rx = sz.width * x;
      canvas.drawLine(Offset(rx, 0), Offset(rx, sz.height),
          p..color = roadCase..strokeWidth = 18..strokeCap = StrokeCap.butt);
      canvas.drawLine(Offset(rx, 0), Offset(rx, sz.height),
          p..color = road..strokeWidth = 14..strokeCap = StrokeCap.butt);
    }

    // Домики
    final houses = [
      Rect.fromLTWH(sz.width*.04, sz.height*.03, sz.width*.08, sz.height*.06),
      Rect.fromLTWH(sz.width*.16, sz.height*.03, sz.width*.1,  sz.height*.06),
      Rect.fromLTWH(sz.width*.04, sz.height*.31, sz.width*.12, sz.height*.14),
      Rect.fromLTWH(sz.width*.42, sz.height*.31, sz.width*.18, sz.height*.14),
      Rect.fromLTWH(sz.width*.76, sz.height*.31, sz.width*.18, sz.height*.14),
      Rect.fromLTWH(sz.width*.04, sz.height*.58, sz.width*.18, sz.height*.14),
      Rect.fromLTWH(sz.width*.56, sz.height*.58, sz.width*.18, sz.height*.14),
      Rect.fromLTWH(sz.width*.08, sz.height*.84, sz.width*.14, sz.height*.1),
      Rect.fromLTWH(sz.width*.55, sz.height*.84, sz.width*.14, sz.height*.1),
    ];
    for (final h in houses) {
      canvas.drawRRect(rr(h, const Radius.circular(2)), p..color = house);
    }

    // Центральная площадь (зелёная)
    canvas.drawRRect(
      rr(Rect.fromLTWH(sz.width*.39, sz.height*.56, sz.width*.26, sz.height*.18),
          const Radius.circular(6)),
      p..color = green,
    );

    // Подпись «Достык» по центру
    final tp = TextPainter(
      text: TextSpan(
        text: 'посёлок Достык',
        style: TextStyle(
          color: label, fontSize: 13, fontWeight: FontWeight.w600,
          letterSpacing: .5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas,
        Offset(sz.width / 2 - tp.width / 2, sz.height * .62));

    // Пин местоположения
    _drawPin(canvas, Offset(sz.width * .52, sz.height * .49));
  }

  void _drawPin(Canvas canvas, Offset center) {
    final paint = Paint();
    final taxi = isDark ? const Color(0xFF2DB896) : const Color(0xFF0E7C66);

    // Тень
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(center.dx, center.dy + 24),
          width: 14, height: 6),
      paint..color = Colors.black.withOpacity(.28)..maskFilter =
          const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // Хвост булавки
    final path = Path()
      ..moveTo(center.dx, center.dy + 24)
      ..lineTo(center.dx - 8, center.dy)
      ..lineTo(center.dx + 8, center.dy)
      ..close();
    canvas.drawPath(path, paint..color = taxi..maskFilter = null);

    // Круг булавки
    canvas.drawCircle(center, 16, paint..color = taxi);
    canvas.drawCircle(center, 16,
        paint..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 3);
    canvas.drawCircle(center, 5, paint..color = Colors.white..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(_MapPainter old) => old.isDark != isDark;
}

// Иконка казахского орнамента для логотипа
class OrnamentIcon extends StatelessWidget {
  final double size;
  final Color color;
  const OrnamentIcon({super.key, this.size = 17, required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _OrnPainter(color: color),
    );
  }
}

class _OrnPainter extends CustomPainter {
  final Color color;
  _OrnPainter({required this.color});

  @override
  void paint(Canvas canvas, Size sz) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = sz.width * .13
      ..strokeCap = StrokeCap.round;
    final cx = sz.width / 2;
    final cy = sz.height / 2;
    // Вертикальная линия
    canvas.drawLine(Offset(cx, cy), Offset(cx, sz.height * .92), p);
    // Левый завиток «қошқар мүйіз»
    final left = Path()
      ..moveTo(cx, cy)
      ..cubicTo(cx, cy - sz.height * .5,
                cx - sz.width * .7, cy - sz.height * .6,
                cx - sz.width * .35, cy + sz.height * .1);
    canvas.drawPath(left, p);
    // Правый завиток
    final right = Path()
      ..moveTo(cx, cy)
      ..cubicTo(cx, cy - sz.height * .5,
                cx + sz.width * .7, cy - sz.height * .6,
                cx + sz.width * .35, cy + sz.height * .1);
    canvas.drawPath(right, p);
  }

  @override
  bool shouldRepaint(_OrnPainter old) => old.color != color;
}
