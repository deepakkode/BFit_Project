import 'package:bfit/services/background_step_tracking.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('nativeStepDelta', () {
    test('does not re-add the local total when tracking is first seeded', () {
      expect(
        nativeStepDelta(
          updateDate: '2026-10-08',
          updateSteps: 4200,
          seedSteps: 4200,
          seeded: true,
          previousDate: null,
          previousSteps: null,
        ),
        0,
      );
    });

    test('adds only new steps from an already observed daily total', () {
      expect(
        nativeStepDelta(
          updateDate: '2026-10-08',
          updateSteps: 4350,
          seedSteps: 4000,
          seeded: false,
          previousDate: '2026-10-08',
          previousSteps: 4200,
        ),
        150,
      );
    });

    test('recovers steps recorded while Flutter was stopped', () {
      expect(
        nativeStepDelta(
          updateDate: '2026-10-08',
          updateSteps: 900,
          seedSteps: 500,
          seeded: false,
          previousDate: '2026-10-07',
          previousSteps: 2200,
        ),
        400,
      );
    });

    test('does not count a reset or a lower duplicate sensor total', () {
      expect(
        nativeStepDelta(
          updateDate: '2026-10-08',
          updateSteps: 100,
          seedSteps: 0,
          seeded: false,
          previousDate: '2026-10-08',
          previousSteps: 150,
        ),
        0,
      );
    });
  });
}
