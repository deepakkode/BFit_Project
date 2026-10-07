import assert from 'node:assert/strict';
import test from 'node:test';
import {
  estimateWalkingMetrics,
  getActivityReadingStatus,
  getDisplayActivityName,
  getGoalSummary,
  getNextQuoteIndex,
  getStepGoalRecommendation,
  STARTER_DAILY_STEP_GOAL,
} from './wellnessMetrics.mjs';

test('uses a starter target until there are three tracked days', () => {
  const recommendation = getStepGoalRecommendation([
    { log_date: '2026-10-05', steps: 4000 },
    { log_date: '2026-10-06', steps: 6000 },
  ], new Date('2026-10-06T12:00:00Z'));

  assert.equal(recommendation.dailyStepGoal, STARTER_DAILY_STEP_GOAL);
  assert.equal(recommendation.sampleDays, 2);
  assert.equal(recommendation.isPersonalized, false);
});

test('suggests a gradual target from the last seven tracked days', () => {
  const recommendation = getStepGoalRecommendation([
    { log_date: '2026-09-29', steps: 10000 },
    { log_date: '2026-10-01', steps: 5000 },
    { log_date: '2026-10-02', steps: 7000 },
    { log_date: '2026-10-03', steps: 5000 },
    { log_date: '2026-10-06', steps: 6000 },
    { log_date: '2026-10-06', steps: 20000 },
    { log_date: '2026-10-07', steps: 30000 },
  ], new Date('2026-10-06T12:00:00Z'));

  assert.equal(recommendation.averageSteps, 8600);
  assert.equal(recommendation.dailyStepGoal, 9500);
  assert.equal(recommendation.sampleDays, 5);
  assert.equal(recommendation.isPersonalized, true);
});

test('clamps a personalized recommendation to the supported goal range', () => {
  const history = [1, 2, 3].map((day) => ({ log_date: `2026-10-0${day}`, steps: 50000 }));
  assert.equal(getStepGoalRecommendation(history, new Date('2026-10-06T12:00:00Z')).dailyStepGoal, 12000);
});

test('personalizes starter recommendations from age, height, weight, and gender', () => {
  const history = [];
  const baseline = getStepGoalRecommendation(history, new Date('2026-10-06T12:00:00Z'), {
    age: 35, height_cm: 170, weight_kg: 70, gender: 'Female',
  });
  const profileAdjusted = getStepGoalRecommendation(history, new Date('2026-10-06T12:00:00Z'), {
    age: 65, height_cm: 150, weight_kg: 90, gender: 'Male',
  });

  assert.notEqual(profileAdjusted.dailyStepGoal, baseline.dailyStepGoal);
});

test('calculates consistent walking distance and approximate calories', () => {
  assert.deepEqual(estimateWalkingMetrics(10000, { height_cm: 170, weight_kg: 70 }), {
    distanceKm: 7.021,
    caloriesKcal: 245.7,
  });
  assert.deepEqual(estimateWalkingMetrics(-100, {}), { distanceKm: 0, caloriesKcal: 0 });
});

test('goal summary uses the requested daily recommendation and stable secondary defaults', () => {
  assert.deepEqual(getGoalSummary(7250), {
    dailyStepGoal: 7250,
    daily_step_goal: 7250,
    weeklyRunningGoal: 3,
    weekly_running_goal: 3,
    monthlyDistanceGoal: 50,
    monthly_distance_goal: 50,
  });
});

test('chooses a different quote for consecutive app sessions', () => {
  assert.equal(getNextQuoteIndex(['a', 'b', 'c'], 1, () => 0.5), 2);
  assert.equal(getNextQuoteIndex(['a'], 0, () => 0), 0);
  assert.equal(getNextQuoteIndex([], -1), -1);
});

test('marks low-confidence and stale activity readings clearly', () => {
  const now = new Date('2026-10-06T12:00:00Z');
  assert.deepEqual(getActivityReadingStatus({
    activity: 'Walking', confidence_score: 0.42, prediction_timestamp: '2026-10-06T11:59:30Z',
  }, now), { isStale: false, note: 'Low confidence · 42%' });
  assert.deepEqual(getActivityReadingStatus({
    activity: 'Standing', confidence_score: 0.95, prediction_timestamp: '2026-10-06T11:57:00Z',
  }, now), { isStale: true, note: 'Last detected 3 min ago' });
});

test('groups sitting and standing under the user-facing Rest label', () => {
  assert.equal(getDisplayActivityName('Sitting'), 'Rest');
  assert.equal(getDisplayActivityName('Standing'), 'Rest');
  assert.equal(getDisplayActivityName('Walking'), 'Walking');
  assert.equal(getDisplayActivityName('Running'), 'Running');
});