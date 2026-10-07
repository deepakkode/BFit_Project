import 'package:bfit/core/models.dart';
import 'package:bfit/core/reminder_schedule_logic.dart';
import 'package:bfit/core/step_sync_logic.dart';
import 'package:bfit/core/wellness_metrics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  group('walking estimates', () {
    test('uses profile height and weight for distance and energy', () {
      final result = estimateWalkingMetrics(
        10000,
        const UserProfile(
          id: 'u1',
          name: 'Ari',
          email: 'ari@example.com',
          age: 35,
          heightCm: 170,
          weightKg: 70,
        ),
      );

      expect(result.distanceKm, 7.021);
      expect(result.caloriesKcal, 245.7);
    });

    test('uses a neutral estimate when profile values are absent', () {
      final result = estimateWalkingMetrics(-100, null);

      expect(result.distanceKm, 0);
      expect(result.caloriesKcal, 0);
    });
  });

  group('personal step goals', () {
    test('uses a gradual profile-adjusted starter before three tracked days', () {
      final result = recommendStepGoal(
        [
          StepDay(logDate: DateTime.utc(2026, 10, 5), steps: 4000),
          StepDay(logDate: DateTime.utc(2026, 10, 6), steps: 6000),
        ],
        DateTime.utc(2026, 10, 6, 12),
        null,
      );

      expect(result.dailyStepGoal, starterDailyStepGoal);
      expect(result.sampleDays, 2);
      expect(result.isPersonalized, isFalse);
    });

    test('uses the recent seven-day average when there is enough history', () {
      final days = [
        (DateTime.utc(2026, 9, 29), 10000),
        (DateTime.utc(2026, 10, 1), 5000),
        (DateTime.utc(2026, 10, 2), 7000),
        (DateTime.utc(2026, 10, 3), 5000),
        (DateTime.utc(2026, 10, 6), 6000),
        (DateTime.utc(2026, 10, 6), 20000),
      ].map((item) => StepDay(logDate: item.$1, steps: item.$2)).toList();

      final result = recommendStepGoal(days, DateTime.utc(2026, 10, 6, 12), null);

      expect(result.averageSteps, 8600);
      expect(result.dailyStepGoal, 9500);
      expect(result.sampleDays, 5);
      expect(result.isPersonalized, isTrue);
    });

    test('clamps a high recommendation and respects profile factors', () {
      final history = List.generate(
        3,
        (index) => StepDay(
          logDate: DateTime.utc(2026, 10, 4 + index),
          steps: 50000,
        ),
      );
      final high = recommendStepGoal(history, DateTime.utc(2026, 10, 6), null);
      final adjusted = recommendStepGoal(
        const [],
        DateTime.utc(2026, 10, 6),
        const UserProfile(
          id: 'u1',
          name: 'Ari',
          email: 'ari@example.com',
          age: 65,
          heightCm: 150,
          weightKg: 90,
          gender: 'Male',
        ),
      );

      expect(high.dailyStepGoal, 12000);
      expect(adjusted.dailyStepGoal, isNot(starterDailyStepGoal));
    });

    test('profile recommendation preserves the existing weekly and monthly goals', () {
      const existing = GoalSettings(
        dailySteps: 8000,
        weeklyRuns: 5,
        monthlyDistance: 72.5,
      );
      const profile = UserProfile(
        id: 'u1',
        name: 'Ari',
        email: 'ari@example.com',
        age: 40,
        heightCm: 170,
        weightKg: 70,
        gender: 'Female',
      );

      final updated = applyDailyGoalRecommendation(
        existing: existing,
        history: const [],
        now: DateTime.utc(2026, 10, 6),
        profile: profile,
      );

      expect(updated.dailySteps, isNot(existing.dailySteps));
      expect(updated.weeklyRuns, existing.weeklyRuns);
      expect(updated.monthlyDistance, existing.monthlyDistance);
    });
  });

  group('step total reconciliation', () {
    test('adds a server baseline only once to an unbased local cache', () {
      final merged = reconcileStepTotal(
        localSteps: 1200,
        baselineKnown: false,
        serverSteps: 4000,
      );

      expect(merged, 5200);
      expect(
        reconcileStepTotal(
          localSteps: merged,
          baselineKnown: true,
          serverSteps: 4000,
        ),
        5200,
      );
    });

    group('local reminder scheduling', () {
      setUpAll(() => tzdata.initializeTimeZones());

      test('uses the next local calendar time, including after a time has passed', () {
        tz.setLocalLocation(tz.getLocation('America/New_York'));
        final beforeSelectedTime = tz.TZDateTime(tz.local, 2026, 3, 7, 9);
        final laterToday = nextLocalReminder(
          beforeSelectedTime,
          hour: 18,
          minute: 15,
        );
        expect(laterToday.day, 7);
        expect(laterToday.hour, 18);
        expect(laterToday.minute, 15);
        expect(laterToday.isAfter(beforeSelectedTime), isTrue);

        final afterSelectedTime = tz.TZDateTime(tz.local, 2026, 3, 7, 19);
        final next = nextLocalReminder(afterSelectedTime, hour: 8, minute: 30);

        expect(next.year, 2026);
        expect(next.month, 3);
        expect(next.day, 8);
        expect(next.hour, 8);
        expect(next.minute, 30);
        expect(next.isAfter(afterSelectedTime), isTrue);
        tz.setLocalLocation(tz.getLocation('UTC'));
      });
    });

    test('retries an already journaled absolute total without double counting', () {
      const localSteps = 5200;
      final retryAfterSuccessfulUpload = reconcileStepTotal(
        localSteps: localSteps,
        baselineKnown: true,
        serverSteps: 5200,
      );

      expect(retryAfterSuccessfulUpload, localSteps);
    });

    test('keeps a higher server total when another client advanced the day', () {
      expect(
        reconcileStepTotal(
          localSteps: 5200,
          baselineKnown: true,
          serverSteps: 5600,
        ),
        5600,
      );
    });

    test('recovers an unsynced prior-day snapshot after restart', () {
      final recovered = recoverPreviousPendingDay(
        snapshotDate: '2026-10-06',
        currentDate: '2026-10-07',
        steps: 3400,
        pending: true,
        baselineKnown: true,
      );

      expect(recovered?.date, '2026-10-06');
      expect(recovered?.steps, 3400);
      expect(recovered?.baselineKnown, isTrue);
    });

    test('does not carry a clean prior-day cache into the new UTC day', () {
      expect(
        recoverPreviousPendingDay(
          snapshotDate: '2026-10-06',
          currentDate: '2026-10-07',
          steps: 3400,
          pending: false,
          baselineKnown: true,
        ),
        isNull,
      );
    });

    test('ignores malformed cached calendar dates', () {
      expect(
        recoverPreviousPendingDay(
          snapshotDate: '2026-02-31',
          currentDate: '2026-03-01',
          steps: 3400,
          pending: true,
          baselineKnown: false,
        ),
        isNull,
      );
    });

    test('does not assign an ambiguous counter delta across a UTC boundary', () {
      expect(canApplyStepDeltaAcrossDates('2026-10-06', '2026-10-07'), isFalse);
      expect(canApplyStepDeltaAcrossDates('2026-10-07', '2026-10-07'), isTrue);
    });
  });

  test('presents sitting and standing as Rest', () {
    expect(displayActivityName('Sitting'), 'Rest');
    expect(displayActivityName('Standing'), 'Rest');
    expect(displayActivityName('Walking'), 'Walking');
  });

  test('reports confidence and stale movement readings', () {
    final now = DateTime.utc(2026, 10, 6, 12);
    final lowConfidence = activityFreshness(
      ActivityReading(
        activity: 'Walking',
        confidence: 0.42,
        predictionTime: DateTime.utc(2026, 10, 6, 11, 59, 30),
      ),
      now,
    );
    final stale = activityFreshness(
      ActivityReading(
        activity: 'Standing',
        confidence: 0.95,
        predictionTime: DateTime.utc(2026, 10, 6, 11, 57),
      ),
      now,
    );

    expect(lowConfidence.note, 'Low confidence · 42%');
    expect(stale.isStale, isTrue);
  });
}
