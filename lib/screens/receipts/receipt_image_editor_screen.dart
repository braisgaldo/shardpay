import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_cropper/image_cropper.dart';

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
  int _previewRequestId = 0;

  @override
  void initState() {
    super.initState();
    _workingPath = widget.imagePath;
    _refreshPreview();
  }

  Future<void> _refreshPreview() async {
    final requestId = ++_previewRequestId;
    try {
      final bytes = await _buildPreviewBytes();
      if (!mounted || requestId != _previewRequestId) {
        return;
      }
      setState(() {
        _previewBytes = bytes;
      });
    } catch (_) {
      if (!mounted || requestId != _previewRequestId) {
        return;
      }
      _showEditorError(
        tr(context, es: 'No se pudo preparar la vista previa del ticket.', en: 'The receipt preview could not be prepared.', gl: 'Non se puido preparar a vista previa do ticket.', fr: 'Impossible de preparer l apercu du ticket.', it: 'Impossibile preparare l anteprima dello scontrino.', pt: 'Nao foi possivel preparar a pre-visualizacao da fatura.'),
      );
    }
  }

  Future<Uint8List> _buildPreviewBytes() async {
    final rawBytes = await File(_workingPath).readAsBytes();
    return compute(_buildReceiptPreviewBytes, {
      'bytes': rawBytes,
      'filterIndex': _selectedFilter.index,
    });
  }

  Future<void> _rotateImage(bool clockwise) async {
    await _runBusyTask(() async {
      final rawBytes = await File(_workingPath).readAsBytes();
      final rotatedBytes = await compute(_rotateReceiptBytes, {
        'bytes': rawBytes,
        'clockwise': clockwise,
      });
      _workingPath = await _writeTempImage(rotatedBytes);
      await _refreshPreview();
    });
  }

  Future<void> _cropImage() async {
    if (_isBusy) {
      return;
    }

    try {
      final cropped = await ImageCropper().cropImage(
        sourcePath: _workingPath,
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 96,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: tr(context, es: 'Recortar ticket', en: 'Crop receipt', gl: 'Recortar ticket', fr: 'Recadrer ticket', it: 'Ritaglia scontrino', pt: 'Recortar fatura'),
            toolbarColor: Theme.of(context).colorScheme.surface,
            toolbarWidgetColor: Theme.of(context).colorScheme.onSurface,
            activeControlsWidgetColor: Theme.of(context).colorScheme.primary,
            backgroundColor: Theme.of(context).colorScheme.surface,
            hideBottomControls: false,
            lockAspectRatio: false,
          ),
          IOSUiSettings(
            title: tr(context, es: 'Recortar ticket', en: 'Crop receipt', gl: 'Recortar ticket', fr: 'Recadrer ticket', it: 'Ritaglia scontrino', pt: 'Recortar fatura'),
            doneButtonTitle: tr(context, es: 'Listo', en: 'Done', gl: 'Listo', fr: 'Pret', it: 'Fine', pt: 'Concluir'),
            cancelButtonTitle: tr(context, es: 'Cancelar', en: 'Cancel', gl: 'Cancelar', fr: 'Annuler', it: 'Annulla', pt: 'Cancelar'),
          ),
        ],
      );

      if (cropped == null || !mounted) {
        return;
      }

      setState(() {
        _workingPath = cropped.path;
        _previewBytes = null;
      });
      await _refreshPreview();
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showEditorError(
        tr(context, es: 'No se pudo recortar la foto del ticket.', en: 'The receipt photo could not be cropped.', gl: 'Non se puido recortar a foto do ticket.', fr: 'Impossible de recadrer la photo du ticket.', it: 'Impossibile ritagliare la foto dello scontrino.', pt: 'Nao foi possivel recortar a foto da fatura.'),
      );
    }
  }

  Future<void> _confirmImage() async {
    await _runBusyTask(() async {
      final rawBytes = await File(_workingPath).readAsBytes();
      final outputBytes = await compute(_buildReceiptExportBytes, {
        'bytes': rawBytes,
        'filterIndex': _selectedFilter.index,
      });
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

  @override
  Widget build(BuildContext context) {
    final filterOptions = [
      (ReceiptImageFilter.none, tr(context, es: 'Original', en: 'Original', gl: 'Orixinal', fr: 'Original', it: 'Originale', pt: 'Original')),
      (ReceiptImageFilter.grayscale, tr(context, es: 'Gris', en: 'Gray', gl: 'Gris', fr: 'Gris', it: 'Grigio', pt: 'Cinzento')),
      (ReceiptImageFilter.document, tr(context, es: 'Documento', en: 'Document', gl: 'Documento', fr: 'Document', it: 'Documento', pt: 'Documento')),
      (ReceiptImageFilter.warm, tr(context, es: 'Cálido', en: 'Warm', gl: 'Calido', fr: 'Chaud', it: 'Caldo', pt: 'Quente')),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(tr(context, es: 'Preparar ticket', en: 'Prepare receipt', gl: 'Preparar ticket', fr: 'Preparer ticket', it: 'Prepara scontrino', pt: 'Preparar fatura')),
        actions: [
          TextButton(
            onPressed: _isBusy ? null : _confirmImage,
            child: Text(tr(context, es: 'Usar foto', en: 'Use photo', gl: 'Usar foto', fr: 'Utiliser photo', it: 'Usa foto', pt: 'Usar foto')),
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
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: _previewBytes == null
                        ? const Center(child: CircularProgressIndicator())
                        : InteractiveViewer(
                            minScale: 0.8,
                            maxScale: 5,
                            child: Image.memory(_previewBytes!, fit: BoxFit.contain),
                          ),
                  ),
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
                      label: Text(tr(context, es: 'Girar izq.', en: 'Rotate left', gl: 'Xirar esq.', fr: 'Tourner g.', it: 'Ruota sx', pt: 'Rodar esq.')),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: _isBusy ? null : () => _rotateImage(true),
                      icon: const Icon(Icons.rotate_90_degrees_cw_rounded),
                      label: Text(tr(context, es: 'Girar der.', en: 'Rotate right', gl: 'Xirar der.', fr: 'Tourner d.', it: 'Ruota dx', pt: 'Rodar dir.')),
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
                    onSelected: _isBusy
                        ? null
                        : (_) async {
                            setState(() {
                              _selectedFilter = filter;
                              _previewBytes = null;
                            });
                            await _refreshPreview();
                          },
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

Uint8List _buildReceiptPreviewBytes(Map<String, Object> payload) {
  final bytes = payload['bytes']! as Uint8List;
  final filter = ReceiptImageFilter.values[payload['filterIndex']! as int];
  return _processReceiptBytes(bytes, filter, maxDimension: 1600);
}

Uint8List _buildReceiptExportBytes(Map<String, Object> payload) {
  final bytes = payload['bytes']! as Uint8List;
  final filter = ReceiptImageFilter.values[payload['filterIndex']! as int];
  return _processReceiptBytes(bytes, filter, maxDimension: 2400);
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