import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Smooth mini area-chart for monthly totals. [values] are paise amounts.
class MiniSparkline extends StatelessWidget {
  const MiniSparkline(
      {super.key, required this.values, this.height = 64, this.color});

  final List<double> values;
  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    if (values.length < 2) return const SizedBox.shrink();
    if (values.every((v) => v <= 0)) return const SizedBox.shrink();
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _SparkPainter(values, color ?? AppColors.accent),
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  _SparkPainter(this.values, this.color);

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // Scale paise down to lakh for stable float math.
    final List<double> scaled =
        values.map((v) => v / 100000.0).toList(growable: false);
    double minV = scaled.reduce((a, b) => a < b ? a : b);
    double maxV = scaled.reduce((a, b) => a > b ? a : b);
    if (maxV <= 0) return;
    if (maxV == minV) {
      minV = maxV - 1;
    }

    const double pad = 6;
    final int n = scaled.length;
    final List<Offset> points = List.generate(n, (i) {
      final double x = pad + (i / (n - 1)) * (size.width - pad * 2);
      final double t = (scaled[i] - minV) / (maxV - minV);
      final double y =
          (size.height - pad - 4) - t * (size.height - pad * 2 - 4);
      return Offset(x, y);
    });

    final Path line = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length - 1; i++) {
      final Offset mid = (points[i] + points[i + 1]) / 2;
      line.quadraticBezierTo(points[i].dx, points[i].dy, mid.dx, mid.dy);
    }
    line.lineTo(points.last.dx, points.last.dy);

    final Path fill = Path.from(line)
      ..lineTo(size.width - pad, size.height)
      ..lineTo(pad, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.3), color.withValues(alpha: 0.0)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    canvas.drawCircle(points.last, 3.5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _SparkPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.values.length != values.length ||
        !_equalValues(oldDelegate.values, values);
  }

  bool _equalValues(List<double> a, List<double> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
