import 'package:flutter/material.dart';

import '../utils/money.dart';

/// Money text that animates from the old paise value to the new one.
class AnimatedMoney extends StatefulWidget {
  const AnimatedMoney({
    super.key,
    required this.paise,
    this.style,
  });

  final int paise;
  final TextStyle? style;

  @override
  State<AnimatedMoney> createState() => _AnimatedMoneyState();
}

class _AnimatedMoneyState extends State<AnimatedMoney>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<int> _animation;
  late int _displayed;

  @override
  void initState() {
    super.initState();
    _displayed = widget.paise;
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _animation = _tweenTo(_displayed);
    // One listener for the widget's whole life: adding a listener per value
    // change (the old shape) stacked a setState per frame for every update.
    _controller.addListener(_onTick);
  }

  void _onTick() {
    final int next = _animation.value;
    if (next != _displayed) setState(() => _displayed = next);
  }

  Animation<int> _tweenTo(int end) =>
      IntTween(begin: _displayed, end: end).animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

  @override
  void didUpdateWidget(covariant AnimatedMoney oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.paise != widget.paise) {
      // Snapshot first: the tween has to start where the display currently is.
      final int from = _displayed;
      _controller.stop();
      _displayed = from;
      _animation = _tweenTo(widget.paise);
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      formatPaise(_displayed),
      style: widget.style,
    );
  }
}
