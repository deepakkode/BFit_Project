export function getApiBaseURL(configuredBaseURL, platform) {
  const configured = typeof configuredBaseURL === 'string'
    ? configuredBaseURL.trim().replace(/\/+$/, '')
    : '';
  const defaultBaseURL = platform === 'web'
    ? 'http://localhost:8000/api/v1'
    : 'http://10.0.2.2:8000/api/v1';

  if (platform === 'web') {
    return configured.replace('10.0.2.2', 'localhost') || defaultBaseURL;
  }
  return configured || defaultBaseURL;
}