int reconcileStepTotal({
  required int localSteps,
  required bool baselineKnown,
  required int serverSteps,
}) {
  final local = localSteps < 0 ? 0 : localSteps;
  final server = serverSteps < 0 ? 0 : serverSteps;
  return baselineKnown ? (local > server ? local : server) : local + server;
}

class PendingStepDay {
  const PendingStepDay({
    required this.date,
    required this.steps,
    required this.baselineKnown,
  });

  final String date;
  final int steps;
  final bool baselineKnown;

  Map<String, dynamic> toJson() => {
        'steps': steps,
        'baseline_known': baselineKnown,
      };
}

PendingStepDay? recoverPreviousPendingDay({
  required String? snapshotDate,
  required String currentDate,
  required int steps,
  required bool pending,
  required bool baselineKnown,
}) {
  if (!pending ||
      snapshotDate == null ||
      snapshotDate == currentDate ||
      !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(snapshotDate)) {
    return null;
  }
  final parsedDate = DateTime.tryParse('${snapshotDate}T00:00:00Z');
  if (parsedDate == null ||
      '${parsedDate.year.toString().padLeft(4, '0')}-'
              '${parsedDate.month.toString().padLeft(2, '0')}-'
              '${parsedDate.day.toString().padLeft(2, '0')}' !=
          snapshotDate) {
    return null;
  }
  return PendingStepDay(
    date: snapshotDate,
    steps: steps < 0 ? 0 : steps,
    baselineKnown: baselineKnown,
  );
}

bool canApplyStepDeltaAcrossDates(String? previousDate, String currentDate) =>
    previousDate == currentDate;
