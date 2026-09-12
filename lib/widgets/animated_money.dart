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
    _animation = IntTween(begin: _displayed, end: _displayed).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
  }

  @override
  void didUpdateWidget(covariant AnimatedMoney oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.paise != widget.paise) {
      _controller.stop();
      _animation = IntTween(begin: _displayed, end: widget.paise).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
      )..addListener(() {
          setState(() => _displayed = _animation.value);
        });
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
