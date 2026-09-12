import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Press-down scale feedback (1.0 → 0.97 over 120ms) shared by every ledger
/// row. Pass [index] for the staggered list entrance, [dividerIndent] for a
/// hairline divider under the row (null = no divider).
class PressScale extends StatefulWidget {
  const PressScale({
    super.key,
    required this.child,
    required this.onTap,
    this.index,
    this.dividerIndent,
    this.curve = Curves.linear,
    this.label,
  });

  final Widget child;
  final VoidCallback onTap;
  final int? index;
  final double? dividerIndent;
  final Curve curve;

  /// TalkBack label, e.g. the bill number or supplier name.
  final String? label;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  var _pressed = false;

  @override
  Widget build(BuildContext context) {
    final scaled = Semantics(
      button: true,
      label: widget.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: widget.curve,
          child: widget.dividerIndent == null
              ? widget.child
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    widget.child,
                    Divider(
                      height: 1,
                      indent: widget.dividerIndent!,
                      endIndent: widget.dividerIndent!,
                    ),
                  ],
                ),
        ),
      ),
    );
    final index = widget.index;
    if (index == null) return scaled;
    return AppMotion.fadeSlideIn(index: index, child: scaled);
  }
}
