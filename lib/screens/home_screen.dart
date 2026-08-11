import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/backup_entry.dart';
import '../services/api_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _api = ApiService();
  final _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  BackupStatus? _status;
  List<BackupEntry> _backups = [];
  bool _loading = true;
  bool _toggling = false;
  String? _error;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _bootstrap();
    _refreshTimer = Timer.periodic(const Duration(seconds: 20), (_) => _refresh(silent: true));
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await _refresh();
  }

  Future<void> _refresh({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final results = await Future.wait([_api.getStatus(), _api.getBackups()]);
      if (!mounted) return;
      setState(() {
        _status = results[0] as BackupStatus;
        _backups = results[1] as List<BackupEntry>;
        _error = null;
        _loading = false;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _error = err.toString();
        _loading = false;
      });
    }
  }

  Future<void> _toggle() async {
    if (_status == null || _toggling) return;
    setState(() => _toggling = true);
    try {
      final next = await _api.setEnabled(!_status!.enabled);
      if (!mounted) return;
      setState(() => _status = next);
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err.toString())));
    } finally {
      if (mounted) setState(() => _toggling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = _status?.enabled ?? false;
    final stateColor = enabled ? Colors.green : Colors.red;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Herramienta de Backups'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _refresh(),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
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
                          _PowerButton(
                            enabled: enabled,
                            busy: _toggling,
                            onPressed: _toggle,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            enabled ? 'Encendido' : 'Apagado',
                            style: TextStyle(
                              color: stateColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (_status?.lastRun != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Ultimo backup: ${_dateFormat.format(_status!.lastRun!.toLocal())}'
                      '${_status!.lastStatus == 'error' ? ' (fallo)' : ''}',
                      style: TextStyle(
                        color: _status!.lastStatus == 'error' ? Colors.red : Colors.grey,
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                  const Text(
                    'Backups realizados',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  if (_backups.isEmpty)
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
            ),
    );
  }
}

class _PowerButton extends StatelessWidget {
  final bool enabled;
  final bool busy;
  final VoidCallback onPressed;

  const _PowerButton({required this.enabled, required this.busy, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final color = enabled ? Colors.green : Colors.red;
    return Material(
      color: color.withValues(alpha: 0.15),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: busy ? null : onPressed,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: busy
              ? SizedBox(
                  width: 48,
                  height: 48,
                  child: CircularProgressIndicator(strokeWidth: 3, color: color),
                )
              : Icon(Icons.power_settings_new, size: 48, color: color),
        ),
      ),
    );
  }
}
