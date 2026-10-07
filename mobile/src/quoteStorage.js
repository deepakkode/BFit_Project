import { Platform } from 'react-native';
import * as SecureStore from 'expo-secure-store';

const QUOTE_INDEX_KEY = 'bfit.lastQuoteIndex';

export async function getLastQuoteIndex() {
  try {
    const saved = Platform.OS === 'web'
      ? globalThis.localStorage?.getItem(QUOTE_INDEX_KEY)
      : await SecureStore.getItemAsync(QUOTE_INDEX_KEY);
    const index = Number(saved);
    return Number.isInteger(index) ? index : -1;
  } catch {
    return -1;
  }
}

export async function setLastQuoteIndex(index) {
  try {
    if (Platform.OS === 'web') {
      globalThis.localStorage?.setItem(QUOTE_INDEX_KEY, String(index));
      return;
    }
    await SecureStore.setItemAsync(QUOTE_INDEX_KEY, String(index));
  } catch {
    return undefined;
  }
}