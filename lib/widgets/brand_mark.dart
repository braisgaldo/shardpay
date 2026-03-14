import 'package:flutter/material.dart';

class ShardPayBrandMark extends StatelessWidget {
  const ShardPayBrandMark({
    super.key,
    this.size = 48,
    this.borderRadius,
    this.backgroundColor,
    this.padding = const EdgeInsets.all(0),
  });

  final double size;
  final double? borderRadius;
  final Color? backgroundColor;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? size * 0.28;

    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: ColoredBox(
          color: backgroundColor ?? Colors.transparent,
          child: Padding(
            padding: padding,
            child: CustomPaint(
              painter: _ShardPayBrandMarkPainter(),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShardPayBrandMarkPainter extends CustomPainter {
  static const double _viewBox = 108;

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / _viewBox;
    final scaleY = size.height / _viewBox;

    void fillPolygon(List<Offset> points, Color color, {double alpha = 1}) {
      final path = Path()..moveTo(points.first.dx * scaleX, points.first.dy * scaleY);
      for (final point in points.skip(1)) {
        path.lineTo(point.dx * scaleX, point.dy * scaleY);
      }
      path.close();
      canvas.drawPath(path, Paint()..color = color.withValues(alpha: alpha));
    }

    fillPolygon(const [Offset(54, 14), Offset(84, 30), Offset(77, 76), Offset(54, 94), Offset(31, 76), Offset(24, 30)], const Color(0xFFAA3B05));
    fillPolygon(const [Offset(54, 18), Offset(79, 31), Offset(73, 73), Offset(54, 88), Offset(35, 73), Offset(29, 31)], const Color(0xFFD3540E));
    fillPolygon(const [Offset(54, 18), Offset(54, 32), Offset(38, 42), Offset(30, 35)], const Color(0xFFFF7A1A));
    fillPolygon(const [Offset(54, 18), Offset(79, 31), Offset(74, 43), Offset(54, 32)], const Color(0xFFFF8A1E));
    fillPolygon(const [Offset(31, 47), Offset(44, 56), Offset(36, 73), Offset(28, 61)], const Color(0xFFC34A10));
    fillPolygon(const [Offset(39, 41), Offset(54, 32), Offset(54, 52), Offset(43, 59), Offset(32, 52)], const Color(0xFFE56613));
    fillPolygon(const [Offset(54, 32), Offset(74, 43), Offset(69, 56), Offset(54, 52)], const Color(0xFFFF9D3B));
    fillPolygon(const [Offset(43, 59), Offset(47, 76), Offset(36, 73)], const Color(0xFFB33E0A));
    fillPolygon(const [Offset(54, 52), Offset(69, 56), Offset(79, 76), Offset(62, 78)], const Color(0xFFF57D1D));
    fillPolygon(const [Offset(62, 78), Offset(54, 88), Offset(79, 76)], const Color(0xFFD65710));
    fillPolygon(const [Offset(31, 76), Offset(54, 94), Offset(43, 78)], const Color(0xFFA03607));

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
    canvas.drawPath(arrow, Paint()..color = Colors.white);

    final arrowInner = Path()
      ..moveTo(54 * scaleX, 26 * scaleY)
      ..lineTo(61 * scaleX, 34 * scaleY)
      ..lineTo(57 * scaleX, 34 * scaleY)
      ..lineTo(57 * scaleX, 58 * scaleY)
      ..lineTo(61 * scaleX, 58 * scaleY)
      ..lineTo(54 * scaleX, 65 * scaleY)
      ..lineTo(47 * scaleX, 58 * scaleY)
      ..lineTo(51 * scaleX, 58 * scaleY)
      ..lineTo(51 * scaleX, 34 * scaleY)
      ..lineTo(47 * scaleX, 34 * scaleY)
      ..close();
    canvas.drawPath(arrowInner, Paint()..color = const Color(0xFFFFF4E7));

    final highlight = Path()
      ..moveTo(31 * scaleX, 26 * scaleY)
      ..cubicTo(46 * scaleX, 16 * scaleY, 66 * scaleX, 16 * scaleY, 81 * scaleX, 23 * scaleY)
      ..cubicTo(88 * scaleX, 26 * scaleY, 94 * scaleX, 30 * scaleY, 98 * scaleX, 34 * scaleY)
      ..cubicTo(96 * scaleX, 26 * scaleY, 90 * scaleX, 20 * scaleY, 82 * scaleX, 17 * scaleY)
      ..cubicTo(69 * scaleX, 12 * scaleY, 47 * scaleX, 13 * scaleY, 31 * scaleX, 26 * scaleY)
      ..close();
    canvas.drawPath(highlight, Paint()..color = const Color(0xFFF7B06E).withValues(alpha: 0.45));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}