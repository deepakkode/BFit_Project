import assert from 'node:assert/strict';
import test from 'node:test';
import { getApiBaseURL } from './apiConfig.mjs';

test('uses the configured PC LAN host on native devices', () => {
  assert.equal(getApiBaseURL(' http://192.168.1.4:8000/api/v1/ ', 'android'), 'http://192.168.1.4:8000/api/v1');
});

test('maps Android emulator host to localhost for web only', () => {
  assert.equal(getApiBaseURL('http://10.0.2.2:8000/api/v1', 'web'), 'http://localhost:8000/api/v1');
  assert.equal(getApiBaseURL('http://10.0.2.2:8000/api/v1', 'android'), 'http://10.0.2.2:8000/api/v1');
});

test('uses the correct platform default when no URL is configured', () => {
  assert.equal(getApiBaseURL('', 'web'), 'http://localhost:8000/api/v1');
  assert.equal(getApiBaseURL(undefined, 'android'), 'http://10.0.2.2:8000/api/v1');
});