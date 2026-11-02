import 'dart:math' as math;
import 'package:flutter/material.dart';

class PostureStickFigure extends StatelessWidget {
  final double pitchUpper;
  final double pitchLower;
  final int postureState;
  final int stepCount;
  final Size size;

  const PostureStickFigure({
    super.key,
    required this.pitchUpper,
    required this.pitchLower,
    required this.postureState,
    required this.stepCount,
    this.size = const Size(120, 160),
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    Color figureColor;
    if (postureState == 0) {
      figureColor = Colors.green;
    } else if (postureState == 1) {
      figureColor = colors.error;
    } else if (postureState == 2) {
      figureColor = Colors.deepOrange;
    } else {
      figureColor = Colors.black;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
          tween: Tween<double>(end: pitchUpper),
          builder: (context, animUpper, child) {
            return TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 100),
              curve: Curves.easeOut,
              tween: Tween<double>(end: pitchLower),
              builder: (context, animLower, child) {
                return CustomPaint(
                  size: size,
                  painter: _StickFigurePainter(
                    pitchUpper: animUpper,
                    pitchLower: animLower,
                    color: figureColor,
                  ),
                );
              },
            );
          },
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.directions_walk, size: 16, color: colors.primary),
            const SizedBox(width: 4),
            Text(
              "$stepCount",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: colors.onSurface,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StickFigurePainter extends CustomPainter {
  final double pitchUpper;
  final double pitchLower;
  final Color color;

  _StickFigurePainter({
    required this.pitchUpper,
    required this.pitchLower,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final double centerX = size.width / 2;

    final double baseStartX = centerX - 10;
    final double baseY = size.height * 0.8;

    final double radUpper = pitchUpper * math.pi / 180;
    final double radLower = pitchLower * math.pi / 180;

    canvas.drawLine(
      Offset(baseStartX, baseY),
      Offset(baseStartX - 10, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(baseStartX, baseY),
      Offset(baseStartX + 10, size.height),
      paint,
    );

    double lowerLength = size.height * 0.25;
    double waistEndX = baseStartX + lowerLength * math.cos(radLower);
    double waistEndY = baseY - lowerLength * math.sin(radLower);
    canvas.drawLine(
      Offset(baseStartX, baseY),
      Offset(waistEndX, waistEndY),
      paint,
    );

    double upperLength = size.height * 0.25;
    double backEndX = waistEndX + upperLength * math.cos(radUpper);
    double backEndY = waistEndY - upperLength * math.sin(radUpper);
    canvas.drawLine(
      Offset(waistEndX, waistEndY),
      Offset(backEndX, backEndY),
      paint,
    );

    final headPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    double headRadius = 12.0;
    double headX = backEndX + 5 * math.cos(radUpper);
    double headY = backEndY - 5 * math.sin(radUpper);
    canvas.drawCircle(Offset(headX, headY), headRadius, headPaint);

    canvas.drawLine(
      Offset(
        waistEndX + (backEndX - waistEndX) * 0.5,
        waistEndY + (backEndY - waistEndY) * 0.5,
      ),
      Offset(
        waistEndX + (backEndX - waistEndX) * 0.5 + 15,
        waistEndY + (backEndY - waistEndY) * 0.5 + 20,
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _StickFigurePainter oldDelegate) {
    return oldDelegate.pitchUpper != pitchUpper ||
        oldDelegate.pitchLower != pitchLower ||
        oldDelegate.color != color;
  }
}
