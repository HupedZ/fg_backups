import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../config.dart' as config;
import '../models/backup_entry.dart';
import '../services/api_service.dart';
import '../services/backup_runner_service.dart';
import '../services/local_config_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WindowListener, TrayListener {
  final _api = ApiService();
  final _localConfig = LocalConfigService();
  final _runner = BackupRunnerService();
  final _dateFormat = DateFormat('dd/MM/yyyy HH:mm');
  final _clientIdController = TextEditingController();

  String? _clientId;
  List<String> _folders = [];
  bool _enabled = false;
  int _backupHour = 3;
  int _backupMinute = 0;

  List<BackupEntry> _backups = [];
  bool _loadingBackups = false;
  bool _running = false;
  String? _error;

  DateTime? _lastRun;
  String? _lastStatus;
  String? _lastError;
  DateTime? _lastTriggeredDate;

  Timer? _scheduleTimer;
  Timer? _backupsRefreshTimer;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    windowManager.setPreventClose(true);
    trayManager.addListener(this);
    _initTray();
    _loadConfig();
    _scheduleTimer = Timer.periodic(const Duration(seconds: 30), (_) => _checkScheduledBackup());
    _backupsRefreshTimer = Timer.periodic(const Duration(minutes: 2), (_) => _refreshBackups(silent: true));
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    trayManager.removeListener(this);
    _scheduleTimer?.cancel();
    _backupsRefreshTimer?.cancel();
    _clientIdController.dispose();
    super.dispose();
  }

  // --- ventana / bandeja ---

  Future<void> _initTray() async {
    await trayManager.setToolTip('Herramienta de Backups');
    await _updateTrayIcon();
    await trayManager.setContextMenu(
      Menu(
        items: [
          MenuItem(key: 'mostrar', label: 'Mostrar panel'),
          MenuItem.separator(),
          MenuItem(key: 'salir', label: 'Salir'),
        ],
      ),
    );
  }

  Future<void> _updateTrayIcon() async {
    final estado = _enabled ? 'on' : 'off';
    final extension = Platform.isWindows ? 'ico' : 'png';
    await trayManager.setIcon('assets/tray_icon_$estado.$extension');
  }

  @override
  void onWindowClose() async {
    await windowManager.hide();
  }

  @override
  void onTrayIconMouseDown() {
    windowManager.show();
    windowManager.focus();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) async {
    if (menuItem.key == 'mostrar') {
      await windowManager.show();
      await windowManager.focus();
    } else if (menuItem.key == 'salir') {
      await windowManager.setPreventClose(false);
      await windowManager.destroy();
    }
  }

  // --- configuracion local ---

  Future<void> _loadConfig() async {
    final clientId = await _localConfig.getClientId();
    final folders = await _localConfig.getFolders();
    final enabled = await _localConfig.getEnabled();
    final hour = await _localConfig.getBackupHour();
    final minute = await _localConfig.getBackupMinute();
    if (!mounted) return;
    setState(() {
      _clientId = clientId;
      _folders = folders;
      _enabled = enabled;
      _backupHour = hour;
      _backupMinute = minute;
    });
    await _updateTrayIcon();
    if (clientId != null && clientId.isNotEmpty) {
      await _refreshBackups();
    }
  }

  Future<void> _saveClientId() async {
    final value = _clientIdController.text.trim();
    if (value.isEmpty) return;
    await _localConfig.setClientId(value);
    setState(() => _clientId = value);
    await _refreshBackups();
  }

  Future<void> _toggleEnabled() async {
    final next = !_enabled;
    await _localConfig.setEnabled(next);
    if (!mounted) return;
    setState(() => _enabled = next);
    await _updateTrayIcon();
  }

  Future<void> _pickBackupTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _backupHour, minute: _backupMinute),
    );
    if (picked == null) return;
    await _localConfig.setBackupTime(hour: picked.hour, minute: picked.minute);
    if (!mounted) return;
    setState(() {
      _backupHour = picked.hour;
      _backupMinute = picked.minute;
    });
  }

  Future<bool> _askAdminPassword() async {
    final entered = await showDialog<String>(
      context: context,
      builder: (_) => const _PasswordDialog(),
    );
    if (entered == null) return false;
    if (entered != config.adminPassword) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Clave incorrecta')),
        );
      }
      return false;
    }
    return true;
  }

  Future<void> _addFolder() async {
    if (!await _askAdminPassword()) return;
    final path = await FilePicker.getDirectoryPath();
    if (path == null || _folders.contains(path)) return;
    final next = [..._folders, path];
    await _localConfig.setFolders(next);
    if (!mounted) return;
    setState(() => _folders = next);
  }

  Future<void> _removeFolder(String path) async {
    if (!await _askAdminPassword()) return;
    final next = _folders.where((f) => f != path).toList();
    await _localConfig.setFolders(next);
    if (!mounted) return;
    setState(() => _folders = next);
  }

  // --- backups ---

  Future<void> _refreshBackups({bool silent = false}) async {
    if (_clientId == null || _clientId!.isEmpty) return;
    if (!silent) setState(() => _loadingBackups = true);
    try {
      final list = await _api.getBackups(_clientId!);
      if (!mounted) return;
      setState(() {
        _backups = list;
        _error = null;
        _loadingBackups = false;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _error = err.toString();
        _loadingBackups = false;
      });
    }
  }

  Future<void> _checkScheduledBackup() async {
    if (!_enabled || _running) return;
    if (_clientId == null || _clientId!.isEmpty || _folders.isEmpty) return;
    final now = DateTime.now();
    if (now.hour != _backupHour || now.minute != _backupMinute) return;
    final today = DateTime(now.year, now.month, now.day);
    if (_lastTriggeredDate == today) return;
    _lastTriggeredDate = today;
    await _runBackupNow();
  }

  Future<void> _runBackupManually() async {
    if (!await _askAdminPassword()) return;
    await _runBackupNow();
  }

  Future<void> _runBackupNow() async {
    if (_clientId == null || _clientId!.isEmpty || _running) return;
    if (_folders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agrega al menos una carpeta primero')),
      );
      return;
    }

    setState(() => _running = true);
    final results = await _runner.runBackup(clientId: _clientId!, folders: _folders);
    final failed = results.where((r) => !r.success).toList();

    if (!mounted) return;
    setState(() {
      _running = false;
      _lastRun = DateTime.now();
      _lastStatus = failed.isEmpty ? 'ok' : 'error';
      _lastError = failed.isEmpty
          ? null
          : failed.map((f) => '${f.folderPath}: ${f.error}').join('\n');
    });

    await _refreshBackups();

    if (failed.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fallo el backup de ${failed.length} carpeta(s)')),
      );
    }
  }

  // --- UI ---

  @override
  Widget build(BuildContext context) {
    if (_clientId == null || _clientId!.isEmpty) {
      return _buildSetupScreen();
    }
    return _buildMainScreen();
  }

  Widget _buildSetupScreen() {
    return Scaffold(
      appBar: AppBar(title: const Text('Herramienta de Backups')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Nombre de este cliente',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Identifica a este servidor ante el VPS. Se configura una sola vez.',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _clientIdController,
                  decoration: const InputDecoration(
                    labelText: 'Ej: cliente-farmacia-xyz',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _saveClientId(),
                ),
                const SizedBox(height: 16),
                FilledButton(onPressed: _saveClientId, child: const Text('Guardar')),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainScreen() {
    final stateColor = _enabled ? Colors.green : Colors.red;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Herramienta de Backups'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _refreshBackups(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('Cliente: $_clientId', style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),
          if (_error != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red),
              ),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Backup automatico diario',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Prende o apaga la copia diaria hacia el VPS',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  _PowerButton(enabled: _enabled, onPressed: _toggleEnabled),
                  const SizedBox(height: 8),
                  Text(
                    _enabled ? 'Encendido' : 'Apagado',
                    style: TextStyle(color: stateColor, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: _pickBackupTime,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.schedule, size: 20, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    'Hora de backup diario: '
                    '${_backupHour.toString().padLeft(2, '0')}:${_backupMinute.toString().padLeft(2, '0')}',
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.edit, size: 16, color: Colors.grey),
                ],
              ),
            ),
          ),
          if (_lastRun != null) ...[
            const SizedBox(height: 4),
            Text(
              'Ultimo backup: ${_dateFormat.format(_lastRun!)}'
              '${_lastStatus == 'error' ? ' (fallo)' : ''}',
              style: TextStyle(color: _lastStatus == 'error' ? Colors.red : Colors.grey),
            ),
            if (_lastStatus == 'error' && _lastError != null)
              Text(_lastError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _running ? null : _runBackupManually,
            icon: _running
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.cloud_upload_outlined),
            label: Text(_running ? 'Subiendo...' : 'Respaldar ahora'),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Carpetas a respaldar',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(icon: const Icon(Icons.create_new_folder_outlined), onPressed: _addFolder),
            ],
          ),
          if (_folders.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('No hay carpetas agregadas', style: TextStyle(color: Colors.grey)),
            )
          else
            ..._folders.map(
              (folder) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.folder_outlined),
                  title: Text(folder, overflow: TextOverflow.ellipsis),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _removeFolder(folder),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 32),
          const Text(
            'Backups realizados',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          if (_loadingBackups)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_backups.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text('Todavia no hay backups', style: TextStyle(color: Colors.grey)),
            )
          else
            ..._backups.map(
              (b) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.folder_zip_outlined),
                  title: Text(b.name),
                  subtitle: Text(_dateFormat.format(b.date.toLocal())),
                  trailing: Text(b.sizeHuman),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog();

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Clave de acceso'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        obscureText: true,
        decoration: const InputDecoration(labelText: 'Clave', border: OutlineInputBorder()),
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Aceptar'),
        ),
      ],
    );
  }
}

class _PowerButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onPressed;

  const _PowerButton({required this.enabled, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final color = enabled ? Colors.green : Colors.red;
    return Material(
      color: color.withValues(alpha: 0.15),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Icon(Icons.power_settings_new, size: 48, color: color),
        ),
      ),
    );
  }
}
