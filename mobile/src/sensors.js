import { useEffect, useState } from 'react';
import { Platform } from 'react-native';
import { Accelerometer, Pedometer } from 'expo-sensors';
import { useQueryClient } from '@tanstack/react-query';
import { activityApi, stepsApi } from './api';
import { estimateWalkingMetrics } from './wellnessMetrics.mjs';

const WINDOW_LENGTH = 200;
const SAMPLE_INTERVAL_MS = 50;
const GRAVITY = 9.80665;

function localDateString(date) {
  return date.toISOString().slice(0, 10);
}

export function useActivitySensors(enabled, user, permissionRefreshToken = 0) {
  const queryClient = useQueryClient();
  const [pedometerStatus, setPedometerStatus] = useState('Checking step counter…');

  useEffect(() => {
    if (!enabled) {
      setPedometerStatus('Step counter paused');
      return undefined;
    }

    let active = true;
    let samples = [];
    const windowStart = () => new Date().toISOString();
    let startedAt = windowStart();

    Accelerometer.setUpdateInterval(SAMPLE_INTERVAL_MS);
    const sensorSubscription = Accelerometer.addListener((value) => {
      if (!active) return;
      samples.push({
        timestamp: new Date().toISOString(),
        acc_x: value.x * GRAVITY,
        acc_y: value.y * GRAVITY,
        acc_z: value.z * GRAVITY,
      });
      if (samples.length >= WINDOW_LENGTH) {
        const windowSamples = samples;
        const windowStartValue = startedAt;
        samples = [];
        startedAt = windowStart();
        activityApi.predict({ window_start: windowStartValue, sample_rate_hz: 20, samples: windowSamples })
          .then(() => queryClient.invalidateQueries({ queryKey: ['activity'] }))
          .catch(() => {});
      }
    });

    let pedometerSubscription;
    let lastWatchTotal = 0;
    const uploadDailyTotals = async (stepsToday) => {
      if (!active) return;
      const today = new Date();
      try {
        const metrics = estimateWalkingMetrics(stepsToday, user);
        await stepsApi.update({
          log_date: localDateString(today),
          steps: stepsToday,
          distance_km: metrics.distanceKm,
          calories_burned: metrics.caloriesKcal,
        });
        queryClient.invalidateQueries({ queryKey: ['steps'] });
      } catch {
        setPedometerStatus('Steps detected, but saving failed. Check API connection.');
      }
    };

    const startPedometer = async () => {
      try {
        const available = await Pedometer.isAvailableAsync();
        if (!active) return;
        if (!available) {
          setPedometerStatus('This device does not provide a step counter.');
          return;
        }

        const permission = await Pedometer.requestPermissionsAsync();
        if (!active) return;
        if (!permission.granted) {
          setPedometerStatus('Allow physical activity access to count steps.');
          return;
        }

        if (Platform.OS === 'ios') {
          const today = new Date();
          const midnight = new Date(Date.UTC(today.getUTCFullYear(), today.getUTCMonth(), today.getUTCDate()));
          try {
            const result = await Pedometer.getStepCountAsync(midnight, today);
            const existing = await stepsApi.today();
            await uploadDailyTotals(Math.max(existing.steps || 0, result.steps));
          } catch {
            // Historical step totals are optional; continue with live updates.
          }
        }

        if (!active) return;
        pedometerSubscription = Pedometer.watchStepCount(({ steps }) => {
          const delta = Math.max(0, steps - lastWatchTotal);
          lastWatchTotal = Math.max(lastWatchTotal, steps);
          if (delta === 0) return;
          setPedometerStatus('Step counter active');
          stepsApi.today()
            .then((existing) => uploadDailyTotals((existing.steps || 0) + delta))
            .catch(() => setPedometerStatus('Steps detected, but could not read today’s total.'));
        });
        setPedometerStatus('Step counter active. Walk a few steps to sync.');
      } catch {
        if (active) setPedometerStatus('Step counter could not start. Check activity permission.');
      }
    };

    startPedometer();

    return () => {
      active = false;
      sensorSubscription.remove();
      pedometerSubscription?.remove();
    };
  }, [enabled, permissionRefreshToken, queryClient, user?.height_cm, user?.weight_kg]);

  return pedometerStatus;
}