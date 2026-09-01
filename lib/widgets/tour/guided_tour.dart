import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/app_text.dart';

/// Un paso del tour guiado.
///
/// Si [targetKey] apunta a un widget montado, el paso lo ilumina recortando el
/// velo oscuro justo encima. Si es `null`, el paso se muestra centrado: sirve
/// para la bienvenida y la despedida.
class TourStep {
  const TourStep({
    required this.title,
    required this.body,
    required this.icon,
    this.targetKey,
    this.illustration,
    this.onEnter,
    this.padding = 8,
    this.radius = 20,
  });

  final String title;
  final String body;
  final IconData icon;
  final GlobalKey? targetKey;

  /// Contenido extra bajo el texto: una tabla de ejemplo, un desglose de
  /// saldos… Sirve para enseñar números concretos en lugar de describirlos.
  final Widget? illustration;

  /// Se ejecuta al entrar en el paso, **antes** de medir el elemento.
  ///
  /// Es lo que permite que el tour cambie de pestaña y siga iluminando el
  /// widget correcto: primero se navega, luego se mide.
  final Future<void> Function()? onEnter;

  /// Margen alrededor del elemento iluminado.
  final double padding;

  /// Redondeo del recorte.
  final double radius;
}

/// Lanza el tour guiado.
///
/// Sustituye a la hoja de manual que se leía de arriba abajo. La diferencia
/// práctica: aquí cada explicación aparece **encima del botón del que habla**,
/// así que se aprende dónde están las cosas, no solo qué hacen.
///
/// Devuelve `true` si se completó y `false` si se saltó o se cerró.
Future<bool> showGuidedTour(BuildContext context, List<TourStep> steps) async {
  if (steps.isEmpty) {
    return false;
  }

  final resultado = await Navigator.of(context, rootNavigator: true).push<bool>(
    PageRouteBuilder<bool>(
      opaque: false,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 220),
      reverseTransitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (_, _, _) => _GuidedTourOverlay(steps: steps),
      transitionsBuilder: (_, animation, _, child) => FadeTransition(opacity: animation, child: child),
    ),
  );

  return resultado ?? false;
}

class _GuidedTourOverlay extends StatefulWidget {
  const _GuidedTourOverlay({required this.steps});

  final List<TourStep> steps;

  @override
  State<_GuidedTourOverlay> createState() => _GuidedTourOverlayState();
}

class _GuidedTourOverlayState extends State<_GuidedTourOverlay> {
  int _index = 0;

  /// Mientras se prepara un paso —cambiando de pestaña, por ejemplo— no se
  /// dibuja el recorte: la posición del elemento aún no es la definitiva y el
  /// foco daría un salto feo.
  bool _preparando = false;

  TourStep get _step => widget.steps[_index];
  bool get _esUltimo => _index == widget.steps.length - 1;

  @override
  void initState() {
    super.initState();
    unawaited(_prepararPaso());
  }

  /// Ejecuta el `onEnter` del paso y espera a que la pantalla se asiente antes
  /// de medir el elemento que hay que iluminar.
  Future<void> _prepararPaso() async {
    final onEnter = _step.onEnter;
    if (onEnter == null) {
      return;
    }

    setState(() => _preparando = true);
    await onEnter();
    // Un par de fotogramas: uno para que el cambio de pestaña se aplique y otro
    // para que el nuevo contenido quede medido.
    await WidgetsBinding.instance.endOfFrame;
    await Future<void>.delayed(const Duration(milliseconds: 260));
    if (mounted) {
      setState(() => _preparando = false);
    }
  }

  Future<void> _irA(int destino) async {
    setState(() => _index = destino);
    await _prepararPaso();
  }

  /// Rectángulo del elemento que ilumina el paso actual, en coordenadas de
  /// pantalla. `null` cuando el paso no apunta a nada o el widget no está
  /// montado —por ejemplo, si la pantalla cambió mientras el tour estaba
  /// abierto—.
  Rect? get _recuadro {
    final key = _step.targetKey;
    final contexto = key?.currentContext;
    if (contexto == null) {
      return null;
    }

    final render = contexto.findRenderObject();
    if (render is! RenderBox || !render.hasSize) {
      return null;
    }

    final origen = render.localToGlobal(Offset.zero);
    return Rect.fromLTWH(origen.dx, origen.dy, render.size.width, render.size.height).inflate(_step.padding);
  }

  void _siguiente() {
    if (_preparando) {
      return;
    }
    if (_esUltimo) {
      Navigator.of(context).pop(true);
      return;
    }
    unawaited(_irA(_index + 1));
  }

  void _anterior() {
    if (_index == 0 || _preparando) {
      return;
    }
    unawaited(_irA(_index - 1));
  }

  void _saltar() => Navigator.of(context).pop(false);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pantalla = MediaQuery.sizeOf(context);
    final recuadro = _preparando ? null : _recuadro;
    final reducirAnimaciones = MediaQuery.disableAnimationsOf(context);

    return PopScope(
      // Atrás sale del tour, no navega por debajo.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _saltar();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            // Velo con el recorte sobre el elemento del paso.
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedContainer(
                  duration: Duration(milliseconds: reducirAnimaciones ? 0 : 240),
                  child: CustomPaint(
                    painter: _SpotlightPainter(
                      recuadro: recuadro,
                      radio: _step.radius,
                      velo: Colors.black.withValues(alpha: 0.72),
                      borde: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),
            ),
            // Un toque en cualquier sitio avanza, como en cualquier tour.
            Positioned.fill(
              child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: _siguiente),
            ),
            _TarjetaDelPaso(
              step: _step,
              indice: _index,
              total: widget.steps.length,
              recuadro: recuadro,
              alturaPantalla: pantalla.height,
              onSiguiente: _siguiente,
              onAnterior: _index == 0 ? null : _anterior,
              onSaltar: _saltar,
              esUltimo: _esUltimo,
            ),
          ],
        ),
      ),
    );
  }
}

/// Dibuja el velo con un hueco redondeado sobre el elemento destacado.
class _SpotlightPainter extends CustomPainter {
  _SpotlightPainter({required this.recuadro, required this.radio, required this.velo, required this.borde});

  final Rect? recuadro;
  final double radio;
  final Color velo;
  final Color borde;

  @override
  void paint(Canvas canvas, Size size) {
    final fondo = Path()..addRect(Offset.zero & size);

    if (recuadro == null) {
      canvas.drawPath(fondo, Paint()..color = velo);
      return;
    }

    final hueco = Path()..addRRect(RRect.fromRectAndRadius(recuadro!, Radius.circular(radio)));
    canvas.drawPath(Path.combine(PathOperation.difference, fondo, hueco), Paint()..color = velo);

    canvas.drawRRect(
      RRect.fromRectAndRadius(recuadro!, Radius.circular(radio)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = borde,
    );
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) {
    return oldDelegate.recuadro != recuadro || oldDelegate.radio != radio || oldDelegate.velo != velo || oldDelegate.borde != borde;
  }
}

/// Tarjeta con el texto del paso.
///
/// Se coloca debajo del elemento iluminado, y encima cuando no cabe. Si el paso
/// no ilumina nada, se centra.
class _TarjetaDelPaso extends StatelessWidget {
  const _TarjetaDelPaso({
    required this.step,
    required this.indice,
    required this.total,
    required this.recuadro,
    required this.alturaPantalla,
    required this.onSiguiente,
    required this.onAnterior,
    required this.onSaltar,
    required this.esUltimo,
  });

  final TourStep step;
  final int indice;
  final int total;
  final Rect? recuadro;
  final double alturaPantalla;
  final VoidCallback onSiguiente;
  final VoidCallback? onAnterior;
  final VoidCallback onSaltar;
  final bool esUltimo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final seguro = MediaQuery.paddingOf(context);
    // Con ilustración la tarjeta crece bastante; si no se tiene en cuenta,
    // acaba solapando el elemento que está explicando.
    final alturaEstimada = step.illustration == null ? 260.0 : 460.0;

    Widget tarjeta = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(26),
        elevation: 10,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Algunos idiomas alargan bastante las explicaciones, y con
              // ilustración la tarjeta no cabe en una pantalla pequeña. El
              // texto se desplaza y los botones se quedan siempre visibles:
              // un tour del que no se puede salir porque «Siguiente» quedó
              // fuera de la pantalla es peor que no tener tour.
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: Icon(step.icon, color: theme.colorScheme.primary, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(step.title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(step.body, style: theme.textTheme.bodyMedium?.copyWith(height: 1.4)),
                      if (step.illustration != null) ...[const SizedBox(height: 14), step.illustration!],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  // Puntos de progreso: cuántos pasos quedan, de un vistazo.
                  Semantics(
                    label: tr(
                      context,
                      es: 'Paso ${indice + 1} de $total',
                      en: 'Step ${indice + 1} of $total',
                      gl: 'Paso ${indice + 1} de $total',
                      ca: 'Pas ${indice + 1} de $total',
                      eu: '${indice + 1}. urratsa $total(e)tik',
                      fr: 'Étape ${indice + 1} sur $total',
                      it: 'Passo ${indice + 1} di $total',
                      pt: 'Passo ${indice + 1} de $total',
                      de: 'Schritt ${indice + 1} von $total',
                      el: 'Βήμα ${indice + 1} από $total',
                      ru: 'Шаг ${indice + 1} из $total',
                      ar: 'الخطوة ${indice + 1} من $total',
                      zh: '第 ${indice + 1} 步，共 $total 步',
                      ja: 'ステップ ${indice + 1} / $total',
                    ),
                    child: Row(
                      children: [
                        for (var i = 0; i < total; i++)
                          Container(
                            width: i == indice ? 18 : 6,
                            height: 6,
                            margin: const EdgeInsets.only(right: 5),
                            decoration: BoxDecoration(
                              color: i == indice ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  if (onAnterior != null)
                    TextButton(
                      onPressed: onAnterior,
                      child: Text(
                        tr(
                          context,
                          es: 'Atrás',
                          en: 'Back',
                          gl: 'Atrás',
                          ca: 'Enrere',
                          eu: 'Atzera',
                          fr: 'Retour',
                          it: 'Indietro',
                          pt: 'Voltar',
                          de: 'Zurück',
                          el: 'Πίσω',
                          ru: 'Назад',
                          ar: 'رجوع',
                          zh: '上一步',
                          ja: '戻る',
                        ),
                      ),
                    ),
                  FilledButton(
                    onPressed: onSiguiente,
                    child: Text(
                      esUltimo
                          ? tr(
                              context,
                              es: 'Listo',
                              en: 'Done',
                              gl: 'Listo',
                              ca: 'Fet',
                              eu: 'Egina',
                              fr: 'Terminé',
                              it: 'Fatto',
                              pt: 'Pronto',
                              de: 'Fertig',
                              el: 'Έτοιμο',
                              ru: 'Готово',
                              ar: 'تم',
                              zh: '完成',
                              ja: '完了',
                            )
                          : tr(
                              context,
                              es: 'Siguiente',
                              en: 'Next',
                              gl: 'Seguinte',
                              ca: 'Següent',
                              eu: 'Hurrengoa',
                              fr: 'Suivant',
                              it: 'Avanti',
                              pt: 'Seguinte',
                              de: 'Weiter',
                              el: 'Επόμενο',
                              ru: 'Далее',
                              ar: 'التالي',
                              zh: '下一步',
                              ja: '次へ',
                            ),
                    ),
                  ),
                ],
              ),
              if (!esUltimo)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton(
                    onPressed: onSaltar,
                    child: Text(
                      tr(
                        context,
                        es: 'Saltar el tour',
                        en: 'Skip the tour',
                        gl: 'Saltar o tour',
                        ca: 'Salta el tour',
                        eu: 'Saltatu bisita',
                        fr: 'Passer la visite',
                        it: 'Salta il tour',
                        pt: 'Saltar a visita',
                        de: 'Tour überspringen',
                        el: 'Παράλειψη της ξενάγησης',
                        ru: 'Пропустить тур',
                        ar: 'تخطي الجولة',
                        zh: '跳过导览',
                        ja: 'ツアーをスキップ',
                      ),
                      style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    // `Positioned` con un solo borde fijado deja que el hijo crezca cuanto
    // quiera, así que sin este tope la tarjeta se sale de la pantalla por abajo
    // y los botones dejan de ser alcanzables. Con el tope, el cuerpo se
    // desplaza dentro de la tarjeta.
    Widget conTope(double disponible) {
      return ConstrainedBox(
        constraints: BoxConstraints(maxHeight: math.max(200, disponible)),
        child: tarjeta,
      );
    }

    final centrada = alturaPantalla - seguro.top - seguro.bottom - 48;

    if (recuadro == null) {
      return Center(child: conTope(centrada));
    }

    // Debajo del elemento si cabe; si no, encima.
    final espacioDebajo = alturaPantalla - recuadro!.bottom - seguro.bottom;
    if (espacioDebajo >= alturaEstimada) {
      return Positioned(left: 0, right: 0, top: recuadro!.bottom + 16, child: conTope(espacioDebajo - 32));
    }

    final espacioEncima = recuadro!.top - seguro.top;
    if (espacioEncima >= alturaEstimada) {
      return Positioned(left: 0, right: 0, bottom: alturaPantalla - recuadro!.top + 16, child: conTope(espacioEncima - 32));
    }

    return Center(child: conTope(centrada));
  }
}
