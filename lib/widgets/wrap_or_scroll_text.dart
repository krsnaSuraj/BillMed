import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Text that is never cut off with an ellipsis, long supplier names in
/// particular. Behaviour, in order:
///
/// 1. the text fits [maxLines] lines: plain wrapped text, no motion, no cost;
/// 2. it does not fit: it walks across its own line ("marquee"), dwelling at
///    each end so it can be read, instead of ending in "...";
/// 3. animations are turned off at OS level (accessibility): static text that
///    never moves, ellipsised as the only remaining option.
///
/// Trade names in a medical khata are long ("Shree Ganesh Medical Agency
/// (Wholesale)" is 38 characters) while a phone row offers roughly 230 dp, so
/// both branches are needed in practice.
///
/// Why there is no [LayoutBuilder] here: these names live in rows wrapped in
/// `IntrinsicHeight` (a stretched row needs a finite height), and a
/// `LayoutBuilder` cannot answer intrinsic queries - it throws "LayoutBuilder
/// does not support returning intrinsic dimensions" and takes the whole row
/// down. Measurement therefore happens after layout, through the render
/// objects, which every ancestor can size without help.
class WrapOrScrollText extends StatefulWidget {
  const WrapOrScrollText({
    super.key,
    required this.name,
    required this.style,
    this.maxLines = 2,
  });

  final String name;
  final TextStyle style;

  /// Lines allowed before the text switches to the scrolling treatment.
  final int maxLines;

  @override
  State<WrapOrScrollText> createState() => _WrapOrScrollTextState();
}

class _WrapOrScrollTextState extends State<WrapOrScrollText> {
  final GlobalKey _staticKey = GlobalKey();

  /// True once this text was measured as actually clipped. Only a rendered
  /// measurement can tell: the same string fits or not depending on the font,
  /// the text scale, the locale and the column width.
  bool _scrolls = false;

  /// One pending post-frame check at a time.
  bool _checkScheduled = false;

  @override
  void didUpdateWidget(covariant WrapOrScrollText oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A renamed or restyled text (an edited supplier) deserves a fresh check.
    if (oldWidget.name != widget.name || oldWidget.style != widget.style) {
      _scrolls = false;
    }
  }

  void _scheduleClipCheck() {
    if (_checkScheduled) return;
    _checkScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkScheduled = false;
      if (!mounted || _scrolls) return;
      final RenderObject? box = _staticKey.currentContext?.findRenderObject();
      if (box is! RenderParagraph || !box.hasSize) return;
      if (!box.didExceedMaxLines) return;
      setState(() => _scrolls = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.name.isEmpty) {
      return Text('', style: widget.style);
    }
    if (!_scrolls) {
      _scheduleClipCheck();
      return Text(
        widget.name,
        key: _staticKey,
        maxLines: widget.maxLines,
        overflow: TextOverflow.ellipsis,
        style: widget.style,
      );
    }
    if (MediaQuery.disableAnimationsOf(context)) {
      // Accessibility: a shortened name beats a moving one.
      return Text(
        widget.name,
        maxLines: widget.maxLines,
        overflow: TextOverflow.ellipsis,
        style: widget.style,
      );
    }
    return _ScrollingName(name: widget.name, style: widget.style);
  }
}

/// One-line name that slides left until its end is visible, then slides back.
class _ScrollingName extends StatefulWidget {
  const _ScrollingName({required this.name, required this.style});

  final String name;
  final TextStyle style;

  @override
  State<_ScrollingName> createState() => _ScrollingNameState();
}

class _ScrollingNameState extends State<_ScrollingName>
    with SingleTickerProviderStateMixin {
  /// Reading speed of the travelling name in px per second: slow enough to
  /// read a trade name, fast enough not to feel stuck.
  static const double _pixelsPerSecond = 26;

  static const Duration _minCycle = Duration(milliseconds: 2600);
  static const Duration _maxCycle = Duration(milliseconds: 12000);

  /// Dwell at both ends, so the name is readable where it stops instead of
  /// snapping back the moment the last glyph appears.
  static const Curve _travel = Interval(0.12, 0.88, curve: Curves.easeInOut);

  /// A horizontal viewport gives the text its natural width without breaking
  /// any constraint: it takes the size its parent offers (so an app-bar title
  /// and an `IntrinsicHeight` row both stay valid) while the child inside is
  /// laid out unbounded and clipped. `OverflowBox` cannot do this - it sizes
  /// itself to the child and asserts inside a height-bounded parent.
  final ScrollController _scroll = ScrollController();

  late final AnimationController _controller =
      AnimationController(vsync: this, duration: _minCycle);
  late final Animation<double> _shift =
      CurvedAnimation(parent: _controller, curve: _travel);

  double _overflow = 0;
  bool _measured = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_applyOffset);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Cycle length follows the distance travelled, so a slightly-too-long name
  /// does not crawl for twelve seconds.
  static Duration _cycleFor(double overflow) {
    final int travel = (overflow / _pixelsPerSecond * 1000).round();
    return Duration(
      milliseconds: (travel + _minCycle.inMilliseconds)
          .clamp(_minCycle.inMilliseconds, _maxCycle.inMilliseconds),
    );
  }

  void _applyOffset() {
    if (!mounted || !_scroll.hasClients) return;
    final double target = (_overflow * _shift.value).clamp(0.0, _overflow);
    if ((_scroll.offset - target).abs() < 0.5) return;
    _scroll.jumpTo(target);
  }

  /// The overflow is only knowable after layout (`maxScrollExtent`), so it is
  /// read in a post-frame callback, never inside build.
  void _measure() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      if (!_scroll.position.hasContentDimensions) return;
      final double overflow = _scroll.position.maxScrollExtent;
      final bool changed = !_measured || (overflow - _overflow).abs() >= 1;
      _measured = true;
      if (!changed) return;
      if (overflow <= 0) {
        // Laid out wide enough after all (rotation, a wider tablet): stop the
        // ticker so an idle row does not burn battery.
        if (_controller.isAnimating) _controller.stop();
        setState(() => _overflow = 0);
        return;
      }
      _controller.duration = _cycleFor(overflow);
      if (!_controller.isAnimating) _controller.repeat(reverse: true);
      setState(() => _overflow = overflow);
    });
  }

  @override
  Widget build(BuildContext context) {
    _measure();
    return SingleChildScrollView(
      controller: _scroll,
      scrollDirection: Axis.horizontal,
      // The name travels on its own; a drag would fight the animation.
      physics: const NeverScrollableScrollPhysics(),
      // Semantics come from the Text itself, so a screen reader always
      // announces the whole name, moving or not.
      child: Text(
        widget.name,
        maxLines: 1,
        softWrap: false,
        style: widget.style,
      ),
    );
  }
}
