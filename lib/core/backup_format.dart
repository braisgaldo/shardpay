/// Formato del fichero de copia de seguridad `.shardpay.bak`.
///
/// Dart puro: aquí solo vive la estructura del documento, su validación y su
/// suma de verificación. El comprimido, el disco y la interfaz quedan fuera,
/// en `lib/services/backup_service.dart`, para que todo esto se pueda probar
/// sin dispositivo.
///
/// **Formato.** Por dentro es JSON en UTF-8 comprimido con gzip. Se eligió JSON
/// y no SQLite ni un ZIP con manifiesto por tres razones: el modelo de dominio
/// ya sabe convertirse a mapas, un fichero de texto se puede inspeccionar y
/// reparar a mano si algún día hace falta, y gzip deja un ticket de mil gastos
/// en unas decenas de kilobytes.
library;

import 'dart:convert';

import '../models/app_models.dart';

/// Identificador del formato. Va dentro del fichero para poder distinguir una
/// copia de ShardPay de cualquier otro `.bak` que el usuario elija por error.
const String backupFormatId = 'es.ghatostudio.shardpay.backup';

/// Versión del esquema del fichero.
///
/// Se sube cuando cambia la forma de los datos. La lectura acepta versiones
/// anteriores y las migra; nunca acepta versiones futuras, porque no puede
/// saber qué significan.
const int backupSchemaVersion = 1;

/// Extensión propia del fichero.
const String backupFileExtension = 'shardpay.bak';

/// Tipo MIME registrado para la asociación de ficheros.
const String backupMimeType = 'application/vnd.ghatostudio.shardpay.backup';

/// Motivos por los que una copia se puede rechazar.
///
/// Es un enum y no un texto porque la app habla trece idiomas y el mensaje de
/// error tiene que estar traducido.
enum BackupError {
  /// El fichero no es JSON legible (o no era un `.shardpay.bak`).
  unreadable,

  /// Es JSON, pero no una copia de ShardPay.
  notAShardPayBackup,

  /// La copia viene de una versión más nueva de la app.
  schemaTooNew,

  /// La suma de verificación no cuadra: el fichero está dañado o manipulado.
  checksumMismatch,

  /// La copia está vacía: no hay nada que restaurar.
  empty,
}

class BackupFormatException implements Exception {
  const BackupFormatException(this.error, [this.detail]);

  final BackupError error;
  final String? detail;

  @override
  String toString() => 'BackupFormatException(${error.name}${detail == null ? '' : ': $detail'})';
}

/// Contenido restaurable de una copia.
class BackupPayload {
  const BackupPayload({required this.preferences, required this.groups});

  /// Ajustes de la app: tema, idioma, notificaciones y el estado del aviso de
  /// donación (que viaja aquí a propósito, para que reinstalar no vuelva a
  /// mostrarlo).
  final Map<String, Object?> preferences;

  final List<ExpenseGroup> groups;

  bool get isEmpty => groups.isEmpty && preferences.isEmpty;

  Map<String, Object?> toJson() => <String, Object?>{
    'preferences': preferences,
    'groups': groups.map((group) => group.toMap()).toList(growable: false),
  };

  factory BackupPayload.fromJson(Map<String, Object?> json) {
    final rawGroups = json['groups'];
    final rawPreferences = json['preferences'];

    return BackupPayload(
      preferences: rawPreferences is Map ? Map<String, Object?>.from(rawPreferences) : const <String, Object?>{},
      groups: rawGroups is List
          ? rawGroups
                .whereType<Map<Object?, Object?>>()
                .map((entry) => ExpenseGroup.fromMap(Map<String, dynamic>.from(entry)))
                .toList(growable: false)
          : const <ExpenseGroup>[],
    );
  }
}

/// Un fichero de copia completo: cabecera más contenido.
class BackupDocument {
  const BackupDocument({
    required this.schemaVersion,
    required this.appVersion,
    required this.createdAt,
    required this.payload,
    this.deviceLabel,
  });

  final int schemaVersion;

  /// Versión de la app que generó la copia (SemVer).
  final String appVersion;

  final DateTime createdAt;

  /// Etiqueta libre para que el usuario reconozca de dónde salió la copia.
  final String? deviceLabel;

  final BackupPayload payload;

  /// Crea una copia con la cabecera al día.
  factory BackupDocument.create({required String appVersion, required BackupPayload payload, String? deviceLabel, DateTime? createdAt}) {
    return BackupDocument(
      schemaVersion: backupSchemaVersion,
      appVersion: appVersion,
      createdAt: createdAt ?? DateTime.now().toUtc(),
      deviceLabel: deviceLabel,
      payload: payload,
    );
  }

  /// Serializa el documento a JSON.
  ///
  /// La suma de verificación se calcula sobre el JSON del contenido, no sobre
  /// el fichero entero, para que la cabecera se pueda leer aunque el contenido
  /// esté dañado y así dar un mensaje de error útil.
  String encode({bool pretty = false}) {
    final payloadJson = jsonEncode(payload.toJson());
    final document = <String, Object?>{
      'format': backupFormatId,
      'schemaVersion': schemaVersion,
      'appVersion': appVersion,
      'createdAt': createdAt.toUtc().toIso8601String(),
      if (deviceLabel != null) 'deviceLabel': deviceLabel,
      'checksum': checksumOf(payloadJson),
      'payload': jsonDecode(payloadJson),
    };

    if (pretty) {
      return const JsonEncoder.withIndent('  ').convert(document);
    }
    return jsonEncode(document);
  }

  /// Lee un documento y lo valida.
  ///
  /// Lanza [BackupFormatException] con el motivo exacto. No devuelve nunca un
  /// documento a medias: o la copia entera es válida, o no se toca nada.
  factory BackupDocument.decode(String source) {
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException catch (error) {
      throw BackupFormatException(BackupError.unreadable, error.message);
    }

    if (decoded is! Map) {
      throw const BackupFormatException(BackupError.notAShardPayBackup);
    }

    final document = Map<String, Object?>.from(decoded);
    if (document['format'] != backupFormatId) {
      throw const BackupFormatException(BackupError.notAShardPayBackup);
    }

    final schemaVersion = document['schemaVersion'];
    if (schemaVersion is! int) {
      throw const BackupFormatException(BackupError.notAShardPayBackup);
    }
    if (schemaVersion > backupSchemaVersion) {
      throw BackupFormatException(BackupError.schemaTooNew, 'esquema $schemaVersion');
    }

    final rawPayload = document['payload'];
    if (rawPayload is! Map) {
      throw const BackupFormatException(BackupError.notAShardPayBackup);
    }

    final migrated = migratePayload(Map<String, Object?>.from(rawPayload), from: schemaVersion);

    final declaredChecksum = document['checksum'];
    if (declaredChecksum is String && schemaVersion == backupSchemaVersion) {
      // La comprobación solo se exige en la versión vigente: una copia migrada
      // ya no coincide, por definición, con la suma de su origen.
      final actual = checksumOf(jsonEncode(rawPayload));
      if (actual != declaredChecksum) {
        throw BackupFormatException(BackupError.checksumMismatch, 'esperado $declaredChecksum, obtenido $actual');
      }
    }

    final payload = BackupPayload.fromJson(migrated);
    if (payload.isEmpty) {
      throw const BackupFormatException(BackupError.empty);
    }

    return BackupDocument(
      schemaVersion: schemaVersion,
      appVersion: document['appVersion'] as String? ?? 'desconocida',
      createdAt: DateTime.tryParse(document['createdAt'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
      deviceLabel: document['deviceLabel'] as String?,
      payload: payload,
    );
  }
}

/// Adapta el contenido de una copia antigua al esquema vigente.
///
/// Hoy solo existe la versión 1, así que no hay nada que adaptar. La función
/// existe ya —y con prueba— porque el momento de escribir el andamio de las
/// migraciones es antes de necesitarlo, no cuando hay copias reales en juego.
Map<String, Object?> migratePayload(Map<String, Object?> payload, {required int from}) {
  var current = payload;

  // Cadena de migraciones: cada entrada lleva el contenido de la version que
  // indica su clave a la siguiente. Hoy esta vacia porque solo existe la
  // version 1; el andamio se escribe antes de necesitarlo, no cuando ya hay
  // copias reales de gente en juego.
  const Map<int, Map<String, Object?> Function(Map<String, Object?>)> steps = <int, Map<String, Object?> Function(Map<String, Object?>)>{};

  for (var version = from; version < backupSchemaVersion; version++) {
    final step = steps[version];
    if (step == null) {
      break;
    }
    current = step(current);
  }

  return current;
}

/// Suma de verificación FNV-1a de 64 bits en hexadecimal.
///
/// No es criptográfica y no pretende serlo: sirve para detectar un fichero
/// truncado o corrupto, que es el fallo real al mover copias entre móviles. Un
/// SHA-256 obligaría a arrastrar `package:crypto` para el mismo resultado
/// práctico.
String checksumOf(String value) {
  const int prime = 0x100000001b3;
  // Se enmascara a 63 bits para que el resultado sea siempre positivo: los
  // enteros de Dart son de 64 bits con signo y un desbordamiento daria una
  // suma con un guion delante.
  const int mask = 0x7FFFFFFFFFFFFFFF;

  var hash = 0xcbf29ce484222325 & mask;
  for (final byte in utf8.encode(value)) {
    hash = (hash ^ byte) & mask;
    hash = (hash * prime) & mask;
  }

  return hash.toRadixString(16).padLeft(16, '0');
}
