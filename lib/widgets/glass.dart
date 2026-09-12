import 'dart:ui';

import 'package:flutter/material.dart';

/// Frosted-glass surface. Caller provides shape via parent ClipRRect/Container.
class GlassBar extends StatelessWidget {
  const GlassBar({super.key, required this.child, this.opacity = 0.72});

  final Widget child;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final tint = dark
        ? Colors.black.withValues(alpha: opacity * 0.86)
        : Colors.white.withValues(alpha: opacity);
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(color: tint, child: child),
      ),
    );
  }
}
