import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/constants/app_theme.dart';
import 'core/network/router.dart';

void main() {
  // ⚠️ DIAGNOSTIC TEMPORAIRE : affiche l'erreur réelle au lieu d'un écran blanc/rouge
  ErrorWidget.builder = (FlutterErrorDetails details) => Material(
        color: Colors.white,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Text(
            '⚠ ERREUR DE RENDU\n\n${details.exceptionAsString()}',
            style: const TextStyle(color: Colors.red, fontSize: 12),
          ),
        ),
      );

  runApp(
    const ProviderScope(
      child: VTontineApp(),
    ),
  );
}

class VTontineApp extends StatelessWidget {
  const VTontineApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'vTontine',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      routerConfig: appRouter,
    );
  }
}