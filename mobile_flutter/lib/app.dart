import 'dart:async';

import 'package:flutter/material.dart';

import 'core/app_controller.dart';
import 'core/palette.dart';
import 'services/reminder_service.dart';
import 'screens/app_shell.dart';
import 'screens/auth_screen.dart';
import 'screens/profile_form_screen.dart';

class BFitApp extends StatefulWidget {
  const BFitApp({required this.controller, super.key});
  final AppController controller;

  @override
  State<BFitApp> createState() => _BFitAppState();
}

class _BFitAppState extends State<BFitApp> {
  @override
  void initState() {
    super.initState();
    widget.controller.initialize();
    unawaited(ReminderService.instance.initializeSafely());
  }

  @override
  void dispose() {
    widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) {
          final app = widget.controller;
          return MaterialApp(
            title: 'BFit',
            debugShowCheckedModeBanner: false,
            theme: bfitTheme(false),
            darkTheme: bfitTheme(true),
            themeMode: app.isDark ? ThemeMode.dark : ThemeMode.light,
            home: app.isLoading
                ? const _LaunchingScreen()
                : app.user == null
                    ? AuthScreen(controller: app)
                    : !app.user!.isComplete
                        ? ProfileFormScreen(
                            controller: app,
                            requiredForUse: true,
                          )
                        : AppShell(controller: app),
          );
        },
      );
}

class _LaunchingScreen extends StatelessWidget {
  const _LaunchingScreen();
  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/brand/bfit-mark.png', width: 58, height: 58),
              const SizedBox(height: 18),
              Text('BFit', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 24),
              const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
          ),
        ),
      );
}
