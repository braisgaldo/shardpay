import 'package:flutter/material.dart';

/// Marca visual de un idioma en el selector.
///
/// Casi todos los idiomas se representan con la bandera del país donde son
/// oficiales, pero el inglés y el árabe no pertenecen a un país concreto:
/// elegirles uno a dedo es una decisión política gratuita en una app de
/// dividir cuentas, así que llevan un icono neutro de idioma. El gallego y el
/// euskera se dibujan a mano porque no tienen emoji de bandera.
class LanguageFlag extends StatelessWidget {
  const LanguageFlag({super.key, required this.code, this.size = 22});

  final String code;
  final double size;

  /// Idiomas que llevan icono neutro en vez de bandera nacional.
  static const neutralIconCodes = <String>{'en', 'ar'};

  @override
  Widget build(BuildContext context) {
    if (neutralIconCodes.contains(code)) {
      return _NeutralLanguageIcon(size: size);
    }
    if (code == 'gl') {
      return _PaintedFlag(size: size, painter: _GaliciaFlagPainter());
    }
    if (code == 'eu') {
      return _PaintedFlag(size: size, painter: _BasqueFlagPainter());
    }
    if (code == 'ca') {
      return _PaintedFlag(size: size, painter: _SenyeraPainter());
    }

    final emoji = switch (code) {
      'es' => '🇪🇸',
      'fr' => '🇫🇷',
      'it' => '🇮🇹',
      'pt' => '🇵🇹',
      'de' => '🇩🇪',
      'el' => '🇬🇷',
      'ru' => '🇷🇺',
      'zh' => '🇨🇳',
      'ja' => '🇯🇵',
      _ => '🏳️',
    };

    return SizedBox(
      width: size * 1.45,
      height: size,
      child: Center(
        child: Text(emoji, style: TextStyle(fontSize: size * 0.9)),
      ),
    );
  }
}

class _NeutralLanguageIcon extends StatelessWidget {
  const _NeutralLanguageIcon({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size * 1.45,
      height: size,
      child: Center(
        child: Icon(Icons.translate_rounded, size: size * 0.85, color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );
  }
}

class _PaintedFlag extends StatelessWidget {
  const _PaintedFlag({required this.size, required this.painter});

  final double size;
  final CustomPainter painter;

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
      child: CustomPaint(painter: painter),
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

class _BasqueFlagPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFD52B1E));

    final green = Paint()
      ..color = const Color(0xFF009B48)
      ..strokeWidth = size.height * 0.16
      ..strokeCap = StrokeCap.butt;
    canvas.drawLine(Offset.zero, Offset(size.width, size.height), green);
    canvas.drawLine(Offset(0, size.height), Offset(size.width, 0), green);

    final white = Paint()
      ..color = Colors.white
      ..strokeWidth = size.height * 0.16
      ..strokeCap = StrokeCap.butt;
    canvas.drawLine(Offset(size.width / 2, 0), Offset(size.width / 2, size.height), white);
    canvas.drawLine(Offset(0, size.height / 2), Offset(size.width, size.height / 2), white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SenyeraPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFFCDD09));

    final stripe = Paint()..color = const Color(0xFFDA121A);
    const stripes = 4;
    final band = size.height / (stripes * 2 - 1);
    for (var index = 0; index < stripes; index++) {
      final top = band * (index * 2);
      canvas.drawRect(Rect.fromLTWH(0, top, size.width, band), stripe);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
