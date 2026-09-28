import axios, { AxiosError, type AxiosInstance, type InternalAxiosRequestConfig } from 'axios';

import { API } from './config';
import { session } from './session';

const identityRefresher = axios.create({ baseURL: API.identity, timeout: 15000 });
let refreshPromise: Promise<boolean> | null = null;

async function tryRefresh(): Promise<boolean> {
  if (refreshPromise) return refreshPromise;
  const refresh = session.refreshToken();
  if (!refresh) return false;
  refreshPromise = (async () => {
    try {
      const { data } = await identityRefresher.post('/api/v1/auth/refresh', { refreshToken: refresh });
      const user = {
        userId: data.user.userId,
        email: data.user.email,
        displayName: data.user.displayName ?? '',
        roles: (data.user.roles ?? []) as string[],
      };
      session.save(data.accessToken, data.refreshToken, user);
      return true;
    } catch {
      return false;
    } finally {
      refreshPromise = null;
    }
  })();
  return refreshPromise;
}

export function createClient(baseURL: string): AxiosInstance {
  const client = axios.create({ baseURL, timeout: 15000 });
  client.interceptors.request.use((config) => {
    const token = session.accessToken();
    if (token) config.headers.Authorization = `Bearer ${token}`;
    return config;
  });
  client.interceptors.response.use(
    (res) => res,
    async (err: AxiosError) => {
      const original = err.config as (InternalAxiosRequestConfig & { _retried?: boolean }) | undefined;
      if (!original || ![401, 403].includes(err.response?.status ?? 0)) return Promise.reject(err);
      if (original.url?.includes('/api/v1/auth/')) return Promise.reject(err);
      if (original._retried) return Promise.reject(err);
      const refreshed = await tryRefresh();
      if (refreshed) {
        original._retried = true;
        const token = session.accessToken();
        if (token) original.headers.Authorization = `Bearer ${token}`;
        return client(original);
      }
      if (typeof window !== 'undefined') {
        session.clear();
        if (window.location.pathname !== '/login') {
          window.location.href = '/login';
        }
      }
      return Promise.reject(err);
    }
  );
  return client;
}
