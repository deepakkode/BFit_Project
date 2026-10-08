import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api_client.dart';
import '../core/app_controller.dart';
import '../core/models.dart';
import '../core/step_sync_logic.dart';
import '../core/wellness_metrics.dart';
import 'background_step_tracking.dart';

class ActivityTracker extends ChangeNotifier {
  ActivityTracker(this.app);

  final AppController app;
  StreamSubscription<AccelerometerEvent>? _accelerometer;
  StreamSubscription<StepCount>? _pedometer;
  StreamSubscription<BackgroundStepUpdate>? _backgroundStepUpdates;
  Timer? _sampleTimer;
  Timer? _retryTimer;
  Timer? _dateTimer;
  final List<JsonMap> _window = [];
  final Map<String, JsonMap> _pendingDays = {};
  AccelerometerEvent? _latestAcceleration;
  Future<void> _stepQueue = Future<void>.value();
  int _queueEpoch = 0;
  UserProfile? _profile;
  String? _userId;
  String _logDate = _utcDate(DateTime.now());
  int _steps = 0;
  int? _lastRawSteps;
  String? _lastRawDate;
  int? _lastNativeSteps;
  String? _lastNativeDate;
  bool _hasServerBaseline = false;
  bool _baselineKnown = false;
  bool _dirty = false;
  bool _running = false;
  bool _permissionGranted = true;
  bool _backgroundTracking = false;
  ActivityReading? latestActivity;
  String stepsStatus = 'Step counter is starting…';
  String activityStatus = 'Movement recognition is starting…';

  int get localSteps => _steps;
  String get stepDate => _logDate;
  bool get hasPendingSync => _dirty || _pendingDays.isNotEmpty;

  Future<void> start(UserProfile profile) async {
    if (_running && _userId == profile.id) return;
    await stop();
    _queueEpoch++;
    _pendingDays.clear();
    _steps = 0;
    _lastRawSteps = null;
    _lastRawDate = null;
    _lastNativeSteps = null;
    _lastNativeDate = null;
    _hasServerBaseline = false;
    _baselineKnown = false;
    _dirty = false;
    _running = true;
    _profile = profile;
    _userId = profile.id;
    _logDate = _utcDate(DateTime.now());
    await _restoreSnapshot();
    await _loadServerBaseline();
    if (!_running) return;

    var notificationGranted = true;
    if (Platform.isAndroid) {
      final permission = await Permission.activityRecognition.request();
      _permissionGranted = permission.isGranted;
      if (!_permissionGranted) {
        stepsStatus = permission.isPermanentlyDenied
            ? 'Allow physical activity access in Settings to count steps.'
            : 'Allow physical activity access to count steps.';
      } else {
        final notificationPermission = await Permission.notification.request();
        notificationGranted = notificationPermission.isGranted;
        if (!notificationGranted) {
          stepsStatus =
              'Allow notifications to keep step tracking active in the background.';
        }
      }
      if (!_permissionGranted || !notificationGranted) {
        await BackgroundStepTracking.stop();
      }
    }
    _accelerometer = accelerometerEventStream(
      samplingPeriod: SensorInterval.gameInterval,
    ).listen(
      (event) => _latestAcceleration = event,
      onError: (Object error) {
        activityStatus = 'Motion sensor unavailable on this device.';
        notifyListeners();
      },
      cancelOnError: false,
    );
    _sampleTimer = Timer.periodic(
      const Duration(milliseconds: 50),
      (_) => _captureSample(),
    );
    if (Platform.isAndroid && _permissionGranted && notificationGranted) {
      _backgroundStepUpdates = BackgroundStepTracking.updates.listen(
        _onBackgroundStepUpdate,
        onError: (Object error) {
          if (!_running) return;
          _backgroundTracking = false;
          stepsStatus =
              'Background tracking could not connect. Steps may pause when BFit is closed.';
          _startPedometer();
          notifyListeners();
        },
        cancelOnError: false,
      );
      try {
        _backgroundTracking = await BackgroundStepTracking.start(
          userId: profile.id,
          seedSteps: _steps,
        );
        if (!_backgroundTracking) {
          stepsStatus =
              'Background step tracking did not start. Steps may pause when BFit is closed.';
        }
      } catch (_) {
        _backgroundTracking = false;
        stepsStatus =
            'Background step tracking is unavailable. Steps may pause when BFit is closed.';
      }
    }
    if (_permissionGranted && !(_backgroundTracking && Platform.isAndroid)) {
      _startPedometer();
    }
    _retryTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      unawaited(_enqueueStepWork(_retrySync));
    });
    _dateTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      unawaited(_enqueueStepWork(_checkDateRollover));
    });
    if (!_permissionGranted) {
      stepsStatus = 'Steps are paused until activity access is allowed.';
    } else if (Platform.isAndroid && !notificationGranted) {
      stepsStatus =
          'Allow notifications to keep step tracking active in the background.';
    } else if (_backgroundTracking) {
      stepsStatus = 'Background step tracking is active · syncing with BFit';
    } else if (stepsStatus == 'Step counter is starting…') {
      stepsStatus =
          'Step counter is active · earlier phone history may not be available';
    }
    activityStatus = 'Collecting movement data · 20 samples per second';
    notifyListeners();
  }

  void _startPedometer() {
    if (_pedometer != null || !_permissionGranted) return;
    _pedometer = Pedometer.stepCountStream.listen(
      _onStepCount,
      onError: (Object error) {
        stepsStatus = 'Step counter is unavailable. Check device permissions.';
        notifyListeners();
      },
      cancelOnError: false,
    );
  }

  void _onBackgroundStepUpdate(BackgroundStepUpdate update) {
    if (!_running || update.userId != _userId) return;
    if (!update.available) {
      _backgroundTracking = false;
      stepsStatus = update.message.isNotEmpty
          ? update.message
          : 'Background step tracking is unavailable on this phone.';
      _startPedometer();
      notifyListeners();
      return;
    }
    _backgroundTracking = true;
    if (update.logDate != _logDate) {
      unawaited(_enqueueStepWork(() async {
        await _checkDateRollover();
        if (update.logDate != _logDate) return;
        await _applyBackgroundStepUpdate(update);
      }));
      return;
    }
    unawaited(_enqueueStepWork(() => _applyBackgroundStepUpdate(update)));
  }

  Future<void> _applyBackgroundStepUpdate(BackgroundStepUpdate update) async {
    final delta = nativeStepDelta(
      updateDate: update.logDate,
      updateSteps: update.steps,
      seedSteps: update.seedSteps,
      seeded: update.seeded,
      previousDate: _lastNativeDate,
      previousSteps: _lastNativeSteps,
    );
    _lastNativeDate = update.logDate;
    _lastNativeSteps = update.steps;
    if (delta > 0) {
      _steps += delta;
      _dirty = true;
    }
    await _persistSnapshot();
    if (delta > 0) {
      await _retrySync();
    } else if (_running) {
      stepsStatus = _dirty || _pendingDays.isNotEmpty
          ? 'Steps are saved on this phone and waiting to sync.'
          : 'Background step tracking is active · synced';
      notifyListeners();
    }
  }

  void _captureSample() {
    if (!_running || _latestAcceleration == null) return;
    final readingTime = DateTime.now().toUtc();
    _window.add({
      'timestamp': readingTime.toIso8601String(),
      'acc_x': _latestAcceleration!.x,
      'acc_y': _latestAcceleration!.y,
      'acc_z': _latestAcceleration!.z,
    });
    if (_window.length < 200) return;
    final samples = List<JsonMap>.from(_window);
    _window.clear();
    activityStatus = 'Sending a movement window for recognition…';
    notifyListeners();
    unawaited(_sendWindow(samples));
  }

  Future<void> _sendWindow(List<JsonMap> samples) async {
    try {
      await app.api.predict({
        'window_start': samples.first['timestamp'],
        'sample_rate_hz': 20,
        'samples': samples,
      });
      try {
        latestActivity = await app.api.currentActivity();
      } on ApiException {
        // The prediction succeeded; a fresh summary can be loaded by Home on retry.
      }
      activityStatus = 'Movement recognition is up to date';
    } on ApiException catch (error) {
      activityStatus = error.statusCode == 503
          ? 'Activity recognition is temporarily unavailable.'
          : 'Movement update could not sync. It will try again in a moment.';
    } catch (_) {
      activityStatus = 'Movement update could not sync. Check your connection.';
    }
    if (_running) notifyListeners();
  }

  void _onStepCount(StepCount event) {
    unawaited(_enqueueStepWork(() async {
      final rawSteps = event.steps;
      final previous = _lastRawSteps;
      final previousRawDate = _lastRawDate;
      _lastRawSteps = rawSteps;
      await _checkDateRollover();
      if (previousRawDate != null &&
          !canApplyStepDeltaAcrossDates(previousRawDate, _logDate)) {
        _lastRawDate = _logDate;
        stepsStatus =
            'Step counter resumed on a new UTC day; it cannot split missed steps across days.';
        await _persistSnapshot();
        notifyListeners();
        return;
      }
      if (previous == null) {
        _lastRawDate = _logDate;
        await _persistSnapshot();
        return;
      }
      _lastRawDate = _logDate;
      if (rawSteps < previous) {
        _steps += rawSteps;
        _dirty = _dirty || rawSteps > 0;
        await _persistSnapshot();
        if (_dirty) await _retrySync();
        return;
      }
      final delta = rawSteps - previous;
      if (delta <= 0) return;
      _steps += delta;
      _dirty = true;
      await _persistSnapshot();
      await _retrySync();
      notifyListeners();
    }));
  }

  Future<void> _enqueueStepWork(Future<void> Function() work) {
    final epoch = _queueEpoch;
    final task = _stepQueue.then((_) async {
      if (_running && epoch == _queueEpoch) await work();
    });
    _stepQueue = task.catchError((Object error) {
      if (epoch == _queueEpoch) {
        stepsStatus = 'Steps are counted on this phone, but could not be saved.';
        if (_running) notifyListeners();
      }
    });
    return _stepQueue;
  }

  Future<void> _checkDateRollover() async {
    final today = _utcDate(DateTime.now());
    if (today == _logDate) return;
    if (_dirty) {
      _pendingDays[_logDate] = {
        'steps': _steps,
        'baseline_known': _baselineKnown,
      };
    }
    _logDate = today;
    _steps = 0;
    _dirty = false;
    _hasServerBaseline = false;
    _baselineKnown = false;
    await _persistSnapshot();
    await _loadServerBaseline();
  }

  Future<void> _loadServerBaseline({bool syncPending = true}) async {
    try {
      final server = await app.api.todaySteps();
      if (_utcDate(DateTime.now()) != _logDate) {
        await _checkDateRollover();
        return;
      }
      if (_dateKey(server.logDate) != _logDate) {
        _hasServerBaseline = false;
        if (_running) {
          stepsStatus =
              'Steps are saved on this phone; today’s server total is not available yet.';
          notifyListeners();
        }
        return;
      }
      _steps = reconcileStepTotal(
        localSteps: _steps,
        baselineKnown: _baselineKnown,
        serverSteps: server.steps,
      );
      _baselineKnown = true;
      _hasServerBaseline = true;
      if (_steps > server.steps) _dirty = true;
      await _persistSnapshot();
      if (syncPending && _dirty) await _retrySync();
      if (_running) {
        stepsStatus = _dirty
            ? 'Steps are saved on this phone and waiting to sync.'
            : 'Step counter is active · synced';
        notifyListeners();
      }
    } catch (_) {
      _hasServerBaseline = false;
      if (_running) {
        stepsStatus = 'Steps are saved on this phone; sync will resume when online.';
        notifyListeners();
      }
    }
  }

  Future<void> _retrySync() async {
    if (!_running) return;
    if (!_hasServerBaseline) {
      await _loadServerBaseline(syncPending: false);
      if (!_hasServerBaseline) return;
    }
    try {
      final dates = _pendingDays.keys.where((date) => date != _logDate).toList()..sort();
      for (final date in dates) {
        final queued = _pendingDays[date]!;
        final day = DateTime.parse('${date}T00:00:00Z');
        final existing = await app.api.stepHistory(start: day, end: day);
        final serverTotal = existing
            .where((entry) => _dateKey(entry.logDate) == date)
            .fold<int>(0, (sum, entry) => sum + entry.steps);
        final total = reconcileStepTotal(
          localSteps: asInt(queued['steps']),
          baselineKnown: queued['baseline_known'] == true,
          serverSteps: serverTotal,
        );
        // Journal the reconciled absolute total before the idempotent upsert.
        // A restart after a successful upload can then safely retry this value.
        _pendingDays[date] = {'steps': total, 'baseline_known': true};
        await _persistSnapshot();
        await _uploadDay(date, total);
        _pendingDays.remove(date);
        await _persistSnapshot();
      }
      if (_dirty) {
        await _loadServerBaseline(syncPending: false);
      }
      if (_dirty && _hasServerBaseline) {
        final snapshotSteps = _steps;
        final snapshotDate = _logDate;
        await _uploadDay(snapshotDate, snapshotSteps);
        if (_steps == snapshotSteps &&
            _logDate == snapshotDate &&
            _logDate == _utcDate(DateTime.now())) {
          _dirty = false;
        }
      }
      stepsStatus = _dirty || _pendingDays.isNotEmpty
          ? 'A few new steps are still waiting to sync.'
          : 'Step counter is active · synced';
      await _persistSnapshot();
      if (_running) notifyListeners();
    } catch (error) {
      stepsStatus = error is ApiException && error.statusCode == 401
          ? 'Sign in again to sync today’s steps.'
          : 'Steps are saved on this phone; sync will retry automatically.';
      try {
        await _persistSnapshot();
      } catch (_) {
        stepsStatus = 'Step sync failed and this phone could not save the pending total.';
      }
      if (_running) notifyListeners();
    }
  }

  Future<void> _uploadDay(String date, int total) async {
    final metrics = estimateWalkingMetrics(total, app.user ?? _profile);
    await app.api.updateSteps(StepDay(
      logDate: DateTime.parse('${date}T00:00:00Z'),
      steps: total,
      distanceKm: metrics.distanceKm,
      calories: metrics.caloriesKcal,
    ));
    if (date == _logDate) _baselineKnown = true;
  }

  String get _snapshotKey => 'bfit.steps.$_userId';

  Future<void> _restoreSnapshot() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(_snapshotKey);
    if (encoded == null) return;
    var migratedPreviousDay = false;
    try {
      final value = jsonDecode(encoded) as Map<String, dynamic>;
      final pending = value['pending_days'];
      if (pending is Map) {
        for (final entry in pending.entries) {
          if (entry.value is Map) {
            _pendingDays['${entry.key}'] =
                Map<String, dynamic>.from(entry.value as Map);
          }
        }
      }
      if (value['log_date'] == _logDate) {
        _steps = asInt(value['steps']);
        _dirty = value['pending'] == true;
        _baselineKnown = value['baseline_known'] == true;
      } else {
        final previous = recoverPreviousPendingDay(
          snapshotDate: value['log_date'] as String?,
          currentDate: _logDate,
          steps: asInt(value['steps']),
          pending: value['pending'] == true,
          baselineKnown: value['baseline_known'] == true,
        );
        if (previous != null) {
          _pendingDays[previous.date] = previous.toJson();
          migratedPreviousDay = true;
        }
      }
      final raw = value['raw_steps'];
      if (raw is num) _lastRawSteps = raw.toInt();
      final rawDate = value['raw_date'];
      if (rawDate is String) {
        _lastRawDate = rawDate;
      } else if (value['log_date'] is String && raw is num) {
        _lastRawDate = value['log_date'] as String;
      }
      final nativeSteps = value['native_steps'];
      if (nativeSteps is num) _lastNativeSteps = nativeSteps.toInt();
      final nativeDate = value['native_date'];
      if (nativeDate is String) _lastNativeDate = nativeDate;
    } on FormatException {
      await prefs.remove(_snapshotKey);
    } on TypeError {
      await prefs.remove(_snapshotKey);
    }
    if (migratedPreviousDay) await _persistSnapshot();
  }

  Future<void> _persistSnapshot() async {
    if (_dirty) {
      _pendingDays[_logDate] = {
        'steps': _steps,
        'baseline_known': _baselineKnown,
      };
    } else {
      _pendingDays.remove(_logDate);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_snapshotKey, jsonEncode({
      'log_date': _logDate,
      'steps': _steps,
      'raw_steps': _lastRawSteps,
      'raw_date': _lastRawDate,
      'native_steps': _lastNativeSteps,
      'native_date': _lastNativeDate,
      'pending': _dirty,
      'baseline_known': _baselineKnown,
      'pending_days': _pendingDays,
    }));
  }

  Future<void> stop() async {
    _running = false;
    _queueEpoch++;
    _sampleTimer?.cancel();
    _retryTimer?.cancel();
    _dateTimer?.cancel();
    await _accelerometer?.cancel();
    await _pedometer?.cancel();
    await _backgroundStepUpdates?.cancel();
    _accelerometer = null;
    _pedometer = null;
    _backgroundStepUpdates = null;
    _backgroundTracking = false;
    _sampleTimer = null;
    _retryTimer = null;
    _dateTimer = null;
  }

  @override
  void dispose() {
    unawaited(stop());
    super.dispose();
  }

  static String _utcDate(DateTime value) {
    final date = value.toUtc();
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  static String _dateKey(DateTime value) {
    final date = value.toUtc();
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }
}
