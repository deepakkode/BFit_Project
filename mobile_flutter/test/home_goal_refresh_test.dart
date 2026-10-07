import 'dart:convert';

import 'package:bfit/core/api_client.dart';
import 'package:bfit/core/app_controller.dart';
import 'package:bfit/core/models.dart';
import 'package:bfit/core/palette.dart';
import 'package:bfit/screens/home_screen.dart';
import 'package:bfit/services/activity_tracker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('Home refreshes its retained daily goal after a successful save',
      (tester) async {
    var goalReads = 0;
    var failNextSave = true;
    final api = BFitApi(
      baseUrl: 'https://example.test/api/v1',
      client: MockClient((request) async {
        if (request.url.path.endsWith('/goals') && request.method == 'GET') {
          goalReads++;
          return http.Response(
            jsonEncode({
              'daily_step_goal': goalReads == 1 ? 5000 : 9000,
              'weekly_running_goal': 3,
              'monthly_distance_goal': 50,
            }),
            200,
          );
        }
        if (request.url.path.endsWith('/goals') && request.method == 'PUT') {
          if (failNextSave) {
            failNextSave = false;
            return http.Response('{"detail":"Goal service unavailable"}', 503);
          }
          return http.Response(
            request.body,
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path.endsWith('/steps/today')) {
          return http.Response(
            '{"log_date":"2026-10-07","steps":0,"distance_km":0,"calories_burned":0}',
            200,
          );
        }
        if (request.url.path.endsWith('/activity/current') ||
            request.url.path.endsWith('/activity/today')) {
          return http.Response('{}', 200);
        }
        return http.Response('Unexpected request', 404);
      }),
    );
    final controller = AppController(api: api)
      ..user = const UserProfile(
        id: 'u1',
        name: 'Ari',
        email: 'ari@example.com',
      );
    final tracker = ActivityTracker(controller);

    await tester.pumpWidget(
      MaterialApp(
        theme: bfitTheme(false),
        home: HomeScreen(controller: controller, tracker: tracker),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('of 5,000 steps'), findsOneWidget);

    await expectLater(
      controller.saveGoals(const GoalSettings(
        dailySteps: 9000,
        weeklyRuns: 3,
        monthlyDistance: 50,
      )),
      throwsA(isA<ApiException>()),
    );
    await tester.pumpAndSettle();
    expect(goalReads, 1);
    expect(find.text('of 5,000 steps'), findsOneWidget);

    await controller.saveGoals(const GoalSettings(
      dailySteps: 9000,
      weeklyRuns: 3,
      monthlyDistance: 50,
    ));
    await tester.pumpAndSettle();

    expect(goalReads, 2);
    expect(find.text('of 9,000 steps'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    tracker.dispose();
    controller.dispose();
  });
}
