import 'dart:convert';

import 'package:bfit/core/api_client.dart';
import 'package:bfit/core/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('sends absolute UTC step totals to the existing upsert contract', () async {
    http.Request? captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(
        jsonEncode({
          'id': 'daily-1',
          'log_date': '2026-10-06',
          'steps': 7210,
          'distance_km': 5.1,
          'calories_burned': 178.5,
        }),
        200,
      );
    });
    final api = BFitApi(baseUrl: 'https://example.test/api/v1', client: client)
      ..token = 'test-token';

    final result = await api.updateSteps(StepDay(
      logDate: DateTime.utc(2026, 10, 6),
      steps: 7210,
      distanceKm: 5.1,
      calories: 178.5,
    ));

    expect(captured!.url.path, '/api/v1/steps/update');
    expect(captured!.headers['authorization'], 'Bearer test-token');
    expect(jsonDecode(captured!.body), {
      'log_date': '2026-10-06',
      'steps': 7210,
      'distance_km': 5.1,
      'calories_burned': 178.5,
    });
    expect(result.steps, 7210);
    api.close();
  });

  test('updates all existing goal fields when persisting a revised daily goal', () async {
    http.Request? captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(
        '{"daily_step_goal":7500,"weekly_running_goal":4,'
        '"monthly_distance_goal":62.5}',
        200,
      );
    });
    final api = BFitApi(baseUrl: 'https://example.test/api/v1', client: client)
      ..token = 'test-token';

    final result = await api.saveGoals(const GoalSettings(
      dailySteps: 7500,
      weeklyRuns: 4,
      monthlyDistance: 62.5,
    ));

    expect(captured!.url.path, '/api/v1/goals');
    expect(captured!.method, 'PUT');
    expect(jsonDecode(captured!.body), {
      'daily_step_goal': 7500,
      'weekly_running_goal': 4,
      'monthly_distance_goal': 62.5,
    });
    expect(result.weeklyRuns, 4);
    expect(result.monthlyDistance, 62.5);
    api.close();
  });

  test('parses bearer token response and profile resource', () async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/auth/login')) {
        expect(request.headers['content-type'], 'application/json');
        return http.Response('{"access_token":"signed","token_type":"bearer"}', 200);
      }
      expect(request.headers['authorization'], 'Bearer signed');
      return http.Response(
        '{"id":"u1","name":"Ari","email":"ari@example.com","age":35,'
        '"height_cm":170,"weight_kg":70,"gender":null,"timezone":"UTC"}',
        200,
      );
    });
    final api = BFitApi(baseUrl: 'https://example.test/api/v1', client: client);

    final token = await api.login(' ari@example.com ', 'password123');
    api.token = token['access_token'] as String;
    final profile = await api.profile();

    expect(api.token, 'signed');
    expect(profile.isComplete, isTrue);
    expect(profile.gender, isNull);
    api.close();
  });

  test('sends ordered 200-point SI activity windows at the backend rate', () async {
    http.Request? captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(
        '{"prediction_id":"p1","activity":"Walking","confidence_score":0.91,'
        '"model_name":"deepconv_lstm","model_version":"2.0.0",'
        '"prediction_timestamp":"2026-10-06T12:00:10Z"}',
        200,
      );
    });
    final api = BFitApi(baseUrl: 'https://example.test/api/v1', client: client)
      ..token = 'test-token';
    final start = DateTime.utc(2026, 10, 6, 12);
    final samples = List.generate(200, (index) {
      final timestamp = start.add(Duration(milliseconds: index * 50));
      return {
        'timestamp': timestamp.toIso8601String(),
        'acc_x': index / 10,
        'acc_y': 9.80665,
        'acc_z': -0.4,
      };
    });

    await api.predict({
      'window_start': start.toIso8601String(),
      'sample_rate_hz': 20,
      'samples': samples,
    });
    final body = jsonDecode(captured!.body) as Map<String, dynamic>;
    final sentSamples = body['samples'] as List;

    expect(captured!.url.path, '/api/v1/activity/predict');
    expect(body['sample_rate_hz'], 20);
    expect(sentSamples, hasLength(200));
    expect(sentSamples.first['timestamp'], start.toIso8601String());
    expect(sentSamples.last['timestamp'], start.add(const Duration(milliseconds: 9950)).toIso8601String());
    expect(sentSamples[1]['acc_y'], 9.80665);
    api.close();
  });

  test('surfaces backend validation details instead of pretending success', () async {
    final api = BFitApi(
      baseUrl: 'https://example.test/api/v1',
      client: MockClient((_) async => http.Response(
            '{"detail":"An account with this email already exists"}',
            409,
          )),
    );

    await expectLater(
      api.login('ari@example.com', 'password123'),
      throwsA(isA<ApiException>().having((error) => error.statusCode, 'status', 409)),
    );
    api.close();
  });
}
