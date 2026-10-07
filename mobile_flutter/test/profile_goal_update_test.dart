import 'dart:convert';

import 'package:bfit/core/api_client.dart';
import 'package:bfit/core/app_controller.dart';
import 'package:bfit/core/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('profile changes persist a revised daily goal without changing other goals', () async {
    http.Request? goalsUpdate;
    final api = BFitApi(
      baseUrl: 'https://example.test/api/v1',
      client: MockClient((request) async {
        if (request.url.path.endsWith('/auth/profile')) {
          return http.Response(
            '{"id":"u1","name":"Ari","email":"ari@example.com","age":65,'
            '"height_cm":150,"weight_kg":90,"gender":"Male","timezone":"UTC"}',
            200,
          );
        }
        if (request.url.path.endsWith('/goals') && request.method == 'GET') {
          return http.Response(
            '{"daily_step_goal":8000,"weekly_running_goal":4,'
            '"monthly_distance_goal":62.5}',
            200,
          );
        }
        if (request.url.path.endsWith('/steps/history')) {
          return http.Response('[]', 200);
        }
        if (request.url.path.endsWith('/goals') && request.method == 'PUT') {
          goalsUpdate = request;
          return http.Response(
            request.body,
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Unexpected request', 404);
      }),
    )..token = 'test-token';
    final controller = AppController(api: api)
      ..user = const UserProfile(
        id: 'u1',
        name: 'Ari',
        email: 'ari@example.com',
        age: 40,
        heightCm: 170,
        weightKg: 70,
        gender: 'Female',
      );

    final result = await controller.updateProfile(
      age: 65,
      heightCm: 150,
      weightKg: 90,
      gender: 'Male',
    );
    final savedGoals = jsonDecode(goalsUpdate!.body) as Map<String, dynamic>;

    expect(result, contains('Your profile and daily goal are updated'));
    expect(controller.profileRevision, 1);
    expect(controller.goalRevision, 1);
    expect(controller.user!.age, 65);
    expect(savedGoals['daily_step_goal'], isNot(8000));
    expect(savedGoals['weekly_running_goal'], 4);
    expect(savedGoals['monthly_distance_goal'], 62.5);
    controller.dispose();
  });

  test('profile save reports partial failure when goals cannot be persisted', () async {
    final api = BFitApi(
      baseUrl: 'https://example.test/api/v1',
      client: MockClient((request) async {
        if (request.url.path.endsWith('/auth/profile')) {
          return http.Response(
            '{"id":"u1","name":"Ari","email":"ari@example.com","age":35,'
            '"height_cm":170,"weight_kg":70,"gender":null,"timezone":"UTC"}',
            200,
          );
        }
        if (request.url.path.endsWith('/goals') && request.method == 'GET') {
          return http.Response(
            '{"daily_step_goal":6000,"weekly_running_goal":3,'
            '"monthly_distance_goal":50}',
            200,
          );
        }
        if (request.url.path.endsWith('/steps/history')) {
          return http.Response('[]', 200);
        }
        if (request.url.path.endsWith('/goals') && request.method == 'PUT') {
          return http.Response('{"detail":"Goal service unavailable"}', 503);
        }
        return http.Response('Unexpected request', 404);
      }),
    )..token = 'test-token';
    final controller = AppController(api: api)
      ..user = const UserProfile(
        id: 'u1',
        name: 'Ari',
        email: 'ari@example.com',
      );

    final result = await controller.updateProfile(
      age: 35,
      heightCm: 170,
      weightKg: 70,
    );

    expect(controller.user!.age, 35);
    expect(controller.goalRevision, 0);
    expect(
      result,
      contains('Your profile is saved, but the daily goal could not be refreshed'),
    );
    expect(controller.bannerMessage, contains('daily goal could not be refreshed'));
    controller.dispose();
  });
}
