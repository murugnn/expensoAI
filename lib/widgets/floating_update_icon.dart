import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:url_launcher/url_launcher.dart';

class FloatingUpdateIcon extends StatefulWidget {
  final VoidCallback onTap;

  const FloatingUpdateIcon({super.key, required this.onTap});

  @override
  State<FloatingUpdateIcon> createState() => _FloatingUpdateIconState();
}

class _FloatingUpdateIconState extends State<FloatingUpdateIcon> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _animation;
  Offset _offset = const Offset(20, 100); // Initial position
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _controller.addListener(() {
      setState(() {
        _offset = _animation.value;
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _snapToEdge(Size screenSize, Size widgetSize) {
    final double left = _offset.dx;
    final double right = screenSize.width - widgetSize.width - left;
    
    // Snap to closest side
    final double targetX = (left < right) ? 16.0 : screenSize.width - widgetSize.width - 16.0;
    
    // Keep Y within bounds (with safe area approximation)
    double targetY = _offset.dy;
    if (targetY < kToolbarHeight + 20) targetY = kToolbarHeight + 20;
    if (targetY > screenSize.height - kBottomNavigationBarHeight - widgetSize.height - 20) {
      targetY = screenSize.height - kBottomNavigationBarHeight - widgetSize.height - 20;
    }

    _animation = Tween<Offset>(
      begin: _offset,
      end: Offset(targetX, targetY),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));

    _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          left: _offset.dx,
          top: _offset.dy,
          child: GestureDetector(
            onPanStart: (_) {
               setState(() => _isDragging = true);
               _controller.stop();
            },
            onPanUpdate: (details) {
              setState(() {
                _offset += details.delta;
              });
            },
            onPanEnd: (details) {
              setState(() => _isDragging = false);
              final screenSize = MediaQuery.of(context).size;
              // Approximate widget size (fab size)
              _snapToEdge(screenSize, const Size(56, 56));
            },
            onTap: widget.onTap,
            child: Material(
               color: Colors.transparent,
               elevation: _isDragging ? 10 : 5,
               shape: const CircleBorder(),
               child: Container(
                 width: 50,
                 height: 50,
                 decoration: BoxDecoration(
                   shape: BoxShape.circle,
                   image: const DecorationImage(
                     image: AssetImage('assets/icons/login.png'),
                     fit: BoxFit.contain,
                   ),
                   boxShadow: const [
                     BoxShadow(
                       color: Colors.black26,
                       blurRadius: 8,
                       offset: Offset(0, 4),
                     )
                   ],
                 ),
               ),
            ),
          ),
        ),
      ],
    );
  }
}
