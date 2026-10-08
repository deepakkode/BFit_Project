import 'models.dart';

const int starterDailyStepGoal = 6000;
const List<String> motivationalQuotes = [
  'Every step is a vote for the stronger, steadier you.',
  'A short walk still moves your day forward.',
  'Consistency builds fitness one ordinary day at a time.',
  'Your pace is yours. Keep moving in a way that feels good.',
  'Small walks add up to meaningful progress.',
  'Recovery is part of training. Give your body room to reset.',
  'One more block, one more lap, one more reason to feel proud.',
  'A little movement can change the rhythm of your day.',
  'Build a routine you can return to, not a streak you fear breaking.',
  'Strong habits are made of manageable steps.',
  'Take the stairs when it suits you; every bit of movement counts.',
  'Today’s effort does not need to look like anyone else’s.',
  'A steady walk is a great place to start.',
  'Celebrate showing up, not just hitting a number.',
  'Your next walk can be a fresh start.',
  'Keep your goals kind enough to keep.',
  'Movement is progress, even when it is gentle.',
  'A few minutes outside can be a win for your routine.',
  'Let your fitness grow at a pace you can sustain.',
  'You do not have to go fast to keep moving forward.',
  'Make room for movement in the day you actually have.',
  'A rest day supports the walks still to come.',
  'Notice the progress that does not fit on a chart.',
  'A walk after a busy day is still time well spent.',
  'Keep going gently; reliable habits beat all-or-nothing plans.',
  'Your health journey is built one choice at a time.',
  'Find a comfortable rhythm and let it carry you.',
  'Every active minute is a moment invested in yourself.',
  'Some days are for pushing; some are for simply showing up.',
  'Progress is returning to movement, again and again.',
  'Walk for the feeling, not only for the count.',
  'A realistic goal today makes tomorrow easier to begin.',
  'Give yourself credit for the steps you took today.',
  'Movement can be simple: stand, stretch, and take a few steps.',
  'The best routine is one that fits your life.',
  'Be patient with your body; fitness grows over time.',
  'A comfortable walk is a strong choice for today.',
  'Little by little is still forward.',
  'Take a breath, find your stride, and continue.',
  'Build strength through the habit of coming back.',
];

class WalkingMetrics {
  const WalkingMetrics(this.distanceKm, this.caloriesKcal);
  final double distanceKm;
  final double caloriesKcal;
}

class GoalRecommendation {
  const GoalRecommendation({
    required this.dailyStepGoal,
    required this.averageSteps,
    required this.sampleDays,
    required this.isPersonalized,
  });
  final int dailyStepGoal;
  final int averageSteps;
  final int sampleDays;
  final bool isPersonalized;
}

GoalSettings applyDailyGoalRecommendation({
  required GoalSettings existing,
  required List<StepDay> history,
  required DateTime now,
  required UserProfile profile,
}) {
  final recommendation = recommendStepGoal(history, now, profile);
  return GoalSettings(
    dailySteps: recommendation.dailyStepGoal,
    weeklyRuns: existing.weeklyRuns,
    monthlyDistance: existing.monthlyDistance,
  );
}

class ActivityFreshness {
  const ActivityFreshness(this.isStale, this.note);
  final bool isStale;
  final String note;
}

String displayActivityName(String? activity) =>
    activity == 'Sitting' || activity == 'Standing'
        ? 'Rest'
        : activity ?? 'Rest';

WalkingMetrics estimateWalkingMetrics(int steps, UserProfile? profile) {
  final safeSteps = steps < 0 ? 0 : steps;
  final height = profile?.heightCm ?? 170;
  final weight = profile?.weightKg ?? 70;
  final metersPerStep = profile?.heightCm == null ? 0.75 : height * 0.00413;
  final distance = (safeSteps * metersPerStep / 1000).toDouble();
  return WalkingMetrics(
    double.parse(distance.toStringAsFixed(3)),
    double.parse((distance * weight * 0.5).toStringAsFixed(1)),
  );
}

double _profileMultiplier(UserProfile? profile) {
  final age = profile?.age ?? 30;
  final height = profile?.heightCm ?? 170;
  final weight = profile?.weightKg ?? 70;
  final gender = (profile?.gender ?? '').trim().toLowerCase();
  final genderFactor = gender == 'male'
      ? 1.03
      : gender == 'female'
          ? 0.97
          : 1.0;
  final ageFactor = age < 18
      ? 1.12
      : age <= 25
          ? 1.08
          : age <= 45
              ? 1.0
              : age <= 60
                  ? 0.9
                  : 0.8;
  final heightMeters = (height / 100).clamp(1.2, double.infinity);
  final bmi = weight / (heightMeters * heightMeters);
  final heightFactor = (height / 170).clamp(0.94, 1.06);
  final bmiFactor = bmi < 18.5
      ? 0.9
      : bmi <= 25
          ? 1.0
          : bmi <= 30
              ? 0.95
              : 0.88;
  return (genderFactor * ageFactor * heightFactor * bmiFactor).toDouble();
}

int _clampGoal(num value) => value.round().clamp(3000, 12000).toInt();

int _roundGoal(num value) => (value / 100).round() * 100;

GoalRecommendation recommendStepGoal(
  List<StepDay> history,
  DateTime now,
  UserProfile? profile,
) {
  final today = DateTime.utc(now.year, now.month, now.day);
  final firstDay = today.subtract(const Duration(days: 6));
  final days = history.where((day) {
    final date =
        DateTime.utc(day.logDate.year, day.logDate.month, day.logDate.day);
    return !date.isBefore(firstDay) && !date.isAfter(today) && day.steps > 0;
  }).toList();
  final average = days.isEmpty
      ? 0
      : days.fold<int>(0, (sum, day) => sum + day.steps) / days.length;
  final multiplier = _profileMultiplier(profile);
  final starter = _clampGoal(_roundGoal(starterDailyStepGoal * multiplier));
  final personalized = days.length >= 3;
  final goal = personalized
      ? _clampGoal(_roundGoal(average * 1.1 * multiplier))
      : starter;
  return GoalRecommendation(
    dailyStepGoal: goal,
    averageSteps: average.round(),
    sampleDays: days.length,
    isPersonalized: personalized,
  );
}

ActivityFreshness activityFreshness(ActivityReading reading, DateTime now) {
  if (reading.activity == null) {
    return const ActivityFreshness(false, 'Waiting for a sensor reading');
  }
  final timestamp = reading.predictionTime ?? reading.startTime;
  final age = timestamp == null
      ? 0
      : now.difference(timestamp).inMinutes.clamp(0, 100000);
  if (age >= 2) return ActivityFreshness(true, 'Last detected $age min ago');
  final confidence = reading.confidence ?? 0;
  if (confidence < 0.6) {
    return ActivityFreshness(
        false, 'Low confidence · ${(confidence * 100).round()}%');
  }
  return ActivityFreshness(false, '${(confidence * 100).round()}% confidence');
}

String quoteForDate(DateTime date) {
  final dayNumber = DateTime.utc(date.year, date.month, date.day)
          .difference(DateTime.utc(2024, 1, 1))
          .inDays
          .abs() %
      motivationalQuotes.length;
  return motivationalQuotes[dayNumber];
}
