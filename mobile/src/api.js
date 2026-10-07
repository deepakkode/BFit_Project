import axios from 'axios';
import { Platform } from 'react-native';
import { getAccessToken } from './tokenStorage';
import { getApiBaseURL } from './apiConfig.mjs';

const baseURL = getApiBaseURL(process.env.EXPO_PUBLIC_API_URL, Platform.OS);
export const API_BASE_URL = baseURL;
const api = axios.create({
  baseURL,
  timeout: 15000,
});

api.interceptors.request.use(async (config) => {
  const token = await getAccessToken();
  if (token) config.headers.Authorization = `Bearer ${token}`;
  return config;
});

export const authApi = {
  async register(payload) {
    return (await api.post('/auth/register', payload)).data;
  },
  async login(payload) {
    return (await api.post('/auth/login', payload)).data;
  },
  async profile() {
    return (await api.get('/auth/profile')).data;
  },
  async updateProfile(payload) {
    return (await api.put('/auth/profile', payload)).data;
  },
};

export const activityApi = {
  async current() {
    return (await api.get('/activity/current')).data;
  },
  async today() {
    return (await api.get('/activity/today')).data;
  },
  async history() {
    return (await api.get('/activity/history')).data;
  },
  async predict(payload) {
    return (await api.post('/activity/predict', payload)).data;
  },
};

export const stepsApi = {
  async today() {
    return (await api.get('/steps/today')).data;
  },
  async update(payload) {
    return (await api.post('/steps/update', payload)).data;
  },
  async history() {
    return (await api.get('/steps/history')).data;
  },
};

export const analyticsApi = {
  async weekly() {
    return (await api.get('/analytics/weekly')).data;
  },
  async monthly() {
    const now = new Date();
    return (await api.get('/analytics/monthly', { params: { year: now.getFullYear(), month: now.getMonth() + 1 } })).data;
  },
};

export const goalsApi = {
  async get() {
    return (await api.get('/goals')).data;
  },
  async save(payload) {
    return (await api.put('/goals', payload)).data;
  },
};