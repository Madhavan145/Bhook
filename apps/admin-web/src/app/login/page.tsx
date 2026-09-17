'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';

import { createClient } from '@/lib/api';
import { API } from '@/lib/config';
import { hasPlatformRole, session } from '@/lib/session';

const identity = createClient(API.identity);

export default function LoginPage() {
  const router = useRouter();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    setBusy(true);
    setError(null);
    try {
      const { data } = await identity.post('/api/v1/auth/login', { email, password });
      const user = {
        userId: data.user.userId,
        email: data.user.email,
        displayName: data.user.displayName ?? '',
        roles: (data.user.roles ?? []) as string[],
      };
      if (!hasPlatformRole(user)) {
        setError('This account does not have platform access.');
        return;
      }
      session.save(data.accessToken, data.refreshToken, user);
      router.replace('/dashboard');
    } catch (err) {
      setError('Invalid credentials or platform access denied.');
    } finally {
      setBusy(false);
    }
  }

  return (
    <div
      style={{
        minHeight: '100vh',
        display: 'grid',
        placeItems: 'center',
        padding: 24,
        background: 'var(--color-surface)',
      }}
    >
      <main
        style={{
          width: '100%',
          maxWidth: 420,
          padding: 32,
          background: 'var(--color-card)',
          borderRadius: 20,
          boxShadow: 'var(--shadow-lg)',
          border: '1px solid var(--color-divider)',
        }}
      >
        <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 20 }}>
          <div
            style={{
              width: 42,
              height: 42,
              borderRadius: 12,
              background: 'var(--color-primary)',
              color: 'white',
              display: 'grid',
              placeItems: 'center',
              fontWeight: 900,
              fontSize: 22,
            }}
          >
            B
          </div>
          <div>
            <div style={{ fontWeight: 800, fontSize: 18, color: 'var(--color-ink-strong)' }}>Bhook Admin</div>
            <div style={{ fontSize: 12, color: 'var(--color-ink-muted)' }}>
              Sign in to the operations console
            </div>
          </div>
        </div>

        <form onSubmit={submit} style={{ display: 'grid', gap: 14 }}>
          <label style={{ display: 'grid', gap: 6 }}>
            <span style={{ fontSize: 12, fontWeight: 700, color: 'var(--color-ink-muted)', letterSpacing: 0.05 }}>
              Work email
            </span>
            <input
              type="email"
              value={email}
              required
              placeholder="you@bhook.io"
              onChange={(e) => setEmail(e.target.value)}
              className="b-input"
            />
          </label>
          <label style={{ display: 'grid', gap: 6 }}>
            <span style={{ fontSize: 12, fontWeight: 700, color: 'var(--color-ink-muted)', letterSpacing: 0.05 }}>
              Password
            </span>
            <input
              type="password"
              value={password}
              required
              onChange={(e) => setPassword(e.target.value)}
              className="b-input"
            />
          </label>
          {error && (
            <div
              style={{
                background: 'var(--color-danger-soft)',
                color: 'var(--color-danger)',
                padding: '10px 12px',
                borderRadius: 10,
                fontSize: 13,
                fontWeight: 500,
              }}
            >
              {error}
            </div>
          )}
          <button
            type="submit"
            disabled={busy}
            className="b-btn b-btn--primary"
            style={{ marginTop: 4, padding: '12px 16px', fontSize: 14 }}
          >
            {busy ? 'Signing in…' : 'Sign in →'}
          </button>
        </form>

        <div
          style={{
            marginTop: 24,
            paddingTop: 16,
            borderTop: '1px solid var(--color-divider)',
            fontSize: 12,
            color: 'var(--color-ink-faint)',
            textAlign: 'center',
          }}
        >
          Platform staff only. Customers, vendors and delivery partners use the mobile apps.
        </div>
      </main>
    </div>
  );
}
