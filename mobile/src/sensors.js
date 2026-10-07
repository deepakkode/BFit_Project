import { useEffect, useState } from 'react';
import { Platform } from 'react-native';
import { Accelerometer, Pedometer } from 'expo-sensors';
import * as SecureStore from 'expo-secure-store';
import { useQueryClient } from '@tanstack/react-query';
import { activityApi, stepsApi } from './api';
import { estimateWalkingMetrics } from './wellnessMetrics.mjs';

const WINDOW_LENGTH = 200;
const SAMPLE_INTERVAL_MS = 50;
const GRAVITY = 9.80665;
const STEP_CACHE_KEY = 'bfit.localSteps';

function utcDateString(date = new Date()) {
  return date.toISOString().slice(0, 10);
}

function wait(milliseconds) {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
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

        let logDate = utcDateString();
        let dailySteps = 0;
        let serverBaselineLoaded = false;
        const cached = await SecureStore.getItemAsync(STEP_CACHE_KEY);
        if (cached) {
          try {
            const snapshot = JSON.parse(cached);
            if (snapshot.logDate === logDate && Number.isFinite(snapshot.steps)) {
              dailySteps = Math.max(0, snapshot.steps);
            }
          } catch {
            await SecureStore.deleteItemAsync(STEP_CACHE_KEY);
          }
        }
        try {
          const existing = await stepsApi.today();
          dailySteps = Math.max(dailySteps, Number(existing.steps) || 0);
          serverBaselineLoaded = true;
        } catch {
          setPedometerStatus('Step counter active. Syncing with the server when available.');
        }

        if (!active) return;
        if (Platform.OS === 'ios') {
          const today = new Date();
          const midnight = new Date(Date.UTC(today.getUTCFullYear(), today.getUTCMonth(), today.getUTCDate()));
          try {
            const result = await Pedometer.getStepCountAsync(midnight, today);
            dailySteps = Math.max(dailySteps, result.steps);
            if (serverBaselineLoaded && dailySteps > 0) {
              const metrics = estimateWalkingMetrics(dailySteps, user);
              await stepsApi.update({
                log_date: logDate,
                steps: dailySteps,
                distance_km: metrics.distanceKm,
                calories_burned: metrics.caloriesKcal,
              });
            }
          } catch {
            // Historical totals are optional; continue counting live steps.
          }
        }
        await SecureStore.setItemAsync(STEP_CACHE_KEY, JSON.stringify({ logDate, steps: dailySteps }));
        queryClient.setQueryData(['steps', 'today'], (existing) => ({
          ...(existing || {}),
          log_date: logDate,
          steps: dailySteps,
        }));
        let lastWatchTotal = 0;
        let uploadQueue = Promise.resolve();
        pedometerSubscription = Pedometer.watchStepCount(({ steps }) => {
          const delta = Math.max(0, steps - lastWatchTotal);
          lastWatchTotal = Math.max(lastWatchTotal, steps);
          if (delta === 0) return;
          uploadQueue = uploadQueue.then(async () => {
            if (!active) return;
            const currentDate = utcDateString();
            if (currentDate !== logDate) {
              logDate = currentDate;
              dailySteps = 0;
              serverBaselineLoaded = false;
            }
            if (!serverBaselineLoaded) {
              try {
                const existing = await stepsApi.today();
                dailySteps = Math.max(dailySteps, Number(existing.steps) || 0);
                serverBaselineLoaded = true;
              } catch {
                setPedometerStatus('Step counter active. Syncing with the server when available.');
                return;
              }
            }
            dailySteps += delta;
            const metrics = estimateWalkingMetrics(dailySteps, user);
            await SecureStore.setItemAsync(STEP_CACHE_KEY, JSON.stringify({ logDate, steps: dailySteps }));
            queryClient.setQueryData(['steps', 'today'], (existing) => ({
              ...(existing || {}),
              log_date: logDate,
              steps: dailySteps,
              distance_km: metrics.distanceKm,
              calories_burned: metrics.caloriesKcal,
            }));
            let lastError;
            for (let attempt = 0; attempt < 3; attempt += 1) {
              try {
                await stepsApi.update({
                  log_date: logDate,
                  steps: dailySteps,
                  distance_km: metrics.distanceKm,
                  calories_burned: metrics.caloriesKcal,
                });
                setPedometerStatus('Step counter active');
                queryClient.invalidateQueries({ queryKey: ['steps'] });
                return;
              } catch (error) {
                lastError = error;
                if (attempt < 2) await wait(500 * (attempt + 1));
              }
            }
            const status = lastError?.response?.status;
            setPedometerStatus(status === 401
              ? 'Steps counted on this phone, but sign in again to sync.'
              : 'Steps counted on this phone; server sync will retry as you walk.');
          }).catch((error) => {
            setPedometerStatus(error.message || 'Step counter could not save today’s total.');
          });
        });
        setPedometerStatus('Step counter active. Walk a few steps to sync.');
      } catch {
        if (active) setPedometerStatus('Step counter could not start. Check activity permission and device sensor support.');
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