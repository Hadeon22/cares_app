import 'package:flutter/material.dart';

import '../constants/app_constants.dart';

/// Wraps [child] in a staggered fade + upward slide entrance.
///
/// Usage:
/// ```dart
/// FadeSlide(delay: Duration(milliseconds: 120), child: MyCard())
/// ```
class FadeSlide extends StatefulWidget {
  const FadeSlide({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = AppDurations.slow,
    this.offsetY = 24,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;
  final double offsetY;

  @override
  State<FadeSlide> createState() => _FadeSlideState();
}

class _FadeSlideState extends State<FadeSlide>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  late final Animation<double> _opacity = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );

  late final Animation<Offset> _offset = Tween<Offset>(
    begin: Offset(0, widget.offsetY / 100),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _offset, child: widget.child),
    );
  }
}
