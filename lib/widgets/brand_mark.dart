import 'package:flutter/material.dart';

class ShardPayBrandMark extends StatelessWidget {
  const ShardPayBrandMark({
    super.key,
    this.size = 48,
    this.borderRadius,
    this.backgroundColor,
    this.foregroundColor,
    this.padding = const EdgeInsets.all(0),
  });

  final double size;
  final double? borderRadius;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? size * 0.28;
    final resolvedBackground = backgroundColor ?? Colors.white;
    final resolvedForeground = foregroundColor ?? const Color(0xFF111111);

    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: ColoredBox(
          color: resolvedBackground,
          child: Padding(
            padding: padding,
            child: CustomPaint(
              painter: _ShardPayBrandMarkPainter(color: resolvedForeground),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShardPayBrandMarkPainter extends CustomPainter {
  const _ShardPayBrandMarkPainter({required this.color});

  static const double _viewBox = 108;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / _viewBox;
    final scaleY = size.height / _viewBox;

    final shell = Path()
      ..moveTo(54 * scaleX, 14 * scaleY)
      ..lineTo(84 * scaleX, 30 * scaleY)
      ..lineTo(77 * scaleX, 76 * scaleY)
      ..lineTo(54 * scaleX, 94 * scaleY)
      ..lineTo(31 * scaleX, 76 * scaleY)
      ..lineTo(24 * scaleX, 30 * scaleY)
      ..close();
    canvas.drawPath(shell, Paint()..color = color);

    final arrow = Path()
      ..moveTo(54 * scaleX, 21 * scaleY)
      ..lineTo(68 * scaleX, 36 * scaleY)
      ..lineTo(61 * scaleX, 36 * scaleY)
      ..lineTo(61 * scaleX, 54 * scaleY)
      ..lineTo(70 * scaleX, 54 * scaleY)
      ..lineTo(54 * scaleX, 71 * scaleY)
      ..lineTo(38 * scaleX, 54 * scaleY)
      ..lineTo(47 * scaleX, 54 * scaleY)
      ..lineTo(47 * scaleX, 36 * scaleY)
      ..lineTo(40 * scaleX, 36 * scaleY)
      ..close();
    canvas.drawPath(arrow, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}