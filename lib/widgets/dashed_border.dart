import 'package:flutter/material.dart';

/// Border putus-putus dengan sudut membulat, mis. untuk kartu voucher.
class DashedRoundedBorder extends StatelessWidget {
  const DashedRoundedBorder({
    super.key,
    required this.child,
    required this.color,
    this.radius = 16,
    this.dashWidth = 6,
    this.gapWidth = 4,
    this.strokeWidth = 1.5,
  });

  final Widget child;
  final Color color;
  final double radius;
  final double dashWidth;
  final double gapWidth;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(
        color: color,
        radius: radius,
        dashWidth: dashWidth,
        gapWidth: gapWidth,
        strokeWidth: strokeWidth,
      ),
      child: child,
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({
    required this.color,
    required this.radius,
    required this.dashWidth,
    required this.gapWidth,
    required this.strokeWidth,
  });

  final Color color;
  final double radius;
  final double dashWidth;
  final double gapWidth;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics();

    for (final metric in metrics) {
      double distance = 0;
      while (distance < metric.length) {
        final next = distance + dashWidth;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          paint,
        );
        distance = next + gapWidth;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.radius != radius ||
      oldDelegate.dashWidth != dashWidth ||
      oldDelegate.gapWidth != gapWidth ||
      oldDelegate.strokeWidth != strokeWidth;
}
