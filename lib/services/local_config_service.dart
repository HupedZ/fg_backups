import 'package:shared_preferences/shared_preferences.dart';

class LocalConfigService {
  static const _clientIdKey = 'client_id';
  static const _foldersKey = 'folders';
  static const _enabledKey = 'enabled';
  static const _backupHourKey = 'backup_hour';
  static const _backupMinuteKey = 'backup_minute';

  Future<String?> getClientId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_clientIdKey);
  }

  Future<void> setClientId(String clientId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_clientIdKey, clientId.trim());
  }

  Future<List<String>> getFolders() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_foldersKey) ?? [];
  }

  Future<void> setFolders(List<String> folders) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_foldersKey, folders);
  }

  Future<bool> getEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? false;
  }

  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);
  }

  /// Hora del backup diario (0-23). Por defecto 3 am.
  Future<int> getBackupHour() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_backupHourKey) ?? 3;
  }

  /// Minuto del backup diario (0-59). Por defecto 0.
  Future<int> getBackupMinute() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_backupMinuteKey) ?? 0;
  }

  Future<void> setBackupTime({required int hour, required int minute}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_backupHourKey, hour);
    await prefs.setInt(_backupMinuteKey, minute);
  }
}
