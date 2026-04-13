import 'dart:math';
import 'package:flutter/material.dart';

class CrystalSparkleOverlay extends StatefulWidget {
  final Widget? child;

  const CrystalSparkleOverlay({super.key, this.child});

  @override
  State<CrystalSparkleOverlay> createState() => _CrystalSparkleOverlayState();
}

class _Crystal {
  double x; // Normalized 0..1
  double y; // Normalized 0..1
  double size; 
  double opacity;
  double vx; // Velocity X
  double vy; // Velocity Y
  double rotation;
  double rotationSpeed;
  
  // Shimmer
  double shimmerPhase; // 0.0 means no shimmer. 
  double shimmerSpeed;
  bool isShimmering;

  _Crystal({
    required this.x,
    required this.y,
    required this.size,
    required this.opacity,
    required this.vx,
    required this.vy,
    required this.rotation,
    required this.rotationSpeed,
    this.shimmerPhase = 0.0,
    this.shimmerSpeed = 0.0,
    this.isShimmering = false,
  });
}

class _CrystalSparkleOverlayState extends State<CrystalSparkleOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_Crystal> _crystals = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(seconds: 30))
      ..addListener(_updateCrystals)
      ..repeat(); 
      
    // Spawn 8-10 crystals
    for (int i = 0; i < 8; i++) {
        _crystals.add(_createCrystal());
    }
  }

  _Crystal _createCrystal() {
    double size = 20.0 + _random.nextDouble() * 40.0;
    // Larger = slower
    double speedMult = (60.0 - size) / 60.0; // 0.0 - 0.66
    
    return _Crystal(
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        size: size,
        opacity: 0.06 + _random.nextDouble() * 0.06, // 0.06 - 0.12
        vx: (_random.nextDouble() - 0.5) * 0.0003 * (1 + speedMult), 
        vy: (_random.nextDouble() - 0.5) * 0.0003 * (1 + speedMult),
        rotation: _random.nextDouble() * pi * 2,
        rotationSpeed: (_random.nextDouble() - 0.5) * 0.002,
    );
  }

  void _updateCrystals() {
    for (var crystal in _crystals) {
        // Move
        crystal.x += crystal.vx;
        crystal.y += crystal.vy;
        crystal.rotation += crystal.rotationSpeed;

        // Wrap
        if (crystal.x < -0.2) crystal.x = 1.2;
        if (crystal.x > 1.2) crystal.x = -0.2;
        if (crystal.y < -0.2) crystal.y = 1.2;
        if (crystal.y > 1.2) crystal.y = -0.2;
        
        // Random shimmer trigger
        if (!crystal.isShimmering && _random.nextDouble() < 0.005) { // ~0.5% chance per frame
            crystal.isShimmering = true;
            crystal.shimmerPhase = 0.0;
            crystal.shimmerSpeed = 0.02 + _random.nextDouble() * 0.03;
        }
        
        if (crystal.isShimmering) {
            crystal.shimmerPhase += crystal.shimmerSpeed;
            if (crystal.shimmerPhase >= 1.0) {
                crystal.isShimmering = false;
                crystal.shimmerPhase = 0.0;
            }
        }
    }
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
                  painter: CrystalPainter(
                    crystals: _crystals,
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

class CrystalPainter extends CustomPainter {
  final List<_Crystal> crystals;
  final bool isDark;

  CrystalPainter({required this.crystals, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0); // Mild blur for soft edges
    
    final Color baseColor = isDark 
        ? Colors.white // Silver/White
        : Colors.blueGrey.shade100; // Soft silver/grey for light mode
        
    for (var crystal in crystals) {
        canvas.save();
        
        double cx = crystal.x * size.width;
        double cy = crystal.y * size.height;
        
        canvas.translate(cx, cy);
        canvas.rotate(crystal.rotation);
        
        // Shimmer opacity boost
        double shimmerOp = 0.0;
        if (crystal.isShimmering) {
            // Sine wave 0->1->0
            shimmerOp = sin(crystal.shimmerPhase * pi) * 0.15;
        }
        
        final double finalOpacity = (crystal.opacity + shimmerOp).clamp(0.0, 1.0);
        
        // Gradient fill for depth
        final rect = Rect.fromCenter(center: Offset.zero, width: crystal.size, height: crystal.size * 1.5);
        paint.shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
             baseColor.withOpacity(finalOpacity * 1.2), // Highlight
             baseColor.withOpacity(finalOpacity * 0.5), // Shadow
          ]
        ).createShader(rect);

        // Draw Diamond Shape
        final path = Path();
        path.moveTo(0, -crystal.size * 0.8); // Top
        path.lineTo(crystal.size * 0.5, 0); // Right
        path.lineTo(0, crystal.size * 0.8); // Bottom
        path.lineTo(-crystal.size * 0.5, 0); // Left
        path.close();
        
        canvas.drawPath(path, paint);
        
        // Optional: White glint during peak shimmer
        if (crystal.isShimmering && crystal.shimmerPhase > 0.4 && crystal.shimmerPhase < 0.6) {
           final glintPaint = Paint()
             ..color = Colors.white.withOpacity(0.3)
             ..style = PaintingStyle.fill
             ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.0);
             
           canvas.drawCircle(Offset(-crystal.size * 0.2, -crystal.size * 0.2), 2.0, glintPaint);
        }

        canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CrystalPainter oldDelegate) => true;
}
