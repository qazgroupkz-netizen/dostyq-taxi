import 'package:flutter/material.dart';

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
    canvas.drawLine(Offset(cx, cy), Offset(cx, sz.height * .92), p);
    // Левый завиток «қошқар мүйіз»
    final left = Path()
      ..moveTo(cx, cy)
      ..cubicTo(cx, cy - sz.height * .5,
                cx - sz.width * .7, cy - sz.height * .6,
                cx - sz.width * .35, cy + sz.height * .1);
    canvas.drawPath(left, p);
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
