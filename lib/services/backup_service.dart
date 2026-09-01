import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../core/backup_format.dart';
import '../models/app_models.dart';
import '../repositories/app_repository.dart';

/// Qué se hace con una copia al importarla.
enum BackupImportMode {
  /// Restaura solo los ajustes: tema, idioma, notificaciones y el estado del
  /// aviso de donación.
  preferencesOnly,

  /// Restaura los ajustes y vuelve a crear los grupos de la copia que ya no
  /// existen para este usuario.
  ///
  /// Los grupos que **sí** siguen existiendo se dejan intactos a propósito: sus
  /// datos vivos pueden incluir gastos añadidos por otras personas desde que se
  /// hizo la copia, y machacarlos borraría trabajo ajeno.
  restoreMissingGroups,
}

/// Resultado de exportar.
class BackupExportResult {
  const BackupExportResult({required this.filePath, required this.fileName, required this.byteSize, required this.groupCount});

  final String filePath;
  final String fileName;
  final int byteSize;
  final int groupCount;
}

/// Resultado de importar.
class BackupImportResult {
  const BackupImportResult({
    required this.document,
    required this.restoredGroups,
    required this.skippedGroups,
    required this.safetyCopyPath,
  });

  final BackupDocument document;
  final int restoredGroups;
  final int skippedGroups;

  /// Copia automática del estado anterior, hecha antes de tocar nada.
  final String? safetyCopyPath;
}

/// Exportación e importación del fichero `.shardpay.bak`.
///
/// El formato y su validación viven en `lib/core/backup_format.dart`, que es
/// Dart puro y tiene pruebas. Aquí solo está lo que necesita el dispositivo:
/// gzip, ficheros y el repositorio.
class BackupService {
  const BackupService({required this.repository});

  final AppRepository repository;

  /// Escribe una copia y devuelve la ruta del fichero.
  Future<BackupExportResult> export({
    required List<ExpenseGroup> groups,
    required Map<String, Object?> preferences,
    required String appVersion,
    String? deviceLabel,
  }) async {
    final document = BackupDocument.create(
      appVersion: appVersion,
      deviceLabel: deviceLabel,
      payload: BackupPayload(preferences: preferences, groups: groups),
    );

    final bytes = gzip.encode(utf8.encode(document.encode()));
    final directory = await getTemporaryDirectory();
    final fileName = _fileNameFor(document.createdAt);
    final file = File('${directory.path}${Platform.pathSeparator}$fileName');
    await file.writeAsBytes(bytes, flush: true);

    return BackupExportResult(filePath: file.path, fileName: fileName, byteSize: bytes.length, groupCount: groups.length);
  }

  /// Lee y valida una copia sin aplicar nada.
  ///
  /// Se llama antes de preguntar al usuario, para poder avisar de un fichero
  /// inválido *antes* de tocar sus datos.
  Future<BackupDocument> read(String path) async {
    final raw = await File(path).readAsBytes();
    final String source;

    // Se aceptan las dos formas: comprimida (lo normal) y JSON en claro, que
    // es lo que sale si alguien descomprime el fichero para mirarlo.
    if (_looksGzipped(raw)) {
      source = utf8.decode(gzip.decode(raw));
    } else {
      source = utf8.decode(raw);
    }

    return BackupDocument.decode(source);
  }

  /// Aplica una copia ya validada.
  ///
  /// Antes de tocar nada guarda una copia automática del estado actual: si la
  /// restauración deja algo peor de lo que estaba, hay a dónde volver.
  Future<BackupImportResult> import({
    required BackupDocument document,
    required BackupImportMode mode,
    required AppUser user,
    required List<ExpenseGroup> currentGroups,
    required Map<String, Object?> currentPreferences,
    required String appVersion,
    required Future<void> Function(Map<String, Object?> preferences) applyPreferences,
  }) async {
    String? safetyCopyPath;
    try {
      final safety = await export(
        groups: currentGroups,
        preferences: currentPreferences,
        appVersion: appVersion,
        deviceLabel: 'copia automática previa a importar',
      );
      safetyCopyPath = safety.filePath;
    } catch (error) {
      debugPrint('[Backup] No se pudo crear la copia de seguridad previa: $error');
    }

    await applyPreferences(document.payload.preferences);

    if (mode == BackupImportMode.preferencesOnly) {
      return BackupImportResult(
        document: document,
        restoredGroups: 0,
        skippedGroups: document.payload.groups.length,
        safetyCopyPath: safetyCopyPath,
      );
    }

    // Se comparan por nombre y fecha de creación y no por identificador: al
    // restaurar, el grupo recibe un identificador nuevo, así que el original ya
    // no vuelve a coincidir nunca y una segunda importación duplicaría todo.
    final existing = currentGroups.map(_groupFingerprint).toSet();

    var restored = 0;
    var skipped = 0;

    for (final group in document.payload.groups) {
      if (existing.contains(_groupFingerprint(group))) {
        skipped++;
        continue;
      }
      await repository.restoreGroup(owner: user, group: group);
      restored++;
    }

    return BackupImportResult(document: document, restoredGroups: restored, skippedGroups: skipped, safetyCopyPath: safetyCopyPath);
  }

  String _groupFingerprint(ExpenseGroup group) {
    return '${group.name.trim().toLowerCase()}|${group.createdAt.toUtc().toIso8601String()}';
  }

  String _fileNameFor(DateTime createdAt) {
    final stamp = createdAt.toUtc().toIso8601String().substring(0, 16).replaceAll(':', '').replaceAll('-', '').replaceAll('T', '-');
    return 'shardpay-$stamp.$backupFileExtension';
  }

  bool _looksGzipped(List<int> bytes) {
    return bytes.length >= 2 && bytes[0] == 0x1f && bytes[1] == 0x8b;
  }
}
