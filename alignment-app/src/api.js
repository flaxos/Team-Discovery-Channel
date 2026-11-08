const STORAGE_KEY = 'tdc-alignment-access-token';
export const getAccessToken = () => sessionStorage.getItem(STORAGE_KEY) || '';
export const setAccessToken = token => token ? sessionStorage.setItem(STORAGE_KEY, token) : sessionStorage.removeItem(STORAGE_KEY);

export async function apiFetch(url, options = {}, token = getAccessToken()) {
  if (!url.startsWith('/api/')) throw new Error('API requests must use the local API path.');
  const headers = new Headers(options.headers);
  if (token) headers.set('Authorization', `Bearer ${token}`);
  if (options.method && options.method !== 'GET') headers.set('Content-Type', 'application/json');
  const response = await fetch(url, { ...options, headers, credentials: 'omit' });
  if (!response.ok) {
    const data = await response.json().catch(() => ({}));
    const error = new Error(data.error || `Request failed (${response.status})`);
    error.status = response.status;
    window.dispatchEvent(new CustomEvent('alignment-api-error', { detail: { message: error.message, status: error.status } }));
    throw error;
  }
  return response;
}
