import 'package:flutter/material.dart';

class SpringyChip extends StatefulWidget {
  final Widget child;
  final Offset? startOffset; // Optional: where the drag was released

  const SpringyChip({
    super.key,
    required this.child,
    this.startOffset,
  });

  @override
  State<SpringyChip> createState() => _SpringyChipState();
}

class _SpringyChipState extends State<SpringyChip> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _positionAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOutBack),
      ),
    );

    // Bouncy spring translation from top (or release point) to target
    final start = widget.startOffset ?? const Offset(0, -70);
    _positionAnimation = Tween<Offset>(begin: start, end: Offset.zero).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 1.0, curve: Curves.elasticOut), // Bounces back & forth
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: _positionAnimation.value,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: widget.child,
          ),
        );
      },
    );
  }
}
