import { Platform } from 'react-native';
import { isRunningInExpoGo } from 'expo';
import * as SecureStore from 'expo-secure-store';

const ENABLED_KEY = 'bfit.dailyMovementReminderEnabled';
const HOUR_KEY = 'bfit.dailyMovementReminderHour';
const MINUTE_KEY = 'bfit.dailyMovementReminderMinute';
const IDENTIFIER_KEY = 'bfit.dailyMovementReminderIdentifier';

async function readValue(key) {
  if (Platform.OS === 'web') return globalThis.localStorage?.getItem(key) ?? null;
  return SecureStore.getItemAsync(key);
}

async function writeValue(key, value) {
  if (Platform.OS === 'web') {
    globalThis.localStorage?.setItem(key, value);
    return;
  }
  await SecureStore.setItemAsync(key, value);
}

async function getNotifications() {
  if (Platform.OS === 'web') throw new Error('Daily reminders are available in the mobile app.');
  if (Platform.OS === 'android' && isRunningInExpoGo()) {
    throw new Error('Android reminders need an installed BFit development build; Expo Go cannot load the notifications module.');
  }

  const Notifications = await import('expo-notifications');
  Notifications.setNotificationHandler({
    handleNotification: async () => ({
      shouldShowBanner: true,
      shouldShowList: true,
      shouldPlaySound: false,
      shouldSetBadge: false,
    }),
  });
  return Notifications;
}

export async function configureMovementNotifications() {
  await getNotifications();
}

export async function getMovementReminderSettings() {
  try {
    const [enabled, hour, minute] = await Promise.all([
      readValue(ENABLED_KEY),
      readValue(HOUR_KEY),
      readValue(MINUTE_KEY),
    ]);
    return {
      enabled: enabled === 'true',
      hour: hour !== null && Number.isInteger(Number(hour)) ? Number(hour) : 19,
      minute: minute !== null && Number.isInteger(Number(minute)) ? Number(minute) : 0,
    };
  } catch {
    return { enabled: false, hour: 19, minute: 0 };
  }
}

export async function scheduleMovementReminder(hour, minute) {
  if (!Number.isInteger(hour) || hour < 0 || hour > 23 || !Number.isInteger(minute) || minute < 0 || minute > 59) {
    throw new Error('Enter a valid reminder time.');
  }

  const Notifications = await getNotifications();
  if (Platform.OS === 'android') {
    await Notifications.setNotificationChannelAsync('daily-movement', {
      name: 'Daily movement reminder',
      importance: Notifications.AndroidImportance.DEFAULT,
      sound: null,
    });
  }

  let permission = await Notifications.getPermissionsAsync();
  if (!permission.granted) permission = await Notifications.requestPermissionsAsync();
  if (!permission.granted) throw new Error('Allow notifications in system settings to use movement reminders.');

  const existingIdentifier = await readValue(IDENTIFIER_KEY);
  const identifier = await Notifications.scheduleNotificationAsync({
    content: {
      title: 'A little movement goes a long way',
      body: 'Take a short walk when it fits your day.',
      sound: false,
    },
    trigger: {
      type: Notifications.SchedulableTriggerInputTypes.DAILY,
      hour,
      minute,
      channelId: 'daily-movement',
    },
  });

  try {
    await Promise.all([
      writeValue(ENABLED_KEY, 'true'),
      writeValue(HOUR_KEY, String(hour)),
      writeValue(MINUTE_KEY, String(minute)),
      writeValue(IDENTIFIER_KEY, identifier),
    ]);
  } catch (error) {
    await Notifications.cancelScheduledNotificationAsync(identifier);
    throw error;
  }

  let previousReminderMayRemain = false;
  if (existingIdentifier && existingIdentifier !== identifier) {
    try {
      await Notifications.cancelScheduledNotificationAsync(existingIdentifier);
    } catch {
      previousReminderMayRemain = true;
    }
  }
  return { previousReminderMayRemain };
}

export async function cancelMovementReminder() {
  const Notifications = await getNotifications();
  const identifier = await readValue(IDENTIFIER_KEY);
  if (identifier) {
    try {
      await Notifications.cancelScheduledNotificationAsync(identifier);
    } catch {
      // The OS may have already removed the scheduled reminder.
    }
  }
  await writeValue(ENABLED_KEY, 'false');
  await writeValue(IDENTIFIER_KEY, '');
}