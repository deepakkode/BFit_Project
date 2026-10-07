export const STARTER_DAILY_STEP_GOAL = 6000;
export const MOTIVATIONAL_QUOTES = [
  'Momentum is built one honest step at a time.',
  'A calm routine beats a perfect one.',
  'Your next move is your strongest comeback.',
  'Small wins stack into powerful weeks.',
  'Progress feels easy when movement is part of your rhythm.',
  'Today is not about doing more — it is about moving well.',
  'Your body responds to consistency, not intensity.',
  'Keep your pace steady and your energy will rise.',
];

const MINIMUM_DAILY_STEP_GOAL = 3000;
const MAXIMUM_DAILY_STEP_GOAL = 12000;
const BASELINE_DAYS = 7;
const MINIMUM_BASELINE_DAYS = 3;

function clampDailyGoal(value) {
  return Math.max(MINIMUM_DAILY_STEP_GOAL, Math.min(MAXIMUM_DAILY_STEP_GOAL, Math.round(Number(value) || STARTER_DAILY_STEP_GOAL)));
}

function getProfileMultiplier(profile = {}) {
  const age = Number(profile.age) || 30;
  const heightCm = Number(profile.height_cm) || 170;
  const weightKg = Number(profile.weight_kg) || 70;
  const normalizedGender = String(profile.gender || '').trim().toLowerCase();

  const genderFactor = normalizedGender === 'male' ? 1.03
    : normalizedGender === 'female' ? 0.97
    : 1.0;

  const ageFactor = age < 18 ? 1.12
    : age <= 25 ? 1.08
    : age <= 45 ? 1.0
    : age <= 60 ? 0.9
    : 0.8;

  const heightMeters = Math.max(heightCm / 100, 1.2);
  const bmi = weightKg / (heightMeters * heightMeters);
  const heightFactor = Math.max(0.94, Math.min(1.06, heightCm / 170));
  const bmiFactor = bmi < 18.5 ? 0.9
    : bmi <= 25 ? 1.0
    : bmi <= 30 ? 0.95
    : 0.88;

  return genderFactor * ageFactor * heightFactor * bmiFactor;
}

export function estimateWalkingMetrics(steps, profile = {}) {
  const safeSteps = Math.max(0, Number(steps) || 0);
  const heightCm = Number(profile.height_cm) || 170;
  const weightKg = Number(profile.weight_kg) || 70;
  const metersPerStep = profile.height_cm ? heightCm * 0.00413 : 0.75;
  const distanceKm = (safeSteps * metersPerStep) / 1000;

  return {
    distanceKm: Number(distanceKm.toFixed(3)),
    caloriesKcal: Number((distanceKm * weightKg * 0.5).toFixed(1)),
  };
}

export function getDisplayActivityName(activity) {
  return activity === 'Sitting' || activity === 'Standing' ? 'Rest' : activity;
}

export function getStepGoalRecommendation(stepHistory = [], now = new Date(), profile = {}) {
  const today = now.toISOString().slice(0, 10);
  const firstDay = new Date(now);
  firstDay.setUTCDate(firstDay.getUTCDate() - (BASELINE_DAYS - 1));
  const firstDayKey = firstDay.toISOString().slice(0, 10);
  const trackedDays = stepHistory.filter((row) => (
    row.log_date >= firstDayKey
    && row.log_date <= today
    && Number(row.steps) > 0
  ));
  const averageSteps = trackedDays.length
    ? trackedDays.reduce((total, row) => total + Number(row.steps), 0) / trackedDays.length
    : 0;

  const profileMultiplier = getProfileMultiplier(profile);
  const starterTarget = clampDailyGoal(Math.round((STARTER_DAILY_STEP_GOAL * profileMultiplier) / 500) * 500);

  if (trackedDays.length < MINIMUM_BASELINE_DAYS) {
    return {
      dailyStepGoal: starterTarget,
      averageSteps: Math.round(averageSteps),
      sampleDays: trackedDays.length,
      isPersonalized: false,
    };
  }

  const gradualTarget = Math.round((averageSteps * 1.1) * profileMultiplier / 500) * 500;
  return {
    dailyStepGoal: clampDailyGoal(gradualTarget),
    averageSteps: Math.round(averageSteps),
    sampleDays: trackedDays.length,
    isPersonalized: true,
  };
}

export function getGoalSummary(dailyStepGoal = STARTER_DAILY_STEP_GOAL) {
  const safeGoal = Math.max(MINIMUM_DAILY_STEP_GOAL, Math.min(MAXIMUM_DAILY_STEP_GOAL, Math.round(Number(dailyStepGoal) || STARTER_DAILY_STEP_GOAL)));
  return {
    dailyStepGoal: safeGoal,
    daily_step_goal: safeGoal,
    weeklyRunningGoal: 3,
    weekly_running_goal: 3,
    monthlyDistanceGoal: 50,
    monthly_distance_goal: 50,
  };
}

export function getNextQuoteIndex(quotes, previousIndex, random = Math.random) {
  if (!quotes.length) return -1;
  if (quotes.length === 1) return 0;

  const candidate = Math.min(Math.floor(random() * quotes.length), quotes.length - 1);
  return candidate === previousIndex ? (candidate + 1) % quotes.length : candidate;
}

export function getActivityReadingStatus(reading, now = new Date()) {
  if (!reading?.activity) return { isStale: false, note: 'Waiting for a sensor reading' };

  const timestamp = reading.prediction_timestamp || reading.start_time;
  const ageMinutes = timestamp
    ? Math.max(0, Math.floor((now.getTime() - new Date(timestamp).getTime()) / 60000))
    : 0;
  if (ageMinutes >= 2) return { isStale: true, note: `Last detected ${ageMinutes} min ago` };

  const confidence = Number(reading.confidence_score) || 0;
  if (confidence < 0.6) return { isStale: false, note: `Low confidence · ${Math.round(confidence * 100)}%` };
  return { isStale: false, note: `${Math.round(confidence * 100)}% confidence` };
}