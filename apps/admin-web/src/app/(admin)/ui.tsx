'use client';

import { useCallback, useState } from 'react';

export function PageHeader({
  eyebrow,
  title,
  subtitle,
  actions,
}: {
  eyebrow: string;
  title: string;
  subtitle: string;
  actions?: React.ReactNode;
}) {
  return (
    <header className="page-head">
      <div style={{ display: 'grid', gap: 6, minWidth: 0 }}>
        <div className="page-head__eyebrow">{eyebrow}</div>
        <h1 style={{ margin: 0 }}>{title}</h1>
        <p style={{ margin: 0, color: 'var(--color-ink-muted)', fontSize: 14 }}>{subtitle}</p>
      </div>
      {actions && <div className="page-head__actions">{actions}</div>}
    </header>
  );
}

const POSITIVE = ['active', 'approved', 'resolved', 'completed', 'auto_verified', 'delivered', 'paid', 'captured'];
const NEGATIVE = ['rejected', 'suspended', 'closed', 'deactivated', 'failed', 'cancelled', 'canceled', 'payment_failed', 'delivery_failed', 'refunded'];
const PENDING = ['applied', 'application', 'under_review', 'pending', 'in_progress', 'offered', 'accepted', 'picked_up', 'out_for_delivery', 'pending_assignment', 'verified', 'awaiting_payment', 'placed', 'confirmed', 'preparing', 'ready'];

export function StatusPill({ status }: { status: string }) {
  const n = (status ?? '').toLowerCase();
  const tone = POSITIVE.includes(n) ? 'success' : NEGATIVE.includes(n) ? 'danger' : PENDING.includes(n) ? 'pending' : 'neutral';
  return <span className={`s-pill s-pill--${tone}`}>{(status ?? '—').replaceAll('_', ' ')}</span>;
}

export function SegmentedTabs({
  value,
  options,
  onChange,
  size = 'md',
}: {
  value: string;
  options: { value: string; label: string; count?: number }[];
  onChange: (value: string) => void;
  size?: 'sm' | 'md';
}) {
  return (
    <div className={`tab-row ${size === 'sm' ? 'tab-row--sm' : ''}`} role="tablist">
      {options.map((o) => (
        <button
          key={o.value}
          role="tab"
          aria-selected={value === o.value}
          className={value === o.value ? 'active' : ''}
          onClick={() => onChange(o.value)}
        >
          {o.label}
          {o.count != null && <span className="tab-count">{o.count}</span>}
        </button>
      ))}
    </div>
  );
}

export function Metric({
  label,
  value,
  tone,
  hint,
}: {
  label: string;
  value: number | string | undefined | null;
  tone?: 'warning' | 'danger' | 'success' | 'info';
  hint?: string;
}) {
  return (
    <div className={`metric-block ${tone ? `metric-block--${tone}` : ''}`}>
      <span>{label}</span>
      <strong>{value ?? '—'}</strong>
      {hint && <em className="metric-block__hint">{hint}</em>}
    </div>
  );
}

export function Drawer({
  title,
  eyebrow,
  onClose,
  children,
  footer,
  width,
}: {
  title: string;
  eyebrow?: string;
  onClose: () => void;
  children: React.ReactNode;
  footer?: React.ReactNode;
  width?: number;
}) {
  return (
    <div className="drawer-backdrop" role="presentation" onMouseDown={(e) => e.target === e.currentTarget && onClose()}>
      <aside className="drawer-panel" role="dialog" aria-modal="true" aria-label={title} style={width ? { width: `min(${width}px, 100%)` } : undefined}>
        <div className="drawer-head">
          <div style={{ minWidth: 0 }}>
            {eyebrow && <div className="modal-kicker">{eyebrow}</div>}
            <h2 style={{ marginTop: 4, wordBreak: 'break-word' }}>{title}</h2>
          </div>
          <button className="drawer-close" aria-label="Close" onClick={onClose}>×</button>
        </div>
        {children}
        {footer && <div className="drawer-foot">{footer}</div>}
      </aside>
    </div>
  );
}

export function DetailGrid({ rows }: { rows: [string, React.ReactNode][] }) {
  return (
    <dl className="detail-grid">
      {rows.map(([k, v], i) => (
        <div key={i} className="detail-grid__row">
          <dt>{k}</dt>
          <dd>{v}</dd>
        </div>
      ))}
    </dl>
  );
}

export function Field({ label, children, hint }: { label: string; children: React.ReactNode; hint?: string }) {
  return (
    <label className="modal-field">
      <span>{label}</span>
      {children}
      {hint && <em className="modal-field__hint">{hint}</em>}
    </label>
  );
}

export type Toast = { tone: 'success' | 'error' | 'info'; msg: string } | null;

export function useToast() {
  const [toast, setToast] = useState<Toast>(null);
  const show = useCallback((tone: 'success' | 'error' | 'info', msg: string) => setToast({ tone, msg }), []);
  const node = toast ? (
    <div className={`toast toast--${toast.tone}`} role="status">
      <span>{toast.msg}</span>
      <button onClick={() => setToast(null)} aria-label="Dismiss" className="toast__x">×</button>
    </div>
  ) : null;
  return { show, node, clear: () => setToast(null) };
}

export function Mono({ children }: { children: string | null | undefined }) {
  return <code className="mono-chip">{children ?? '—'}</code>;
}

export function shortId(id?: string | null): string {
  return id ? `${id.slice(0, 8)}…` : '—';
}

export function money(minor?: number | null, currency = 'INR'): string {
  if (minor == null) return '—';
  try {
    return new Intl.NumberFormat('en-IN', { style: 'currency', currency }).format(minor / 100);
  } catch {
    return `${(minor / 100).toFixed(2)} ${currency}`;
  }
}

export function timeAgo(iso?: string): string {
  if (!iso) return '';
  try {
    const d = new Date(iso);
    const diff = (Date.now() - d.getTime()) / 1000;
    if (diff < 60) return `${Math.floor(diff)}s ago`;
    if (diff < 3600) return `${Math.floor(diff / 60)}m ago`;
    if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`;
    if (diff < 604800) return `${Math.floor(diff / 86400)}d ago`;
    return d.toLocaleDateString();
  } catch {
    return iso;
  }
}
