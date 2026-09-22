import 'dart:io';

import 'package:flutter/material.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:window_manager/window_manager.dart';

import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await windowManager.ensureInitialized();
  const windowOptions = WindowOptions(
    size: Size(520, 720),
    center: true,
    title: 'Herramienta de Backups',
  );
  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  // El destino real de esta app es Windows (servidores de clientes); en otras
  // plataformas de escritorio el plugin no tiene canal nativo registrado.
  if (Platform.isWindows) {
    launchAtStartup.setup(
      appName: 'Herramienta de Backups',
      appPath: Platform.resolvedExecutable,
    );
    await launchAtStartup.enable();
  }

  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Herramienta de Backups',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.blueGrey, useMaterial3: true),
      home: const HomeScreen(),
    );
  }
}
