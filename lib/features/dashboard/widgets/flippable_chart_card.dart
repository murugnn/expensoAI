import 'dart:math';
import 'package:flutter/material.dart';

class FlippableChartCard extends StatefulWidget {
  final Widget front;
  final Widget back;

  const FlippableChartCard({super.key, required this.front, required this.back});

  @override
  State<FlippableChartCard> createState() => _FlippableChartCardState();
}

class _FlippableChartCardState extends State<FlippableChartCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isFront = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutBack,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _flip() {
    if (_isFront) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
    _isFront = !_isFront;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _flip,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          final angle = _animation.value * pi;
          // If angle > 90 degrees (pi/2), we are showing the back
          final isBackVisible = angle >= pi / 2;

          final transform = Matrix4.identity()
            ..setEntry(3, 2, 0.001) // perspective
            ..rotateY(angle);
            
          return Transform(
            alignment: Alignment.center,
            transform: transform,
            child: isBackVisible
                ? Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(pi), // correct mirror for back
                    child: widget.back,
                  )
                : widget.front,
          );
        },
      ),
    );
  }
}
