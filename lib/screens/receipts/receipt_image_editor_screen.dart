import 'dart:io';

import 'package:extended_image/extended_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../../app/app_text.dart';

enum ReceiptImageFilter { none, grayscale, document, warm }

class ReceiptImageEditorScreen extends StatefulWidget {
  const ReceiptImageEditorScreen({super.key, required this.imagePath});

  final String imagePath;

  @override
  State<ReceiptImageEditorScreen> createState() => _ReceiptImageEditorScreenState();
}

class _ReceiptImageEditorScreenState extends State<ReceiptImageEditorScreen> {
  late String _workingPath;
  Uint8List? _previewBytes;
  ReceiptImageFilter _selectedFilter = ReceiptImageFilter.none;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _workingPath = widget.imagePath;
    _refreshPreview();
  }

  Future<void> _refreshPreview() async {
    try {
      final bytes = await _buildPreviewBytes();
      if (!mounted) {
        return;
      }
      setState(() {
        _previewBytes = bytes;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showEditorError(
        tr(
          context,
          es: 'No se pudo preparar la vista previa del ticket.',
          en: 'The receipt preview could not be prepared.',
          gl: 'Non se puido preparar a vista previa do ticket.',
          fr: 'Impossible de preparer l apercu du ticket.',
          it: 'Impossibile preparare l anteprima dello scontrino.',
          pt: 'Nao foi possivel preparar a pre-visualizacao da fatura.',
        ),
      );
    }
  }

  Future<Uint8List> _buildPreviewBytes() async {
    return File(_workingPath).readAsBytes();
  }

  Future<void> _rotateImage(bool clockwise) async {
    await _runBusyTask(() async {
      final rawBytes = await File(_workingPath).readAsBytes();
      final rotatedBytes = await compute(_rotateReceiptBytes, {'bytes': rawBytes, 'clockwise': clockwise});
      _workingPath = await _writeTempImage(rotatedBytes);
      await _refreshPreview();
    });
  }

  Future<void> _cropImage() async {
    if (_isBusy) {
      return;
    }

    try {
      if (!mounted) {
        return;
      }

      final croppedPath = await Navigator.of(
        context,
      ).push<String>(MaterialPageRoute(builder: (_) => _ReceiptCropScreen(imagePath: _workingPath)));

      if (croppedPath == null || !mounted) {
        return;
      }

      setState(() {
        _workingPath = croppedPath;
        _previewBytes = null;
      });
      await _refreshPreview();
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showEditorError(
        tr(
          context,
          es: 'No se pudo recortar la foto del ticket.',
          en: 'The receipt photo could not be cropped.',
          gl: 'Non se puido recortar a foto do ticket.',
          fr: 'Impossible de recadrer la photo du ticket.',
          it: 'Impossibile ritagliare la foto dello scontrino.',
          pt: 'Nao foi possivel recortar a foto da fatura.',
        ),
      );
    }
  }

  Future<void> _confirmImage() async {
    await _runBusyTask(() async {
      final rawBytes = await File(_workingPath).readAsBytes();
      final outputBytes = await compute(_buildReceiptExportBytes, {'bytes': rawBytes, 'filterIndex': _selectedFilter.index});
      final outputPath = _selectedFilter == ReceiptImageFilter.none ? _workingPath : await _writeTempImage(outputBytes);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(outputPath);
    });
  }

  Future<void> _runBusyTask(Future<void> Function() action) async {
    if (_isBusy) {
      return;
    }

    setState(() {
      _isBusy = true;
    });
    try {
      await action();
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  Future<String> _writeTempImage(Uint8List bytes) async {
    final file = File('${Directory.systemTemp.path}${Platform.pathSeparator}shardpay_receipt_${DateTime.now().microsecondsSinceEpoch}.jpg');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  void _showEditorError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildPreviewImage() {
    if (_previewBytes == null) {
      return const Center(child: CircularProgressIndicator());
    }

    Widget image = Image.memory(_previewBytes!, fit: BoxFit.contain);
    final matrix = _previewMatrixFor(_selectedFilter);
    if (matrix != null) {
      image = ColorFiltered(colorFilter: ColorFilter.matrix(matrix), child: image);
    }

    return InteractiveViewer(minScale: 0.8, maxScale: 5, child: image);
  }

  @override
  Widget build(BuildContext context) {
    final filterOptions = [
      (
        ReceiptImageFilter.none,
        tr(context, es: 'Original', en: 'Original', gl: 'Orixinal', fr: 'Original', it: 'Originale', pt: 'Original'),
      ),
      (ReceiptImageFilter.grayscale, tr(context, es: 'Gris', en: 'Gray', gl: 'Gris', fr: 'Gris', it: 'Grigio', pt: 'Cinzento')),
      (
        ReceiptImageFilter.document,
        tr(context, es: 'Documento', en: 'Document', gl: 'Documento', fr: 'Document', it: 'Documento', pt: 'Documento'),
      ),
      (ReceiptImageFilter.warm, tr(context, es: 'Cálido', en: 'Warm', gl: 'Calido', fr: 'Chaud', it: 'Caldo', pt: 'Quente')),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          tr(
            context,
            es: 'Preparar ticket',
            en: 'Prepare receipt',
            gl: 'Preparar ticket',
            fr: 'Preparer ticket',
            it: 'Prepara scontrino',
            pt: 'Preparar fatura',
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isBusy ? null : _confirmImage,
            child: Text(
              tr(context, es: 'Usar foto', en: 'Use photo', gl: 'Usar foto', fr: 'Utiliser photo', it: 'Usa foto', pt: 'Usar foto'),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: ClipRRect(borderRadius: BorderRadius.circular(24), child: _buildPreviewImage()),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: _isBusy ? null : _cropImage,
                      icon: const Icon(Icons.crop_rounded),
                      label: Text(tr(context, es: 'Recortar', en: 'Crop', gl: 'Recortar', fr: 'Recadrer', it: 'Ritaglia', pt: 'Recortar')),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: _isBusy ? null : () => _rotateImage(false),
                      icon: const Icon(Icons.rotate_90_degrees_ccw_rounded),
                      label: Text(
                        tr(
                          context,
                          es: 'Girar izq.',
                          en: 'Rotate left',
                          gl: 'Xirar esq.',
                          fr: 'Tourner g.',
                          it: 'Ruota sx',
                          pt: 'Rodar esq.',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: _isBusy ? null : () => _rotateImage(true),
                      icon: const Icon(Icons.rotate_90_degrees_cw_rounded),
                      label: Text(
                        tr(
                          context,
                          es: 'Girar der.',
                          en: 'Rotate right',
                          gl: 'Xirar der.',
                          fr: 'Tourner d.',
                          it: 'Ruota dx',
                          pt: 'Rodar dir.',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 54,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemBuilder: (context, index) {
                  final (filter, label) = filterOptions[index];
                  return ChoiceChip(
                    label: Text(label),
                    selected: filter == _selectedFilter,
                    onSelected: _isBusy ? null : (_) => setState(() => _selectedFilter = filter),
                  );
                },
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemCount: filterOptions.length,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
              child: Text(
                tr(
                  context,
                  es: 'Ajusta el encuadre y mejora el contraste antes de analizar el ticket.',
                  en: 'Adjust framing and improve contrast before analyzing the receipt.',
                  gl: 'Axusta o encadre e mellora o contraste antes de analizar o ticket.',
                  fr: 'Ajustez le cadrage et le contraste avant d analyser le ticket.',
                  it: 'Regola l inquadratura e il contrasto prima di analizzare lo scontrino.',
                  pt: 'Ajusta o enquadramento e melhora o contraste antes de analisar a fatura.',
                ),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Uint8List _buildReceiptExportBytes(Map<String, Object> payload) {
  final bytes = payload['bytes']! as Uint8List;
  final filter = ReceiptImageFilter.values[payload['filterIndex']! as int];
  return _processReceiptBytes(bytes, filter, maxDimension: 2400);
}

Uint8List _cropReceiptBytesFromRect(Map<String, Object> payload) {
  final bytes = payload['bytes']! as Uint8List;
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    return bytes;
  }

  final left = (payload['left']! as double).round().clamp(0, decoded.width - 1);
  final top = (payload['top']! as double).round().clamp(0, decoded.height - 1);
  final width = (payload['width']! as double).round().clamp(1, decoded.width - left);
  final height = (payload['height']! as double).round().clamp(1, decoded.height - top);
  final cropped = img.copyCrop(decoded, x: left, y: top, width: width, height: height);
  return Uint8List.fromList(img.encodeJpg(cropped, quality: 96));
}

Uint8List _rotateReceiptBytes(Map<String, Object> payload) {
  final bytes = payload['bytes']! as Uint8List;
  final clockwise = payload['clockwise']! as bool;
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    return bytes;
  }

  final rotated = img.copyRotate(decoded, angle: clockwise ? 90 : -90);
  return Uint8List.fromList(img.encodeJpg(rotated, quality: 94));
}

Uint8List _processReceiptBytes(Uint8List bytes, ReceiptImageFilter filter, {required int maxDimension}) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    return bytes;
  }

  var working = img.Image.from(decoded);
  final largestSide = working.width > working.height ? working.width : working.height;
  if (largestSide > maxDimension) {
    if (working.width >= working.height) {
      working = img.copyResize(working, width: maxDimension);
    } else {
      working = img.copyResize(working, height: maxDimension);
    }
  }

  switch (filter) {
    case ReceiptImageFilter.none:
      break;
    case ReceiptImageFilter.grayscale:
      working = img.grayscale(working);
      break;
    case ReceiptImageFilter.document:
      working = img.grayscale(working);
      working = img.adjustColor(working, contrast: 2.2, brightness: 0.08, gamma: 0.92);
      working = img.gaussianBlur(working, radius: 1);
      for (final pixel in working) {
        final luminance = img.getLuminance(pixel);
        final binary = luminance >= 170 ? 255 : 0;
        pixel
          ..r = binary
          ..g = binary
          ..b = binary;
      }
      break;
    case ReceiptImageFilter.warm:
      working = img.adjustColor(working, saturation: 1.08, contrast: 1.12, brightness: 0.02);
      for (final pixel in working) {
        pixel
          ..r = (pixel.r * 1.06).clamp(0, 255).toInt()
          ..g = (pixel.g * 1.01).clamp(0, 255).toInt()
          ..b = (pixel.b * 0.95).clamp(0, 255).toInt();
      }
      break;
  }

  return Uint8List.fromList(img.encodeJpg(working, quality: 94));
}

List<double>? _previewMatrixFor(ReceiptImageFilter filter) {
  switch (filter) {
    case ReceiptImageFilter.none:
      return null;
    case ReceiptImageFilter.grayscale:
      return const [0.2126, 0.7152, 0.0722, 0, 0, 0.2126, 0.7152, 0.0722, 0, 0, 0.2126, 0.7152, 0.0722, 0, 0, 0, 0, 0, 1, 0];
    case ReceiptImageFilter.document:
      return const [1.5, 1.5, 1.5, 0, -180, 1.5, 1.5, 1.5, 0, -180, 1.5, 1.5, 1.5, 0, -180, 0, 0, 0, 1, 0];
    case ReceiptImageFilter.warm:
      return const [1.08, 0, 0, 0, 12, 0, 1.01, 0, 0, 4, 0, 0, 0.92, 0, -6, 0, 0, 0, 1, 0];
  }
}

class _ReceiptCropScreen extends StatefulWidget {
  const _ReceiptCropScreen({required this.imagePath});

  final String imagePath;

  @override
  State<_ReceiptCropScreen> createState() => _ReceiptCropScreenState();
}

class _ReceiptCropScreenState extends State<_ReceiptCropScreen> {
  final ImageEditorController _editorController = ImageEditorController();
  bool _isSaving = false;

  Future<void> _applyCrop() async {
    if (_isSaving) {
      return;
    }

    final cropRect = _editorController.getCropRect();
    final state = _editorController.state;
    if (cropRect == null || state == null) {
      return;
    }

    setState(() => _isSaving = true);
    try {
      final croppedBytes = await compute(_cropReceiptBytesFromRect, {
        'bytes': state.rawImageData,
        'left': cropRect.left,
        'top': cropRect.top,
        'width': cropRect.width,
        'height': cropRect.height,
      });
      final file = File(
        '${Directory.systemTemp.path}${Platform.pathSeparator}shardpay_receipt_crop_${DateTime.now().microsecondsSinceEpoch}.jpg',
      );
      await file.writeAsBytes(croppedBytes, flush: true);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(file.path);
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              tr(
                context,
                es: 'No se pudo recortar la foto del ticket.',
                en: 'The receipt photo could not be cropped.',
                gl: 'Non se puido recortar a foto do ticket.',
                fr: 'Impossible de recadrer la photo du ticket.',
                it: 'Impossibile ritagliare la foto dello scontrino.',
                pt: 'Nao foi possivel recortar a foto da fatura.',
              ),
            ),
          ),
        );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          tr(
            context,
            es: 'Recortar ticket',
            en: 'Crop receipt',
            gl: 'Recortar ticket',
            fr: 'Recadrer ticket',
            it: 'Ritaglia scontrino',
            pt: 'Recortar fatura',
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _applyCrop,
            child: Text(tr(context, es: 'Aplicar', en: 'Apply', gl: 'Aplicar', fr: 'Appliquer', it: 'Applica', pt: 'Aplicar')),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ExtendedImage.file(
              File(widget.imagePath),
              fit: BoxFit.contain,
              mode: ExtendedImageMode.editor,
              cacheRawData: true,
              initEditorConfigHandler: (_) => EditorConfig(
                maxScale: 8,
                cropRectPadding: const EdgeInsets.all(20),
                hitTestSize: 24,
                lineColor: Colors.white,
                cornerColor: colorScheme.primary,
                editorMaskColorHandler: (context, pointerDown) => Colors.black.withValues(alpha: 0.42),
                initCropRectType: InitCropRectType.imageRect,
                controller: _editorController,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Text(
              tr(
                context,
                es: 'Mueve las esquinas y haz zoom sobre la imagen para ajustar el recorte.',
                en: 'Drag the corners and zoom the image to adjust the crop.',
                gl: 'Move as esquinas e fai zoom sobre a imaxe para axustar o recorte.',
                fr: 'Deplacez les coins et zoomez sur l image pour ajuster le recadrage.',
                it: 'Sposta gli angoli e fai zoom sull immagine per regolare il ritaglio.',
                pt: 'Move os cantos e faz zoom na imagem para ajustar o recorte.',
              ),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
