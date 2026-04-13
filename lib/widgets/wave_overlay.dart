import 'dart:math';
import 'package:flutter/material.dart';

class WaveOverlay extends StatefulWidget {
  final Widget? child;

  const WaveOverlay({super.key, this.child});

  @override
  State<WaveOverlay> createState() => _WaveOverlayState();
}

class _WaveOverlayState extends State<WaveOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20), // Slow, calm movement
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      return Stack(
        children: [
          if (widget.child != null) widget.child!,
          IgnorePointer(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return CustomPaint(
                  size: Size(constraints.maxWidth, constraints.maxHeight),
                  painter: WavePainter(
                    progress: _controller.value,
                    color: Theme.of(context).colorScheme.primary,
                    isDark: Theme.of(context).brightness == Brightness.dark,
                  ),
                );
              },
            ),
          ),
        ],
      );
    });
  }
}

class WavePainter extends CustomPainter {
  final double progress;
  final Color color;
  final bool isDark;

  WavePainter({
    required this.progress,
    required this.color,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Base oscillation
    final double t = progress * 2 * pi;

    // We draw 3 waves with different phases and speeds
    _drawWave(canvas, size, paint, t, 1.0, 0.05, 0.0); // Background, slow
    _drawWave(canvas, size, paint, t, 1.2, 0.08, 2.0); // Middle
    _drawWave(canvas, size, paint, t, 1.5, 0.12, 4.0); // Foreground, faster
  }

  void _drawWave(Canvas canvas, Size size, Paint paint, double time,
      double speed, double opacity, double verticalOffset) {
    
    // Adjust color based on theme
    final baseColor = isDark ? Colors.white : color;
    paint.color = baseColor.withOpacity(opacity);

    final path = Path();
    final width = size.width;
    final height = size.height;
    final midY = height * 0.5 + (verticalOffset * 20);

    path.moveTo(0, midY);

    for (double x = 0; x <= width; x += 10) {
      // Sine wave calculation
      // y = A * sin(kx - wt)
      
      final normalizedX = x / width;
      
      // Amplitude varies slightly across screen
      final amplitude = 40.0 + 10 * sin(normalizedX * 2 * pi);
      
      final y = midY +
          amplitude *
              sin((normalizedX * 4 * pi) + (time * speed) + verticalOffset);

      path.lineTo(x, y);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant WavePainter oldDelegate) => true;
}
