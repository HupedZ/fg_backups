import 'dart:convert';
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
  final Map<String, String> _headers = {
    'Content-Type': 'application/json',
    'x-api-key': config.apiKey,
  };

  Uri _uri(String path) {
    return Uri.parse('${config.serverUrl.replaceAll(RegExp(r"/$"), "")}$path');
  }

  Future<BackupStatus> getStatus() async {
    final res = await http.get(_uri('/api/status'), headers: _headers).timeout(const Duration(seconds: 10));
    _checkOk(res);
    return BackupStatus.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<BackupStatus> setEnabled(bool enabled) async {
    final res = await http
        .post(_uri('/api/toggle'), headers: _headers, body: jsonEncode({'enabled': enabled}))
        .timeout(const Duration(seconds: 10));
    _checkOk(res);
    return BackupStatus.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<List<BackupEntry>> getBackups() async {
    final res = await http.get(_uri('/api/backups'), headers: _headers).timeout(const Duration(seconds: 10));
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
