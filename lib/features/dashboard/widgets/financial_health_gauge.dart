import 'dart:math';
import 'package:flutter/material.dart';

class FinancialHealthGauge extends StatelessWidget {
  final int score;
  final String grade;
  final VoidCallback onTap;

  const FinancialHealthGauge({
    super.key,
    required this.score,
    required this.grade,
    required this.onTap,
  });

  Color _getScoreColor() {
    if (score >= 80) return const Color(0xFF10B981); // Emerald Green
    if (score >= 60) return const Color(0xFF3B82F6); // Blue
    if (score >= 40) return const Color(0xFFF59E0B); // Amber
    return const Color(0xFFEF4444); // Red
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final color = _getScoreColor();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withOpacity(0.3),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: cs.outlineVariant.withOpacity(0.5)),
        ),
        child: Row(
          children: [
            // Gauge Graphic
            SizedBox(
              width: 80,
              height: 44, // Slightly taller to fit stroke comfortably
              child: CustomPaint(
                painter: _SemiCircleGaugePainter(
                  score: score,
                  trackColor: cs.outlineVariant.withOpacity(0.5),
                  progressColor: color,
                ),
              ),
            ),
            const SizedBox(width: 24),
            // Information
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Financial Health',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '$score',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: cs.onSurface,
                          height: 1.1,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          grade,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: color,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: cs.onSurfaceVariant, size: 20),
          ],
        ),
      ),
    );
  }
}

class _SemiCircleGaugePainter extends CustomPainter {
  final int score;
  final Color trackColor;
  final Color progressColor;

  _SemiCircleGaugePainter({
    required this.score,
    required this.trackColor,
    required this.progressColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 12.0;
    
    // Position center slightly up so arc sits correctly
    final center = Offset(size.width / 2, size.height);
    final radius = size.width / 2 - (strokeWidth / 2);
    
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromCircle(center: center, radius: radius);

    // Draw background track (Semi-circle: 180 degrees)
    canvas.drawArc(rect, pi, pi, false, trackPaint);

    // Draw active track
    final progressAngle = (score / 100) * pi;
    canvas.drawArc(rect, pi, progressAngle, false, progressPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
