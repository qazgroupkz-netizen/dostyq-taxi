import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../theme.dart';

// Имитация карты — нарисована через CustomPainter, поддерживает перетаскивание
// На этапе 4 заменится на настоящий flutter_map + OpenStreetMap

class MockMap extends StatefulWidget {
  final String? pickupLabel;
  final String? destLabel;
  /// 0.0–1.0: прогресс движения машины (null = машина не едет)
  final double? carFraction;
  /// 'coming' = едет к подаче, 'ride' = везёт клиента
  final String? carPhase;
  const MockMap({super.key, this.pickupLabel, this.destLabel,
      this.carFraction, this.carPhase});
  @override
  State<MockMap> createState() => _MockMapState();
}

class _MockMapState extends State<MockMap> {
  Offset _pan   = Offset.zero;
  double _scale = 1.0;
  double _baseScale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onScaleStart: (d) {
        _baseScale = _scale;
      },
      onScaleUpdate: (d) {
        setState(() {
          _scale = (_baseScale * d.scale).clamp(0.5, 3.0);
          _pan = Offset(
            (_pan.dx + d.focalPointDelta.dx).clamp(-200.0, 200.0),
            (_pan.dy + d.focalPointDelta.dy).clamp(-200.0, 200.0),
          );
        });
      },
      onDoubleTap: () => setState(() { _pan = Offset.zero; _scale = 1.0; }),
      child: SizedBox.expand(
        child: CustomPaint(
          painter: _MapPainter(
            isDark: context.isDark,
            pan: _pan,
            scale: _scale,
            pickupLabel: widget.pickupLabel,
            destLabel: widget.destLabel,
            carFraction: widget.carFraction,
            carPhase: widget.carPhase,
          ),
        ),
      ),
    );
  }
}

class _MapPainter extends CustomPainter {
  final bool isDark;
  final Offset pan;
  final double scale;
  final String? pickupLabel;
  final String? destLabel;
  final double? carFraction;
  final String? carPhase;
  _MapPainter({
    required this.isDark,
    this.pan = Offset.zero,
    this.scale = 1.0,
    this.pickupLabel,
    this.destLabel,
    this.carFraction,
    this.carPhase,
  });

  @override
  void paint(Canvas canvas, Size sz) {
    canvas.save();
    // Масштаб вокруг центра экрана, затем панорамирование
    canvas.translate(sz.width / 2 + pan.dx, sz.height / 2 + pan.dy);
    canvas.scale(scale);
    canvas.translate(-sz.width / 2, -sz.height / 2);

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

    // Точка назначения (рисуем до пина подачи, чтобы пин был поверх)
    if (destLabel != null) {
      _drawDestPin(
        canvas,
        Offset(sz.width * .30, sz.height * .28),
        destLabel!,
      );
    }

    // Пин подачи с подписью
    _drawPin(canvas, Offset(sz.width * .52, sz.height * .49),
        label: pickupLabel);

    // Машина (поверх всего)
    if (carFraction != null && carPhase != null) {
      _drawCar(canvas, sz);
    }

    canvas.restore();
  }

  void _drawCar(Canvas canvas, Size sz) {
    final t = carFraction!.clamp(0.0, 1.0);
    final Offset start, end;
    if (carPhase == 'coming') {
      start = Offset(sz.width * .83, sz.height * .13);
      end   = Offset(sz.width * .52, sz.height * .49);
    } else {
      start = Offset(sz.width * .52, sz.height * .49);
      end   = Offset(sz.width * .30, sz.height * .28);
    }
    final pos   = Offset.lerp(start, end, t)!;
    final angle = math.atan2(end.dy - start.dy, end.dx - start.dx);
    _drawCarMarker(canvas, pos, angle);
  }

  void _drawCarMarker(Canvas canvas, Offset pos, double angle) {
    final taxi  = isDark ? const Color(0xFF2DB896) : const Color(0xFF0E7C66);
    final white = Colors.white;
    final paint = Paint()..maskFilter = null;

    // Тень
    canvas.drawOval(
      Rect.fromCenter(center: pos.translate(0, 4), width: 26, height: 10),
      paint
        ..color = Colors.black.withOpacity(.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    // Машина рисуется «носом» вправо (0 градусов), поворачиваем по направлению
    canvas.rotate(angle + math.pi / 2);

    // Кузов
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: 18, height: 26),
        const Radius.circular(5),
      ),
      paint..color = taxi..style = PaintingStyle.fill..maskFilter = null,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: 18, height: 26),
        const Radius.circular(5),
      ),
      paint..color = white..style = PaintingStyle.stroke..strokeWidth = 2,
    );

    // Лобовое стекло
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-5, -11, 10, 7),
        const Radius.circular(2),
      ),
      paint..color = white.withOpacity(.55)..style = PaintingStyle.fill,
    );

    // Фары
    canvas.drawCircle(const Offset(-5, -13), 2.5,
        paint..color = const Color(0xFFFFF3C4)..style = PaintingStyle.fill);
    canvas.drawCircle(const Offset(5, -13), 2.5, paint);

    canvas.restore();
  }

  void _drawPin(Canvas canvas, Offset center, {String? label}) {
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

    // Пузырь с подписью над кругом
    if (label != null) {
      _drawBubble(canvas, Offset(center.dx, center.dy - 18), label);
    }
  }

  // Точка назначения: зелёный квадрат на столбике + пузырь сверху
  void _drawDestPin(Canvas canvas, Offset base, String label) {
    final taxi = isDark ? const Color(0xFF2DB896) : const Color(0xFF0E7C66);
    final dark = const Color(0xFF14171F);
    final paint = Paint()..maskFilter = null;

    // Тень под точкой
    canvas.drawOval(
      Rect.fromCenter(center: Offset(base.dx, base.dy + 2), width: 12, height: 5),
      paint
        ..color = Colors.black.withOpacity(.20)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    // Столбик
    canvas.drawLine(
      Offset(base.dx, base.dy),
      Offset(base.dx, base.dy - 30),
      paint
        ..color = dark
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke
        ..maskFilter = null,
    );

    // Зелёный квадрат
    final sq = Offset(base.dx, base.dy - 41);
    final sqRect = Rect.fromCenter(center: sq, width: 22, height: 22);
    canvas.drawRRect(
      RRect.fromRectAndRadius(sqRect, const Radius.circular(6)),
      paint..color = taxi..style = PaintingStyle.fill,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(sqRect, const Radius.circular(6)),
      paint..color = dark..style = PaintingStyle.stroke..strokeWidth = 3,
    );

    // Пузырь над квадратом
    _drawBubble(canvas, Offset(sq.dx, sq.dy - 13), label);
  }

  // Универсальный белый пузырь с тёмным текстом
  void _drawBubble(Canvas canvas, Offset tip, String text) {
    final bgColor = isDark ? const Color(0xFF181B21) : const Color(0xFFFFFFFF);
    final inkColor = isDark ? const Color(0xFFF2F4F7) : const Color(0xFF14171F);

    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: inkColor,
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    const hPad = 14.0;
    const bubH = 30.0;
    final bubW = tp.width + hPad * 2;
    const gap = 8.0;

    final bubTop  = tip.dy - gap - bubH;
    final bubLeft = tip.dx - bubW / 2;

    // Тень
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(bubLeft + 2, bubTop + 3, bubW, bubH),
        const Radius.circular(15),
      ),
      Paint()
        ..color = Colors.black.withOpacity(.15)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // Фон
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(bubLeft, bubTop, bubW, bubH),
        const Radius.circular(15),
      ),
      Paint()..color = bgColor..maskFilter = null,
    );

    // Текст
    tp.paint(
      canvas,
      Offset(tip.dx - tp.width / 2, bubTop + (bubH - tp.height) / 2),
    );
  }

  @override
  bool shouldRepaint(_MapPainter old) =>
      old.isDark != isDark ||
      old.pan != pan ||
      old.scale != scale ||
      old.pickupLabel != pickupLabel ||
      old.destLabel != destLabel ||
      old.carFraction != carFraction ||
      old.carPhase != carPhase;
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
