import 'package:flutter/material.dart';

/// Subtle 3D perspective tilt reacting to scroll offset. Rebuilds only the
/// transform (child passed through) on scroll notifications.
class TiltOnScroll extends StatelessWidget {
  const TiltOnScroll({
    super.key,
    required this.scrollController,
    required this.child,
    this.maxTilt = 0.04,
  });

  final ScrollController scrollController;
  final Widget child;
  final double maxTilt;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: scrollController,
      builder: (context, child) {
        final double offset = scrollController.hasClients
            ? scrollController.offset.clamp(0, double.infinity)
            : 0;
        final double tilt = (offset * 0.0004).clamp(0, maxTilt);
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0015)
            ..rotateX(tilt),
          child: child,
        );
      },
      child: child,
    );
  }
}
