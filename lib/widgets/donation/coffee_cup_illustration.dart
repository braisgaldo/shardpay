import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Taza de café dibujada a mano con `CustomPaint`.
///
/// Es vectorial y toma los colores del tema activo a propósito: un PNG o un
/// emoji se quedarían con su propio color y desentonarían en los temas oscuros
/// y en los de acento verde o azul. Así la ilustración cambia con la app.
///
/// El vapor ondula en un ciclo de unos tres segundos. Si el sistema pide
/// reducir animaciones, se dibuja quieto.
class CoffeeCupIllustration extends StatefulWidget {
  const CoffeeCupIllustration({super.key, required this.semanticsLabel, this.size = 132, this.animate = true});

  /// Descripción para lectores de pantalla. Obligatoria: una ilustración sin
  /// texto alternativo es invisible con TalkBack o VoiceOver.
  final String semanticsLabel;

  final double size;

  /// Permite congelar el vapor sin quitar la ilustración.
  final bool animate;

  @override
  State<CoffeeCupIllustration> createState() => _CoffeeCupIllustrationState();
}

class _CoffeeCupIllustrationState extends State<CoffeeCupIllustration> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(seconds: 3));

  @override
  void initState() {
    super.initState();
    if (widget.animate) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(CoffeeCupIllustration oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.animate && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Respeta la preferencia del sistema de reducir animaciones.
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final animate = widget.animate && !reduceMotion;

    if (animate && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!animate && _controller.isAnimating) {
      _controller.stop();
    }

    return Semantics(
      label: widget.semanticsLabel,
      image: true,
      excludeSemantics: true,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return CustomPaint(
              painter: _CoffeeCupPainter(
                progress: animate ? _controller.value : 0.35,
                cup: scheme.primary,
                cupShade: scheme.primaryContainer,
                coffee: scheme.onPrimaryContainer,
                steam: scheme.secondary,
                saucer: scheme.tertiary,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CoffeeCupPainter extends CustomPainter {
  _CoffeeCupPainter({
    required this.progress,
    required this.cup,
    required this.cupShade,
    required this.coffee,
    required this.steam,
    required this.saucer,
  });

  final double progress;
  final Color cup;
  final Color cupShade;
  final Color coffee;
  final Color steam;
  final Color saucer;

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.width / 100;

    _paintSteam(canvas, unit);
    _paintSaucer(canvas, unit);
    _paintCup(canvas, unit);
  }

  void _paintSteam(Canvas canvas, double unit) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = unit * 3
      ..strokeCap = StrokeCap.round;

    // Tres trazos desfasados: el ojo lee el conjunto como vapor subiendo,
    // aunque cada trazo por separado sea una simple onda.
    for (var index = 0; index < 3; index++) {
      final phase = progress + index * 0.28;
      final wobble = math.sin(phase * math.pi * 2);
      final rise = (phase % 1) * 0.4;
      final opacity = (1 - (phase % 1)) * 0.5 + 0.12;

      paint.color = steam.withValues(alpha: opacity.clamp(0.0, 0.7));

      final x = unit * (34 + index * 16);
      final top = unit * (6 - rise * 6);
      final bottom = unit * 30;

      final path = Path()
        ..moveTo(x, bottom)
        ..cubicTo(
          x + wobble * unit * 5,
          bottom - (bottom - top) * 0.35,
          x - wobble * unit * 5,
          bottom - (bottom - top) * 0.7,
          x + wobble * unit * 2,
          top,
        );
      canvas.drawPath(path, paint);
    }
  }

  void _paintSaucer(Canvas canvas, double unit) {
    final paint = Paint()..color = saucer.withValues(alpha: 0.32);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(unit * 14, unit * 84, unit * 72, unit * 8), Radius.circular(unit * 4)), paint);
  }

  void _paintCup(Canvas canvas, double unit) {
    final body = Path()
      ..moveTo(unit * 26, unit * 38)
      ..lineTo(unit * 74, unit * 38)
      ..cubicTo(unit * 73, unit * 74, unit * 66, unit * 84, unit * 50, unit * 84)
      ..cubicTo(unit * 34, unit * 84, unit * 27, unit * 74, unit * 26, unit * 38)
      ..close();

    canvas.drawPath(body, Paint()..color = cup);

    // Asa.
    final handle = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = unit * 6
      ..strokeCap = StrokeCap.round
      ..color = cup;
    canvas.drawArc(Rect.fromLTWH(unit * 68, unit * 44, unit * 22, unit * 24), -math.pi / 2.2, math.pi * 1.05, false, handle);

    // Borde y superficie del café.
    canvas.drawOval(Rect.fromLTWH(unit * 24, unit * 32, unit * 52, unit * 13), Paint()..color = cupShade);
    canvas.drawOval(Rect.fromLTWH(unit * 29, unit * 35, unit * 42, unit * 8), Paint()..color = coffee.withValues(alpha: 0.85));
  }

  @override
  bool shouldRepaint(covariant _CoffeeCupPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.cup != cup ||
        oldDelegate.steam != steam ||
        oldDelegate.coffee != coffee ||
        oldDelegate.saucer != saucer ||
        oldDelegate.cupShade != cupShade;
  }
}
