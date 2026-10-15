const ACCESS = 'bhook.admin.accessToken';
const REFRESH = 'bhook.admin.refreshToken';
const USER = 'bhook.admin.user';

export type AdminUser = {
  userId: string;
  email: string;
  displayName: string;
  roles: string[];
};

export const session = {
  save(access: string, refresh: string, user: AdminUser) {
    if (typeof window === 'undefined') return;
    localStorage.setItem(ACCESS, access);
    localStorage.setItem(REFRESH, refresh);
    localStorage.setItem(USER, JSON.stringify(user));
  },
  clear() {
    if (typeof window === 'undefined') return;
    localStorage.removeItem(ACCESS);
    localStorage.removeItem(REFRESH);
    localStorage.removeItem(USER);
  },
  accessToken(): string | null {
    if (typeof window === 'undefined') return null;
    return localStorage.getItem(ACCESS);
  },
  refreshToken(): string | null {
    if (typeof window === 'undefined') return null;
    return localStorage.getItem(REFRESH);
  },
  user(): AdminUser | null {
    if (typeof window === 'undefined') return null;
    const raw = localStorage.getItem(USER);
    return raw ? (JSON.parse(raw) as AdminUser) : null;
  },
};

export function hasPlatformRole(user: AdminUser | null): boolean {
  if (!user) return false;
  return user.roles.some((r) => r.startsWith('PLATFORM_'));
}
