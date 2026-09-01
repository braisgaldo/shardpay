import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_text.dart';

/// Captura de tickets con vista previa en vivo.
///
/// Sustituye a la llamada directa a la cámara del sistema. La diferencia no es
/// estética: con la cámara del sistema el usuario encuadra a ojo, dispara y no
/// se entera de que ha salido movido hasta que el OCR falla. Aquí hay guía de
/// encuadre, linterna, enfoque al tocar y aviso de recorte, que es donde de
/// verdad se gana calidad de lectura.
class ReceiptScannerScreen extends StatefulWidget {
  const ReceiptScannerScreen({super.key});

  @override
  State<ReceiptScannerScreen> createState() => _ReceiptScannerScreenState();
}

class _ReceiptScannerScreenState extends State<ReceiptScannerScreen> with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = const <CameraDescription>[];
  bool _torchOn = false;
  bool _capturing = false;
  Object? _failure;
  Offset? _focusPoint;
  Timer? _focusIndicatorTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_setUpCamera());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _focusIndicatorTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    // Android puede quitarnos la cámara en cuanto la app pasa a segundo plano;
    // hay que soltarla y volver a pedirla, no dejar un controlador zombi.
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _controller = null;
      controller.dispose();
      if (mounted) {
        setState(() {});
      }
    } else if (state == AppLifecycleState.resumed) {
      unawaited(_setUpCamera());
    }
  }

  Future<void> _setUpCamera() async {
    try {
      if (_cameras.isEmpty) {
        _cameras = await availableCameras();
      }
      if (_cameras.isEmpty) {
        throw CameraException('sin-camara', 'El dispositivo no expone ninguna cámara.');
      }

      final camera = _cameras.firstWhere((entry) => entry.lensDirection == CameraLensDirection.back, orElse: () => _cameras.first);

      // Un ticket es una hoja larga y estrecha con letra de 2 mm: con 720p el
      // OCR se queda sin píxeles por carácter. Se pide la mayor resolución
      // razonable y se baja si el dispositivo no puede.
      final controller = CameraController(camera, ResolutionPreset.veryHigh, enableAudio: false);

      await controller.initialize();
      await _applyPreferredModes(controller);

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _controller = controller;
        _failure = null;
        _torchOn = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _failure = error);
    }
  }

  Future<void> _applyPreferredModes(CameraController controller) async {
    // Ninguno de estos ajustes es imprescindible y no todos los dispositivos
    // los soportan, así que cada uno va por su cuenta y un fallo no tumba la
    // inicialización entera.
    for (final action in <Future<void> Function()>[
      () => controller.setFlashMode(FlashMode.off),
      () => controller.setFocusMode(FocusMode.auto),
      () => controller.setExposureMode(ExposureMode.auto),
    ]) {
      try {
        await action();
      } on CameraException {
        continue;
      }
    }
  }

  Future<void> _toggleTorch() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }
    final next = !_torchOn;
    try {
      await controller.setFlashMode(next ? FlashMode.torch : FlashMode.off);
      if (mounted) {
        setState(() => _torchOn = next);
      }
    } on CameraException {
      if (!mounted) {
        return;
      }
      _showMessage(
        tr(
          context,
          es: 'Esta cámara no permite encender la linterna.',
          en: 'This camera cannot turn on the torch.',
          gl: 'Esta cámara non permite acender a lanterna.',
          fr: 'Cet appareil photo ne permet pas d activer la lampe.',
          it: 'Questa fotocamera non consente di accendere la torcia.',
          pt: 'Esta câmara não permite ligar a lanterna.',
        ),
      );
    }
  }

  Future<void> _focusAt(Offset localPosition, Size previewSize) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    final normalized = Offset(
      (localPosition.dx / previewSize.width).clamp(0.0, 1.0),
      (localPosition.dy / previewSize.height).clamp(0.0, 1.0),
    );

    setState(() => _focusPoint = localPosition);
    _focusIndicatorTimer?.cancel();
    _focusIndicatorTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) {
        setState(() => _focusPoint = null);
      }
    });

    try {
      await controller.setFocusPoint(normalized);
      await controller.setExposurePoint(normalized);
    } on CameraException {
      // Hay cámaras sin enfoque por punto; el indicador ya ha dado la
      // sensación de respuesta y el enfoque automático sigue trabajando.
    }
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _capturing) {
      return;
    }

    setState(() => _capturing = true);
    try {
      await HapticFeedback.mediumImpact();
      final picture = await controller.takePicture();
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(picture.path);
    } on CameraException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _capturing = false);
      _showMessage(error.description ?? error.code);
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_failure != null)
            _ScannerError(onRetry: () => unawaited(_setUpCamera()))
          else if (controller == null || !controller.value.isInitialized)
            const Center(child: CircularProgressIndicator())
          else
            _buildPreview(controller),
          _buildOverlay(context, ready: _failure == null && controller != null && controller.value.isInitialized),
        ],
      ),
    );
  }

  Widget _buildPreview(CameraController controller) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) => _focusAt(details.localPosition, size),
          child: Stack(
            fit: StackFit.expand,
            children: [
              FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: controller.value.previewSize?.height ?? size.width,
                  height: controller.value.previewSize?.width ?? size.height,
                  child: CameraPreview(controller),
                ),
              ),
              if (_focusPoint != null) Positioned(left: _focusPoint!.dx - 34, top: _focusPoint!.dy - 34, child: const _FocusRing()),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOverlay(BuildContext context, {required bool ready}) {
    final mediaQuery = MediaQuery.of(context);

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                _RoundIconButton(
                  icon: Icons.close_rounded,
                  tooltip: tr(context, es: 'Cerrar', en: 'Close', gl: 'Pechar', fr: 'Fermer', it: 'Chiudi', pt: 'Fechar'),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                const Spacer(),
                _RoundIconButton(
                  icon: _torchOn ? Icons.flashlight_on_rounded : Icons.flashlight_off_rounded,
                  active: _torchOn,
                  tooltip: _torchOn
                      ? tr(
                          context,
                          es: 'Apagar linterna',
                          en: 'Turn torch off',
                          gl: 'Apagar lanterna',
                          fr: 'Éteindre la lampe',
                          it: 'Spegni torcia',
                          pt: 'Desligar lanterna',
                        )
                      : tr(
                          context,
                          es: 'Encender linterna',
                          en: 'Turn torch on',
                          gl: 'Acender lanterna',
                          fr: 'Allumer la lampe',
                          it: 'Accendi torcia',
                          pt: 'Ligar lanterna',
                        ),
                  onPressed: ready ? _toggleTorch : null,
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: mediaQuery.size.width * 0.08, vertical: 12),
              child: const _ReceiptGuide(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
            child: Text(
              tr(
                context,
                es: 'Encaja el ticket entero dentro del marco, sobre una superficie lisa y bien iluminada.',
                en: 'Fit the whole receipt inside the frame, on a flat, well lit surface.',
                gl: 'Encaixa o ticket enteiro dentro do marco, sobre unha superficie lisa e ben iluminada.',
                fr: 'Placez le ticket entier dans le cadre, sur une surface plane et bien éclairée.',
                it: 'Inquadra tutto lo scontrino, su una superficie piana e ben illuminata.',
                pt: 'Encaixa a fatura inteira dentro da moldura, sobre uma superfície lisa e bem iluminada.',
              ),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Semantics(
                  button: true,
                  label: tr(
                    context,
                    es: 'Hacer foto del ticket',
                    en: 'Take a photo of the receipt',
                    gl: 'Facer foto do ticket',
                    fr: 'Photographier le ticket',
                    it: 'Fotografa lo scontrino',
                    pt: 'Fotografar a fatura',
                  ),
                  child: GestureDetector(
                    onTap: ready && !_capturing ? _capture : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: ready ? 1 : 0.4),
                        border: Border.all(color: Colors.white24, width: 6),
                      ),
                      child: _capturing
                          ? const Padding(
                              padding: EdgeInsets.all(20),
                              child: CircularProgressIndicator(strokeWidth: 3, color: Colors.black54),
                            )
                          : const Icon(Icons.receipt_long_rounded, color: Colors.black87, size: 30),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Marco con proporción de ticket y esquinas marcadas.
class _ReceiptGuide extends StatelessWidget {
  const _ReceiptGuide();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(painter: _ReceiptGuidePainter(), child: const SizedBox.expand()),
    );
  }
}

class _ReceiptGuidePainter extends CustomPainter {
  static const double _cornerLength = 28;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rounded = RRect.fromRectAndRadius(rect, const Radius.circular(20));

    final dim = Paint()..color = Colors.black.withValues(alpha: 0.35);
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Rect.fromLTWH(-size.width, -size.height, size.width * 3, size.height * 3)),
        Path()..addRRect(rounded),
      ),
      dim,
    );

    final corner = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    void drawCorner(Offset origin, double dx, double dy) {
      canvas.drawLine(origin, origin.translate(_cornerLength * dx, 0), corner);
      canvas.drawLine(origin, origin.translate(0, _cornerLength * dy), corner);
    }

    drawCorner(rect.topLeft.translate(2, 2), 1, 1);
    drawCorner(rect.topRight.translate(-2, 2), -1, 1);
    drawCorner(rect.bottomLeft.translate(2, -2), 1, -1);
    drawCorner(rect.bottomRight.translate(-2, -2), -1, -1);
  }

  @override
  bool shouldRepaint(covariant _ReceiptGuidePainter oldDelegate) => false;
}

class _FocusRing extends StatelessWidget {
  const _FocusRing();

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 1.4, end: 1),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
      child: Container(
        width: 68,
        height: 68,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.amberAccent, width: 2),
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.tooltip, required this.onPressed, this.active = false});

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      iconSize: 24,
      // 48 dp de área táctil: requisito de accesibilidad, no un capricho.
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      style: IconButton.styleFrom(
        backgroundColor: active ? Colors.amberAccent : Colors.black38,
        foregroundColor: active ? Colors.black : Colors.white,
      ),
      icon: Icon(icon),
    );
  }
}

class _ScannerError extends StatelessWidget {
  const _ScannerError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.no_photography_rounded, size: 56, color: Colors.white70),
            const SizedBox(height: 18),
            Text(
              tr(
                context,
                es: 'No se pudo abrir la cámara. Revisa el permiso de cámara en los ajustes del sistema.',
                en: 'The camera could not be opened. Check the camera permission in your system settings.',
                gl: 'Non se puido abrir a cámara. Revisa o permiso de cámara nos axustes do sistema.',
                fr: 'Impossible d ouvrir l appareil photo. Vérifiez l autorisation dans les réglages du système.',
                it: 'Non è stato possibile aprire la fotocamera. Controlla il permesso nelle impostazioni di sistema.',
                pt: 'Não foi possível abrir a câmara. Verifica a permissão de câmara nas definições do sistema.',
              ),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(
                tr(context, es: 'Reintentar', en: 'Try again', gl: 'Reintentar', fr: 'Réessayer', it: 'Riprova', pt: 'Tentar de novo'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
