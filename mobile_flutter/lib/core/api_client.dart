import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'models.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

class BFitApi {
  BFitApi({
    String? baseUrl,
    http.Client? client,
    this.onUnauthorized,
  })  : baseUrl = _normalizeBase(baseUrl ?? const String.fromEnvironment(
          'BFIT_API_BASE_URL',
          defaultValue: 'https://bfit-api.onrender.com/api/v1',
        )),
        _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;
  VoidCallback? onUnauthorized;
  String? token;

  static String _normalizeBase(String value) => value.replaceFirst(RegExp(r'/+$'), '');

  Future<dynamic> _request(
    String method,
    String path, {
    JsonMap? body,
    Map<String, String>? query,
    bool authorized = true,
  }) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    final headers = <String, String>{'Accept': 'application/json'};
    if (body != null) headers['content-type'] = 'application/json';
    if (authorized && token != null) headers['authorization'] = 'Bearer $token';
    try {
      final request = http.Request(method, uri)..headers.addAll(headers);
      if (body != null) request.body = jsonEncode(body);
      final streamed = await _client.send(request).timeout(const Duration(seconds: 75));
      final response = await http.Response.fromStream(streamed);
      final decoded = response.body.isEmpty ? null : jsonDecode(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        if (response.statusCode == 401 && authorized) onUnauthorized?.call();
        final detail = decoded is Map ? decoded['detail'] : null;
        final message = detail is String
            ? detail
            : detail is List
                ? detail.map((item) => item is Map ? item['msg'] : item).join(', ')
                : 'The service returned ${response.statusCode}. Please try again.';
        throw ApiException(message, statusCode: response.statusCode);
      }
      return decoded;
    } on TimeoutException {
      throw const ApiException('The service is taking longer than usual. Check your connection and retry.');
    } on FormatException {
      throw const ApiException('The service returned a response BFit could not read.');
    } on http.ClientException {
      throw const ApiException('Could not reach BFit. Check your internet connection and try again.');
    }
  }

  Future<JsonMap> _map(String method, String path,
      {JsonMap? body, Map<String, String>? query, bool authorized = true}) async {
    final value = await _request(method, path,
        body: body, query: query, authorized: authorized);
    if (value is! Map) throw const ApiException('Unexpected response from BFit.');
    return Map<String, dynamic>.from(value);
  }

  Future<JsonMap> register(JsonMap payload) =>
      _map('POST', '/auth/register', body: payload, authorized: false);

  Future<JsonMap> login(String email, String password) => _map(
        'POST',
        '/auth/login',
        body: {'email': email.trim(), 'password': password},
        authorized: false,
      );

  Future<UserProfile> profile() async =>
      UserProfile.fromJson(await _map('GET', '/auth/profile'));

  Future<UserProfile> updateProfile(JsonMap payload) async =>
      UserProfile.fromJson(await _map('PUT', '/auth/profile', body: payload));

  Future<ActivityReading> currentActivity() async =>
      ActivityReading.fromJson(await _map('GET', '/activity/current'));

  Future<JsonMap> todayActivity() => _map('GET', '/activity/today');

  Future<List<ActivitySession>> activityHistory() async {
    final rows = await _list('GET', '/activity/history');
    return rows.map(ActivitySession.fromJson).toList();
  }

  Future<JsonMap> predict(JsonMap payload) =>
      _map('POST', '/activity/predict', body: payload);

  Future<StepDay> todaySteps() async =>
      StepDay.fromJson(await _map('GET', '/steps/today'));

  Future<List<StepDay>> stepHistory({DateTime? start, DateTime? end}) async {
    final now = DateTime.now().toUtc();
    final query = <String, String>{};
    if (start != null) query['start'] = _date(start);
    if (end != null) query['end'] = _date(end);
    if (query.isEmpty) {
      query['start'] = _date(now.subtract(const Duration(days: 29)));
      query['end'] = _date(now);
    }
    final rows = await _list('GET', '/steps/history', query: query);
    return rows.map(StepDay.fromJson).toList();
  }

  Future<StepDay> updateSteps(StepDay day) async => StepDay.fromJson(
        await _map('POST', '/steps/update', body: {
          'log_date': _date(day.logDate),
          'steps': day.steps,
          'distance_km': day.distanceKm,
          'calories_burned': day.calories,
        }),
      );

  Future<JsonMap> weekly({DateTime? weekStart}) => _map(
        'GET',
        '/analytics/weekly',
        query: {'week_start': _date(weekStart ?? _monday(DateTime.now().toUtc()))},
      );

  Future<JsonMap> monthly(DateTime month) =>
      _map('GET', '/analytics/monthly', query: {
        'year': '${month.year}',
        'month': '${month.month}',
      });

  Future<GoalSettings> goals() async =>
      GoalSettings.fromJson(await _map('GET', '/goals'));

  Future<GoalSettings> saveGoals(GoalSettings goals) async =>
      GoalSettings.fromJson(await _map('PUT', '/goals', body: goals.toJson()));

  Future<List<JsonMap>> _list(String method, String path,
      {Map<String, String>? query}) async {
    final value = await _request(method, path, query: query);
    if (value is! List) throw const ApiException('Unexpected response from BFit.');
    return value.map((row) {
      if (row is! Map) throw const ApiException('Unexpected response from BFit.');
      return Map<String, dynamic>.from(row);
    }).toList();
  }

  static String _date(DateTime value) =>
      '${value.toUtc().year.toString().padLeft(4, '0')}-'
      '${value.toUtc().month.toString().padLeft(2, '0')}-'
      '${value.toUtc().day.toString().padLeft(2, '0')}';

  static DateTime _monday(DateTime value) =>
      DateTime.utc(value.year, value.month, value.day)
          .subtract(Duration(days: value.weekday - DateTime.monday));

  void close() => _client.close();
}
