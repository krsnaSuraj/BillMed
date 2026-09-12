import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Brand mark: gradient squircle + slip-and-badge glyph + optional wordmark.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 48});

  final double size;

  @override
  Widget build(BuildContext context) {
    final double radius = size * 0.25;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppGradients.brand,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: CustomPaint(painter: _LogoPainter()),
    );
  }
}

/// Brand mark: white bill slip with bill-text lines + mint badge cross.
/// Fractions mirror the launcher foreground mark 1:1 (1024-space geometry
/// divided by 1024), so the splash logo and the app icon are ditto.
class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;

    final Paint white = Paint()..color = Colors.white;
    const Color slate = Color(0xFF46558C);
    const Color mint = Color(0xFF00BFA5);

    // Bill slip: x 342-622, y 262-722, radius 56.
    final RRect slip = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.334, w * 0.256, w * 0.273, w * 0.449),
      Radius.circular(w * 0.055),
    );
    canvas.drawRRect(slip, white);

    // Mint header strip clipped to slip top (strip runs to y 360).
    canvas.save();
    canvas.clipRRect(slip);
    canvas.drawRect(
      Rect.fromLTWH(w * 0.334, w * 0.256, w * 0.273, w * 0.096),
      Paint()..color = mint,
    );
    canvas.restore();

    // Bill-text lines (x 392-…, y 430/492/554/616).
    final Paint slateP = Paint()
      ..color = slate
      ..strokeCap = StrokeCap.round
      ..strokeWidth = w * 0.025;
    canvas.drawLine(
        Offset(w * 0.383, w * 0.420), Offset(w * 0.559, w * 0.420), slateP);
    canvas.drawLine(
        Offset(w * 0.383, w * 0.480), Offset(w * 0.529, w * 0.480), slateP);
    canvas.drawLine(
        Offset(w * 0.383, w * 0.541), Offset(w * 0.500, w * 0.541), slateP);
    final Paint mintP = Paint()
      ..color = mint
      ..strokeCap = StrokeCap.round
      ..strokeWidth = w * 0.031;
    canvas.drawLine(
        Offset(w * 0.383, w * 0.602), Offset(w * 0.508, w * 0.602), mintP);

    // Badge: white ring r144 + mint disc r130 + white cross, center (660,640).
    final Offset c = Offset(w * 0.645, w * 0.625);
    canvas.drawCircle(c, w * 0.141, white);
    canvas.drawCircle(c, w * 0.127, Paint()..color = mint);
    final Paint crossP = Paint()
      ..color = Colors.white
      ..strokeCap = StrokeCap.round
      ..strokeWidth = w * 0.053;
    canvas.drawLine(
        Offset(c.dx, c.dy - w * 0.076), Offset(c.dx, c.dy + w * 0.076), crossP);
    canvas.drawLine(
        Offset(c.dx - w * 0.076, c.dy), Offset(c.dx + w * 0.076, c.dy), crossP);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
