import 'package:flutter/material.dart';

class LanguageFlag extends StatelessWidget {
  const LanguageFlag({super.key, required this.code, this.size = 22});

  final String code;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (code == 'gl') {
      return _GaliciaFlag(size: size);
    }

    final emoji = switch (code) {
      'es' => '🇪🇸',
      'en' => '🇬🇧',
      'fr' => '🇫🇷',
      'it' => '🇮🇹',
      'pt' => '🇵🇹',
      'de' => '🇩🇪',
      'ru' => '🇷🇺',
      'zh' => '🇨🇳',
      'ja' => '🇯🇵',
      _ => '🏳️',
    };

    return SizedBox(
      width: size * 1.45,
      height: size,
      child: Center(
        child: Text(
          emoji,
          style: TextStyle(fontSize: size * 0.9),
        ),
      ),
    );
  }
}

class _GaliciaFlag extends StatelessWidget {
  const _GaliciaFlag({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size * 1.45,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0x220F172A)),
      ),
      clipBehavior: Clip.antiAlias,
      child: CustomPaint(
        painter: _GaliciaFlagPainter(),
      ),
    );
  }
}

class _GaliciaFlagPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF6EC1FF);
    final path = Path()
      ..moveTo(size.width * 0.18, 0)
      ..lineTo(size.width * 0.42, 0)
      ..lineTo(size.width * 0.82, size.height)
      ..lineTo(size.width * 0.58, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
