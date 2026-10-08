import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';
import 'models.dart';
import 'wellness_metrics.dart';
import '../services/background_step_tracking.dart';

class AppController extends ChangeNotifier {
  AppController({BFitApi? api})
      : _storage = const FlutterSecureStorage(),
        api = api ?? BFitApi() {
    this.api.onUnauthorized = expireSession;
  }

  final FlutterSecureStorage _storage;
  final BFitApi api;
  UserProfile? user;
  bool isLoading = true;
  bool isDark = false;
  int profileRevision = 0;
  int goalRevision = 0;
  String? bannerMessage;

  static const _tokenKey = 'bfit.accessToken';

  Future<void> initialize() async {
    final preferences = await SharedPreferences.getInstance();
    isDark = preferences.getBool('bfit.darkMode') ?? false;
    final token = await _storage.read(key: _tokenKey);
    if (token != null) {
      api.token = token;
      try {
        user = await api.profile();
      } on ApiException {
        await BackgroundStepTracking.stop();
        await _storage.delete(key: _tokenKey);
        api.token = null;
      }
    }
    isLoading = false;
    notifyListeners();
  }

  Future<void> signIn(String email, String password) async {
    final result = await api.login(email, password);
    await _saveSession(asString(result['access_token']));
  }

  Future<void> registerAndSignIn({
    required String name,
    required String email,
    required String password,
    int? age,
    double? heightCm,
    double? weightKg,
    String? gender,
  }) async {
    await api.register({
      'name': name.trim(),
      'email': email.trim(),
      'password': password,
      'age': age,
      'height_cm': heightCm,
      'weight_kg': weightKg,
      'gender': gender,
    });
    await signIn(email, password);
  }

  Future<void> _saveSession(String token) async {
    if (token.isEmpty)
      throw const ApiException('Sign-in did not return a secure session.');
    await _storage.write(key: _tokenKey, value: token);
    api.token = token;
    try {
      user = await api.profile();
    } catch (_) {
      api.token = null;
      await _storage.delete(key: _tokenKey);
      rethrow;
    }
    bannerMessage = null;
    notifyListeners();
  }

  Future<String?> updateProfile({
    required int age,
    required double heightCm,
    required double weightKg,
    String? gender,
  }) async {
    final previous = user;
    final updated = await api.updateProfile({
      'age': age,
      'height_cm': heightCm,
      'weight_kg': weightKg,
      'gender': gender?.isEmpty == true ? null : gender,
    });
    final wasComplete = previous?.isComplete ?? false;
    final profileChanged = previous == null ||
        previous.age != updated.age ||
        previous.heightCm != updated.heightCm ||
        previous.weightKg != updated.weightKg ||
        previous.gender != updated.gender;
    String? outcome;
    if (profileChanged) {
      GoalSettings? existingGoals;
      try {
        existingGoals = await api.goals();
      } catch (error) {
        outcome =
            'Your profile is saved, but the daily goal could not be refreshed. '
            'Weekly runs and monthly distance were left unchanged. ${_errorMessage(error)}';
      }

      if (existingGoals != null) {
        List<StepDay> history = [];
        var usedProfileOnlyStartingPoint = false;
        try {
          history = await api.stepHistory();
        } catch (_) {
          usedProfileOnlyStartingPoint = true;
        }

        final updatedGoals = applyDailyGoalRecommendation(
          existing: existingGoals,
          history: history,
          now: DateTime.now().toUtc(),
          profile: updated,
        );
        try {
          await _persistGoals(updatedGoals, notify: false);
          outcome = usedProfileOnlyStartingPoint
              ? 'Your profile and a profile-based daily starting goal are saved. '
                  'Recent step history was unavailable, so the goal does not include it. '
                  'Weekly runs and monthly distance are unchanged.'
              : 'Your profile and daily goal are updated. '
                  'Weekly runs and monthly distance are unchanged.';
        } catch (error) {
          outcome =
              'Your profile is saved, but the daily goal could not be refreshed. '
              'Weekly runs and monthly distance were left unchanged. ${_errorMessage(error)}';
        }
      }
    }

    if (api.token == null) return outcome;
    user = updated;
    if (profileChanged) profileRevision++;
    if (!wasComplete) bannerMessage = outcome;
    notifyListeners();
    return outcome;
  }

  static String _errorMessage(Object error) => error is ApiException
      ? error.message
      : 'Check your connection and try again.';

  Future<GoalSettings> saveGoals(GoalSettings goals) =>
      _persistGoals(goals, notify: true);

  Future<GoalSettings> _persistGoals(
    GoalSettings goals, {
    required bool notify,
  }) async {
    final saved = await api.saveGoals(goals);
    goalRevision++;
    if (notify) notifyListeners();
    return saved;
  }

  Future<void> signOut() async {
    await BackgroundStepTracking.stop();
    user = null;
    api.token = null;
    await _storage.delete(key: _tokenKey);
    notifyListeners();
  }

  void expireSession() {
    if (user == null) return;
    unawaited(BackgroundStepTracking.stop());
    user = null;
    api.token = null;
    unawaited(_storage.delete(key: _tokenKey));
    bannerMessage = 'Your session ended. Sign in again to continue.';
    notifyListeners();
  }

  Future<void> setDarkMode(bool value) async {
    isDark = value;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('bfit.darkMode', value);
    notifyListeners();
  }

  void clearBanner() {
    bannerMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    api.close();
    super.dispose();
  }
}
