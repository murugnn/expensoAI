import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class SnowOverlay extends StatefulWidget {
  final bool isEnabled;

  const SnowOverlay({super.key, required this.isEnabled});

  @override
  State<SnowOverlay> createState() => _SnowOverlayState();
}

class _SnowOverlayState extends State<SnowOverlay>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _controller;
  final List<SnowParticle> _particles = [];
  final Random _random = Random();
  late Ticker _ticker;
  double _width = 0;
  double _height = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10), // Arbitrary, we use Ticker for physics
    )..repeat();

    // Use a Ticker for smooth physics updates independent of the controller's duration
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    if (!widget.isEnabled || _width == 0 || _height == 0) return;

    if (_particles.isEmpty) {
      _initParticles();
    }

    for (var particle in _particles) {
      particle.update(_width, _height);
    }
    // No set state here, the CustomPainter listens to the controller (repaint)
    // Actually, CustomPainter needs to repaint.
    // If we use AnimatedBuilder or similar, it handles repaints.
    // But since we update physics in _onTick, we might need to trigger repaint manually
    // or bind the painter to the ticker?
    // A simpler way: bind the painter to the _controller, and update physics in the painter?
    // No, physics in paint() is bad practice (framerate dependency).
    // Let's stick to _onTick updating state, and notify the painter.
  }
  
  void _initParticles() {
    // Generate 40-60 particles
    final count = 40 + _random.nextInt(20);
    for (int i = 0; i < count; i++) {
        _particles.add(SnowParticle(
            x: _random.nextDouble() * _width,
            y: _random.nextDouble() * _height,
            size: 1.0 + _random.nextDouble() * 2.5, // 1.0 - 3.5
            speed: 0.5 + _random.nextDouble() * 1.5, // 0.5 - 2.0
            opacity: 0.3 + _random.nextDouble() * 0.4, // 0.3 - 0.7
            swayOffset: _random.nextDouble() * 100,
        ));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _controller.stop(); 
      _ticker.stop();
    } else if (state == AppLifecycleState.resumed && widget.isEnabled) {
      _controller.repeat();
      if (!_ticker.isActive) _ticker.start();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isEnabled) return const SizedBox.shrink();

    return LayoutBuilder(builder: (context, constraints) {
      _width = constraints.maxWidth;
      _height = constraints.maxHeight;

      return IgnorePointer(
        child: AnimatedBuilder(
          animation: _controller, // Triggers repaint every frame
          builder: (context, child) {
            return CustomPaint(
              painter: SnowPainter(_particles),
              size: Size.infinite,
            );
          },
        ),
      );
    });
  }
}

class SnowParticle {
  double x;
  double y;
  double size;
  double speed;
  double opacity;
  double swayOffset;
  double swayPhase = 0;

  SnowParticle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.opacity,
    required this.swayOffset,
  });

  void update(double width, double height) {
    y += speed;
    swayPhase += 0.01;
    
    // Horizontal drift
    x += sin(swayPhase + swayOffset) * 0.3;

    // Reset if out of bounds
    if (y > height + 10) {
      y = -10;
      x = Random().nextDouble() * width;
      // Slight randomization on respawn
      speed = 0.5 + Random().nextDouble() * 1.5; 
      opacity = 0.3 + Random().nextDouble() * 0.4;
    }
    
    // Wrap x
    if (x > width + 10) x = -10;
    if (x < -10) x = width + 10;
  }
}

class SnowPainter extends CustomPainter {
  final List<SnowParticle> particles;

  SnowPainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;

    for (var particle in particles) {
      paint.color = Colors.white.withOpacity(particle.opacity);
      canvas.drawCircle(Offset(particle.x, particle.y), particle.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
