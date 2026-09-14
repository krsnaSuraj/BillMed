import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'sparkline.dart';

/// Animated draw-in reveal for [MiniSparkline]: clips left-to-right over
/// 900ms (easeOutCubic) with a fade. Same values contract (paise doubles).
class DrawSparkline extends StatefulWidget {
  const DrawSparkline(
      {super.key, required this.values, this.height = 72, this.color});

  final List<double> values;
  final double height;
  final Color? color;

  @override
  State<DrawSparkline> createState() => _DrawSparklineState();
}

class _DrawSparklineState extends State<DrawSparkline>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  late final Animation<double> _progress =
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);

  @override
  void initState() {
    super.initState();
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(covariant DrawSparkline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.values, widget.values)) {
      _ctrl
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.values.length < 2 || widget.values.every((v) => v <= 0)) {
      return const SizedBox.shrink();
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final chart = MiniSparkline(
          values: widget.values,
          height: widget.height,
          color: widget.color,
        );
        // Unbounded width (e.g. inside scrollables without constraints):
        // fade only, no clip reveal.
        if (!constraints.hasBoundedWidth) {
          return FadeTransition(opacity: _progress, child: chart);
        }
        return AnimatedBuilder(
          animation: _progress,
          builder: (context, child) => Opacity(
            opacity: _progress.value,
            child: ClipRect(
              child: Align(
                alignment: Alignment.centerLeft,
                widthFactor: _progress.value == 0 ? 0.01 : _progress.value,
                child: child,
              ),
            ),
          ),
          child: chart,
        );
      },
    );
  }
}
