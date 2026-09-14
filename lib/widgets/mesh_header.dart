import 'package:flutter/material.dart';

/// Aurora mesh backdrop: soft indigo/teal/mint blobs on transparent canvas.
/// Place in a Stack behind headers; content sits on top.
class MeshHeader extends StatelessWidget {
  const MeshHeader({super.key, this.height = 230});

  final double height;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: ClipRect(
        // Melt the bottom edge into the background: without this the
        // header band ends in a hard visible line (see Bills screen).
        child: ShaderMask(
          shaderCallback: (r) => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black, Colors.black, Colors.transparent],
            stops: [0.0, 0.62, 1.0],
          ).createShader(r),
          blendMode: BlendMode.dstIn,
          child: CustomPaint(painter: _MeshPainter(dark: dark)),
        ),
      ),
    );
  }
}

class _MeshPainter extends CustomPainter {
  _MeshPainter({required this.dark});

  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    // Base wash.
    final wash = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: dark
          ? [
              const Color(0xFF1A237E).withValues(alpha: 0.55),
              Colors.transparent,
            ]
          : [
              const Color(0xFF534BAE).withValues(alpha: 0.22),
              Colors.transparent,
            ],
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..shader = wash,
    );

    // Soft blobs: concentric circles, decreasing alpha.
    _blob(canvas, Offset(size.width * 0.85, -size.height * 0.15),
        size.height * 0.55, const Color(0xFF00BFA5), dark ? 0.20 : 0.13);
    _blob(canvas, Offset(size.width * 0.12, -size.height * 0.10),
        size.height * 0.45, const Color(0xFF0096AA), dark ? 0.22 : 0.12);
    _blob(canvas, Offset(size.width * 0.55, size.height * 0.25),
        size.height * 0.60, const Color(0xFF1A237E), dark ? 0.34 : 0.10);
  }

  void _blob(Canvas canvas, Offset center, double radius, Color color,
      double peakAlpha) {
    for (var i = 5; i >= 1; i--) {
      canvas.drawCircle(
        center,
        radius * i / 5,
        Paint()..color = color.withValues(alpha: peakAlpha * (6 - i) / 5),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MeshPainter oldDelegate) =>
      oldDelegate.dark != dark;
}
