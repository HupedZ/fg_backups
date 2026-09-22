import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;

import 'api_service.dart';

class FolderBackupResult {
  final String folderPath;
  final bool success;
  final String? error;

  FolderBackupResult({required this.folderPath, required this.success, this.error});
}

class BackupRunnerService {
  final _api = ApiService();

  /// Comprime y sube cada carpeta de [folders] para el cliente [clientId].
  /// Devuelve un resultado por carpeta; no lanza si una carpeta falla,
  /// para que las demas se sigan intentando.
  Future<List<FolderBackupResult>> runBackup({
    required String clientId,
    required List<String> folders,
  }) async {
    final results = <FolderBackupResult>[];

    for (final folderPath in folders) {
      File? zipFile;
      try {
        zipFile = await _zipFolder(folderPath);
        await _api.uploadBackup(clientId: clientId, zipFile: zipFile);
        results.add(FolderBackupResult(folderPath: folderPath, success: true));
      } catch (err) {
        results.add(FolderBackupResult(folderPath: folderPath, success: false, error: err.toString()));
      } finally {
        if (zipFile != null && await zipFile.exists()) {
          await zipFile.delete();
        }
      }
    }

    return results;
  }

  Future<File> _zipFolder(String folderPath) async {
    final sourceDir = Directory(folderPath);
    if (!await sourceDir.exists()) {
      throw Exception('La carpeta no existe: $folderPath');
    }

    final folderName = p.basename(folderPath);
    final zipPath = p.join(Directory.systemTemp.path, '${folderName}_${DateTime.now().millisecondsSinceEpoch}.zip');

    final encoder = ZipFileEncoder();
    await encoder.zipDirectory(sourceDir, filename: zipPath);

    return File(zipPath);
  }
}
