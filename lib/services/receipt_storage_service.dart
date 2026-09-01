import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

class StoredReceipt {
  const StoredReceipt({required this.storagePath, required this.downloadUrl});

  final String storagePath;
  final String downloadUrl;
}

class ReceiptStorageService {
  const ReceiptStorageService({required this.enabled});

  final bool enabled;

  Future<StoredReceipt?> uploadReceipt({required String groupId, required String expenseId, required String imagePath}) async {
    if (!enabled) {
      return null;
    }

    final file = File(imagePath);
    // La versión síncrona es más rápida para una sola comprobación: la
    // asíncrona monta un intercambio con el hilo de E/S que aquí no compensa.
    if (!file.existsSync()) {
      return null;
    }

    final extension = imagePath.contains('.') ? imagePath.split('.').last.toLowerCase() : 'jpg';
    final storagePath = 'receipts/$groupId/$expenseId/ticket.$extension';
    final ref = FirebaseStorage.instance.ref(storagePath);

    await ref.putFile(file, SettableMetadata(contentType: extension == 'png' ? 'image/png' : 'image/jpeg'));

    return StoredReceipt(storagePath: storagePath, downloadUrl: await ref.getDownloadURL());
  }
}
