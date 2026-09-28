'use client';

import Link from 'next/link';
import type { Route } from 'next';
import { useRouter, usePathname } from 'next/navigation';
import { useEffect, useState, type ReactNode } from 'react';

import { session, type AdminUser } from '@/lib/session';

type NavItem = { href: Route; label: string; icon: string };
type NavGroup = { label: string; items: NavItem[] };

const NAV: NavGroup[] = [
  {
    label: 'Overview',
    items: [
      { href: '/dashboard', label: 'Dashboard', icon: '◉' },
      { href: '/orders', label: 'Orders', icon: '▤' },
    ],
  },
  {
    label: 'Network',
    items: [
      { href: '/campuses', label: 'Campuses', icon: '▦' },
      { href: '/vendors', label: 'Vendors', icon: '◈' },
      { href: '/staff', label: 'Delivery staff', icon: '⇄' },
    ],
  },
  {
    label: 'People',
    items: [{ href: '/verifications', label: 'Verifications', icon: '✓' }],
  },
  {
    label: 'Operations',
    items: [
      { href: '/finance', label: 'Finance', icon: '₹' },
      { href: '/tickets', label: 'Support', icon: '✉' },
      { href: '/audit', label: 'Audit log', icon: '≡' },
    ],
  },
];

const LABELS: Record<string, string> = Object.fromEntries(
  NAV.flatMap((g) => g.items).map((i) => [i.href, i.label])
);

export default function AdminLayout({ children }: { children: ReactNode }) {
  const router = useRouter();
  const pathname = usePathname();
  const [user, setUser] = useState<AdminUser | null>(null);
  const [ready, setReady] = useState(false);

  useEffect(() => {
    const u = session.user();
    if (!u || !session.accessToken()) {
      router.replace('/login');
      return;
    }
    setUser(u);
    setReady(true);
  }, [router]);

  if (!ready) return null;

  const initials = (user?.displayName || user?.email || 'A')
    .split(/[\s@.]/)
    .filter(Boolean)
    .slice(0, 2)
    .map((s) => s[0]!.toUpperCase())
    .join('');

  const current = LABELS[pathname ?? ''] ?? 'Console';
  const primaryRole = (user?.roles ?? []).find((r) => r.startsWith('PLATFORM_')) ?? (user?.roles ?? [])[0] ?? '—';

  return (
    <div className="admin-shell">
      <div className="admin-brand">
        <div className="admin-brand__logo">B</div>
        <div>
          <div className="admin-brand__name">Bhook</div>
          <div className="admin-brand__sub">Super Admin</div>
        </div>
      </div>

      <header className="admin-topbar">
        <nav className="admin-topbar__crumbs" aria-label="Breadcrumb">
          <span>Console</span>
          <span>/</span>
          <b>{current}</b>
        </nav>
        <div className="admin-topbar__spacer" />
        <span className="admin-env" title="Environment">Local</span>
        <div className="admin-user">
          <div className="admin-user__av">{initials}</div>
          <div className="admin-user__meta">
            <div className="admin-user__name">{user?.displayName || user?.email}</div>
            <div className="admin-user__role">{primaryRole.replaceAll('_', ' ')}</div>
          </div>
        </div>
        <button
          type="button"
          className="admin-signout"
          onClick={() => {
            session.clear();
            router.replace('/login');
          }}
        >
          Sign out
        </button>
      </header>

      <aside className="admin-sidebar">
        {NAV.map((group) => (
          <div className="nav-group" key={group.label}>
            <div className="nav-group__label">{group.label}</div>
            {group.items.map((n) => {
              const active = pathname === n.href || pathname?.startsWith(n.href + '/');
              return (
                <Link key={n.href} href={n.href} className={`nav-link ${active ? 'nav-link--active' : ''}`}>
                  <span className="nav-link__ic" aria-hidden>
                    {n.icon}
                  </span>
                  {n.label}
                </Link>
              );
            })}
          </div>
        ))}
      </aside>

      <main className="admin-main">{children}</main>
    </div>
  );
}
