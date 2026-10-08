import 'dart:io';

import 'package:flutter/services.dart';

class BackgroundStepUpdate {
  const BackgroundStepUpdate({
    required this.userId,
    required this.logDate,
    required this.steps,
    required this.seedSteps,
    required this.seeded,
    required this.available,
    required this.message,
  });

  final String userId;
  final String logDate;
  final int steps;
  final int seedSteps;
  final bool seeded;
  final bool available;
  final String message;

  static BackgroundStepUpdate? fromPlatform(Object? value) {
    if (value is! Map) return null;
    final date = value['log_date'];
    final userId = value['user_id'];
    if (date is! String || userId is! String) return null;
    return BackgroundStepUpdate(
      userId: userId,
      logDate: date,
      steps: _intValue(value['steps']),
      seedSteps: _intValue(value['seed_steps']),
      seeded: value['seeded'] == true,
      available: value['available'] != false,
      message: value['message'] is String ? value['message'] as String : '',
    );
  }

  static int _intValue(Object? value) =>
      value is num && value >= 0 ? value.toInt() : 0;
}

int nativeStepDelta({
  required String updateDate,
  required int updateSteps,
  required int seedSteps,
  required bool seeded,
  required String? previousDate,
  required int? previousSteps,
}) {
  if (seeded) return 0;
  if (previousDate == updateDate && previousSteps != null) {
    return updateSteps > previousSteps ? updateSteps - previousSteps : 0;
  }
  return updateSteps > seedSteps ? updateSteps - seedSteps : 0;
}

class BackgroundStepTracking {
  BackgroundStepTracking._();

  static const _methods = MethodChannel('com.deepakkode.bfit/step_tracking');
  static const _events = EventChannel('com.deepakkode.bfit/step_updates');

  static Stream<BackgroundStepUpdate> get updates => _events
      .receiveBroadcastStream()
      .map(BackgroundStepUpdate.fromPlatform)
      .where((update) => update != null)
      .cast<BackgroundStepUpdate>();

  static Future<bool> start({
    required String userId,
    required int seedSteps,
  }) async {
    if (!Platform.isAndroid) return false;
    return await _methods.invokeMethod<bool>('start', {
          'user_id': userId,
          'seed_steps': seedSteps,
        }) ??
        false;
  }

  static Future<void> stop() async {
    if (!Platform.isAndroid) return;
    try {
      await _methods.invokeMethod<void>('stop');
    } on PlatformException {
      // Sign-out must complete even if Android cannot reach the service.
    } on MissingPluginException {
      // There is no service to stop in a non-Android or test runtime.
    }
  }
}
