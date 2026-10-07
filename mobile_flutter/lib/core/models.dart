typedef JsonMap = Map<String, dynamic>;

int asInt(Object? value, [int fallback = 0]) =>
    value is num ? value.round() : int.tryParse('$value') ?? fallback;

double asDouble(Object? value, [double fallback = 0]) =>
    value is num ? value.toDouble() : double.tryParse('$value') ?? fallback;

String asString(Object? value, [String fallback = '']) =>
    value is String ? value : fallback;

DateTime? asDate(Object? value) {
  if (value is! String) return null;
  final calendarDate = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
  if (calendarDate != null) {
    return DateTime.utc(
      int.parse(calendarDate[1]!),
      int.parse(calendarDate[2]!),
      int.parse(calendarDate[3]!),
    );
  }
  return DateTime.tryParse(value);
}

class UserProfile {
  const UserProfile({
    required this.id,
    required this.name,
    required this.email,
    this.age,
    this.heightCm,
    this.weightKg,
    this.gender,
    this.timezone = 'UTC',
  });

  final String id;
  final String name;
  final String email;
  final int? age;
  final double? heightCm;
  final double? weightKg;
  final String? gender;
  final String timezone;

  bool get isComplete => age != null && heightCm != null && weightKg != null;

  factory UserProfile.fromJson(JsonMap json) => UserProfile(
        id: asString(json['id']),
        name: asString(json['name'], 'Friend'),
        email: asString(json['email']),
        age: json['age'] == null ? null : asInt(json['age']),
        heightCm: json['height_cm'] == null ? null : asDouble(json['height_cm']),
        weightKg: json['weight_kg'] == null ? null : asDouble(json['weight_kg']),
        gender: json['gender'] as String?,
        timezone: asString(json['timezone'], 'UTC'),
      );
}

class ActivityReading {
  const ActivityReading({
    this.activity,
    this.confidence,
    this.startTime,
    this.predictionTime,
    this.durationSeconds = 0,
  });

  final String? activity;
  final double? confidence;
  final DateTime? startTime;
  final DateTime? predictionTime;
  final int durationSeconds;

  factory ActivityReading.fromJson(JsonMap json) => ActivityReading(
        activity: json['activity'] as String?,
        confidence: json['confidence_score'] == null
            ? null
            : asDouble(json['confidence_score']),
        startTime: asDate(json['start_time']),
        predictionTime: asDate(json['prediction_timestamp']),
        durationSeconds: asInt(json['duration_seconds']),
      );
}

class ActivitySession {
  const ActivitySession({
    required this.activity,
    required this.confidence,
    required this.startTime,
    this.endTime,
    required this.durationSeconds,
  });

  final String activity;
  final double confidence;
  final DateTime startTime;
  final DateTime? endTime;
  final int durationSeconds;

  factory ActivitySession.fromJson(JsonMap json) => ActivitySession(
        activity: asString(json['activity'], 'Rest'),
        confidence: asDouble(json['confidence_score']),
        startTime: asDate(json['start_time']) ?? DateTime.fromMillisecondsSinceEpoch(0),
        endTime: asDate(json['end_time']),
        durationSeconds: asInt(json['duration_seconds']),
      );
}

class StepDay {
  const StepDay({
    required this.logDate,
    required this.steps,
    this.distanceKm = 0,
    this.calories = 0,
  });

  final DateTime logDate;
  final int steps;
  final double distanceKm;
  final double calories;

  factory StepDay.fromJson(JsonMap json) => StepDay(
        logDate: asDate(json['log_date']) ?? DateTime.now().toUtc(),
        steps: asInt(json['steps']),
        distanceKm: asDouble(json['distance_km']),
        calories: asDouble(json['calories_burned']),
      );
}

class DailyAggregate {
  const DailyAggregate({
    this.walkingMinutes = 0,
    this.runningMinutes = 0,
    this.sittingMinutes = 0,
    this.standingMinutes = 0,
    this.totalSteps = 0,
    this.totalDistance = 0,
    this.totalCalories = 0,
  });

  final int walkingMinutes;
  final int runningMinutes;
  final int sittingMinutes;
  final int standingMinutes;
  final int totalSteps;
  final double totalDistance;
  final double totalCalories;

  int get restMinutes => sittingMinutes + standingMinutes;

  factory DailyAggregate.fromJson(JsonMap json) => DailyAggregate(
        walkingMinutes: asInt(json['walking_minutes']),
        runningMinutes: asInt(json['running_minutes']),
        sittingMinutes: asInt(json['sitting_minutes']),
        standingMinutes: asInt(json['standing_minutes']),
        totalSteps: asInt(json['total_steps']),
        totalDistance: asDouble(json['total_distance']),
        totalCalories: asDouble(json['total_calories']),
      );
}

class GoalSettings {
  const GoalSettings({
    this.dailySteps = 6000,
    this.weeklyRuns = 3,
    this.monthlyDistance = 50,
  });

  final int dailySteps;
  final int weeklyRuns;
  final double monthlyDistance;

  factory GoalSettings.fromJson(JsonMap json) => GoalSettings(
        dailySteps: asInt(json['daily_step_goal'], 6000),
        weeklyRuns: asInt(json['weekly_running_goal'], 3),
        monthlyDistance: asDouble(json['monthly_distance_goal'], 50),
      );

  JsonMap toJson() => {
        'daily_step_goal': dailySteps,
        'weekly_running_goal': weeklyRuns,
        'monthly_distance_goal': monthlyDistance,
      };
}
