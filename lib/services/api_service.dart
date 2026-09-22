import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

import '../config.dart' as config;
import '../models/backup_entry.dart';

class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => message;
}

class ApiService {
  final Map<String, String> _headers = {'x-api-key': config.apiKey};

  Uri _uri(String path, [Map<String, String>? query]) {
    final base = config.serverUrl.replaceAll(RegExp(r'/$'), '');
    return Uri.parse('$base$path').replace(queryParameters: query);
  }

  Future<void> uploadBackup({required String clientId, required File zipFile}) async {
    final request = http.MultipartRequest('POST', _uri('/api/upload'))
      ..headers.addAll(_headers)
      ..fields['clientId'] = clientId
      ..files.add(await http.MultipartFile.fromPath('file', zipFile.path));

    final streamed = await request.send().timeout(const Duration(minutes: 30));
    final res = await http.Response.fromStream(streamed);
    _checkOk(res);
  }

  Future<List<BackupEntry>> getBackups(String clientId) async {
    final res = await http
        .get(_uri('/api/backups', {'clientId': clientId}), headers: _headers)
        .timeout(const Duration(seconds: 15));
    _checkOk(res);
    final list = jsonDecode(res.body) as List<dynamic>;
    return list.map((e) => BackupEntry.fromJson(e as Map<String, dynamic>)).toList();
  }

  void _checkOk(http.Response res) {
    if (res.statusCode == 401) {
      throw ApiException('API key invalida');
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException('Error del servidor (${res.statusCode})');
    }
  }
}
