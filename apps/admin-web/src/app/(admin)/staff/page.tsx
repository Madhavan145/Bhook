'use client';

import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';

import { createClient } from '@/lib/api';
import { API } from '@/lib/config';

import { Field, Mono, PageHeader, StatusPill } from '../ui';

const delivery = createClient(API.delivery);
const identity = createClient(API.identity);
const campusClient = createClient(API.campus);

type Partner = {
  id: string;
  userId: string;
  campusId: string;
  status: string;
  availabilityStatus: string;
  activeTaskCount: number;
  currentLatitude: number | null;
  currentLongitude: number | null;
  createdAt: string;
  updatedAt: string;
};

type Summary = { total: number; applied: number; active: number; suspended: number; online: number };
type Campus = { id: string; displayName: string };

const STATUSES = ['', 'APPLIED', 'VERIFIED', 'ACTIVE', 'SUSPENDED', 'DEACTIVATED'];

export default function StaffPage() {
  const qc = useQueryClient();
  const [campusId, setCampusId] = useState('');
  const [status, setStatus] = useState('');
  const [selected, setSelected] = useState<Partner | null>(null);
  const [creating, setCreating] = useState(false);
  const [creds, setCreds] = useState<{ email: string; password: string | null; name: string } | null>(null);
  const [form, setForm] = useState({ displayName: '', email: '', phoneE164: '', campusId: '', password: '' });
  const [toast, setToast] = useState<{ tone: 'success' | 'error'; msg: string } | null>(null);

  const campuses = useQuery({
    queryKey: ['staff-campuses'],
    queryFn: () => campusClient.get('/api/v1/campuses').then((r) => r.data as Campus[]),
  });
  const summary = useQuery({
    queryKey: ['staff-summary'],
    queryFn: () => delivery.get('/api/v1/platform/delivery-partners/summary').then((r) => r.data as Summary),
  });
  const partners = useQuery({
    queryKey: ['staff', campusId, status],
    queryFn: () =>
      delivery
        .get('/api/v1/platform/delivery-partners', {
          params: { campusId: campusId || undefined, status: status || undefined },
        })
        .then((r) => r.data as Partner[]),
  });

  const campusName = (id: string) => campuses.data?.find((c) => c.id === id)?.displayName ?? `${id.slice(0, 8)}…`;

  const action = useMutation({
    mutationFn: ({ id, verb }: { id: string; verb: 'approve' | 'suspend' | 'reactivate' | 'deactivate' }) =>
      delivery.post(`/api/v1/platform/delivery-partners/${id}/${verb}`).then((r) => r.data as Partner),
    onSuccess: (updated, vars) => {
      setToast({ tone: 'success', msg: `Partner ${vars.verb}d successfully` });
      setSelected((prev) => (prev && prev.id === updated.id ? updated : prev));
      qc.invalidateQueries({ queryKey: ['staff'] });
      qc.invalidateQueries({ queryKey: ['staff-summary'] });
    },
    onError: () => setToast({ tone: 'error', msg: 'Action failed. Check permissions and try again.' }),
  });

  const createStaff = useMutation({
    mutationFn: async () => {
      const provisioned = await identity
        .post('/api/v1/platform/users', {
          email: form.email,
          displayName: form.displayName,
          phoneE164: form.phoneE164 || undefined,
          roles: ['DELIVERY_PARTNER'],
          password: form.password || undefined,
        })
        .then((r) => r.data as { userId: string; email: string; temporaryPassword: string | null });
      await delivery.post('/api/v1/platform/delivery-partners', { userId: provisioned.userId, campusId: form.campusId });
      return { email: provisioned.email, password: provisioned.temporaryPassword ?? (form.password || null), name: form.displayName };
    },
    onSuccess: (result) => {
      setCreating(false);
      setCreds(result);
      setForm({ displayName: '', email: '', phoneE164: '', campusId: '', password: '' });
      qc.invalidateQueries({ queryKey: ['staff'] });
      qc.invalidateQueries({ queryKey: ['staff-summary'] });
      setToast({ tone: 'success', msg: 'Delivery staff created' });
    },
    onError: () => setToast({ tone: 'error', msg: 'Could not create staff. The email may already be registered.' }),
  });

  const rows = partners.data ?? [];

  return (
    <div className="console-page">
      <PageHeader
        eyebrow="Network"
        title="Delivery staff"
        subtitle="Manage delivery partners across every campus — approve applicants, control access, and monitor availability."
        actions={<button className="b-btn b-btn--primary" onClick={() => { setCreds(null); setCreating(true); }}>Create staff</button>}
      />

      <section className="info-panel">
        <h3>Two ways to onboard delivery staff</h3>
        <p>
          <b>Self-service:</b> a rider signs up in the partner app and picks the campus they will serve, creating an <b>APPLIED</b>
          record you approve here. <b>Admin-provisioned:</b> use <b>Create staff</b> to generate their login account and an active,
          campus-bound partner profile in one step — you&rsquo;ll get credentials to hand over. Riders are scoped to a single campus;
          orders auto-assign to the nearest available approved rider on that campus.
        </p>
      </section>

      <div className="metric-strip">
        <Metric label="Total staff" value={summary.data?.total} />
        <Metric label="Active" value={summary.data?.active} tone="success" />
        <Metric label="Pending approval" value={summary.data?.applied} tone="warning" />
        <Metric label="Suspended" value={summary.data?.suspended} tone="danger" />
        <Metric label="Online now" value={summary.data?.online} />
      </div>

      <section className="console-toolbar">
        <label>
          <span>Campus</span>
          <select className="b-input" value={campusId} onChange={(e) => setCampusId(e.target.value)}>
            <option value="">All campuses</option>
            {(campuses.data ?? []).map((c) => (
              <option key={c.id} value={c.id}>
                {c.displayName}
              </option>
            ))}
          </select>
        </label>
        <label>
          <span>Status</span>
          <select className="b-input" value={status} onChange={(e) => setStatus(e.target.value)}>
            {STATUSES.map((s) => (
              <option key={s} value={s}>
                {s === '' ? 'All statuses' : s}
              </option>
            ))}
          </select>
        </label>
        <div className="console-toolbar__end">
          <span style={{ fontSize: 12, color: 'var(--color-ink-muted)', fontWeight: 600, paddingBottom: 10 }}>
            {rows.length} shown
          </span>
        </div>
      </section>

      <section className="console-table-wrap">
        <table className="b-table">
          <thead>
            <tr>
              <th>Partner</th>
              <th>Campus</th>
              <th>Status</th>
              <th>Availability</th>
              <th>Active tasks</th>
              <th>Joined</th>
            </tr>
          </thead>
          <tbody>
            {partners.isLoading && (
              <tr>
                <td colSpan={6} className="b-empty">
                  Loading delivery staff…
                </td>
              </tr>
            )}
            {!partners.isLoading && rows.length === 0 && (
              <tr>
                <td colSpan={6} className="b-empty">
                  No delivery partners match this view.
                </td>
              </tr>
            )}
            {rows.map((p) => (
              <tr key={p.id} className="row-click" onClick={() => setSelected(p)}>
                <td>
                  <strong>{p.userId.slice(0, 8)}…</strong>
                  <small>{p.id.slice(0, 8)}…</small>
                </td>
                <td>{campusName(p.campusId)}</td>
                <td>
                  <StatusPill status={p.status} />
                </td>
                <td>
                  <span
                    style={{
                      fontSize: 12,
                      fontWeight: 700,
                      color: p.availabilityStatus === 'ONLINE' ? 'var(--color-success)' : 'var(--color-ink-faint)',
                    }}
                  >
                    ● {p.availabilityStatus}
                  </span>
                </td>
                <td className="numeric">{p.activeTaskCount}</td>
                <td>
                  <small>{new Date(p.createdAt).toLocaleDateString()}</small>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </section>

      {selected && (
        <div className="drawer-backdrop" role="presentation" onMouseDown={(e) => e.target === e.currentTarget && setSelected(null)}>
          <aside className="drawer-panel" role="dialog" aria-modal="true" aria-label="Partner detail">
            <div className="drawer-head">
              <div>
                <div className="modal-kicker">Delivery partner</div>
                <h2 style={{ marginTop: 4 }}>{selected.userId.slice(0, 12)}…</h2>
              </div>
              <button className="drawer-close" aria-label="Close" onClick={() => setSelected(null)}>
                ×
              </button>
            </div>

            <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
              <StatusPill status={selected.status} />
              <span
                style={{
                  fontSize: 12,
                  fontWeight: 700,
                  color: selected.availabilityStatus === 'ONLINE' ? 'var(--color-success)' : 'var(--color-ink-faint)',
                  alignSelf: 'center',
                }}
              >
                ● {selected.availabilityStatus}
              </span>
            </div>

            <dl className="detail-grid">
              <div className="detail-grid__row"><dt>Partner ID</dt><dd>{selected.id}</dd></div>
              <div className="detail-grid__row"><dt>User ID</dt><dd>{selected.userId}</dd></div>
              <div className="detail-grid__row"><dt>Campus</dt><dd>{campusName(selected.campusId)}</dd></div>
              <div className="detail-grid__row"><dt>Active tasks</dt><dd>{selected.activeTaskCount}</dd></div>
              <div className="detail-grid__row"><dt>Location</dt><dd>{selected.currentLatitude != null && selected.currentLongitude != null ? `${selected.currentLatitude}, ${selected.currentLongitude}` : 'Not reporting'}</dd></div>
              <div className="detail-grid__row"><dt>Joined</dt><dd>{new Date(selected.createdAt).toLocaleString()}</dd></div>
              <div className="detail-grid__row"><dt>Updated</dt><dd>{new Date(selected.updatedAt).toLocaleString()}</dd></div>
            </dl>

            <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', borderTop: '1px solid var(--color-divider)', paddingTop: 16 }}>
              {(selected.status === 'APPLIED' || selected.status === 'VERIFIED') && (
                <button className="b-btn b-btn--primary" disabled={action.isPending} onClick={() => action.mutate({ id: selected.id, verb: 'approve' })}>
                  Approve
                </button>
              )}
              {selected.status === 'ACTIVE' && (
                <button className="b-btn b-btn--danger" disabled={action.isPending} onClick={() => action.mutate({ id: selected.id, verb: 'suspend' })}>
                  Suspend
                </button>
              )}
              {selected.status === 'SUSPENDED' && (
                <button className="b-btn b-btn--primary" disabled={action.isPending} onClick={() => action.mutate({ id: selected.id, verb: 'reactivate' })}>
                  Reactivate
                </button>
              )}
              {selected.status !== 'DEACTIVATED' && (
                <button className="b-btn b-btn--ghost" disabled={action.isPending} onClick={() => action.mutate({ id: selected.id, verb: 'deactivate' })}>
                  Deactivate
                </button>
              )}
            </div>
          </aside>
        </div>
      )}

      {creating && (
        <div className="modal-backdrop" role="presentation" onMouseDown={(e) => { if (e.target === e.currentTarget) setCreating(false); }}>
          <form className="modal-panel" onSubmit={(e) => { e.preventDefault(); createStaff.mutate(); }}>
            <div className="modal-kicker">Provision staff</div>
            <h2>Create delivery staff</h2>
            <p className="modal-copy">Creates a login account and an active, campus-bound partner profile. Share the generated credentials with the rider.</p>
            <Field label="Full name"><input className="b-input" required value={form.displayName} onChange={(e) => setForm({ ...form, displayName: e.target.value })} /></Field>
            <Field label="Email" hint="Used as the login username"><input className="b-input" type="email" required value={form.email} onChange={(e) => setForm({ ...form, email: e.target.value })} /></Field>
            <Field label="Phone" hint="Optional"><input className="b-input" value={form.phoneE164} onChange={(e) => setForm({ ...form, phoneE164: e.target.value })} placeholder="+91…" /></Field>
            <Field label="Campus"><select className="b-input" required value={form.campusId} onChange={(e) => setForm({ ...form, campusId: e.target.value })}>
              <option value="">Select a campus</option>
              {(campuses.data ?? []).map((c) => <option key={c.id} value={c.id}>{c.displayName}</option>)}
            </select></Field>
            <Field label="Temporary password" hint="Leave blank to auto-generate a secure one"><input className="b-input" value={form.password} onChange={(e) => setForm({ ...form, password: e.target.value })} /></Field>
            <div className="modal-actions">
              <button type="button" className="b-btn b-btn--ghost" onClick={() => setCreating(false)}>Cancel</button>
              <button className="b-btn b-btn--primary" disabled={createStaff.isPending || !form.campusId}>{createStaff.isPending ? 'Creating…' : 'Create staff'}</button>
            </div>
          </form>
        </div>
      )}

      {creds && (
        <div className="modal-backdrop" role="presentation" onMouseDown={(e) => { if (e.target === e.currentTarget) setCreds(null); }}>
          <div className="modal-panel">
            <div className="modal-kicker">Credentials issued</div>
            <h2>{creds.name} is ready</h2>
            <p className="modal-copy">Share these credentials securely — the password is shown only once and won&rsquo;t be recoverable.</p>
            <dl className="detail-grid">
              <div className="detail-grid__row"><dt>Login email</dt><dd><Mono>{creds.email}</Mono></dd></div>
              <div className="detail-grid__row"><dt>Password</dt><dd>{creds.password ? <Mono>{creds.password}</Mono> : 'Set by you'}</dd></div>
            </dl>
            <div className="modal-actions">
              <button className="b-btn b-btn--ghost" onClick={() => { if (creds.password) navigator.clipboard?.writeText(`${creds.email} / ${creds.password}`); }}>Copy</button>
              <button className="b-btn b-btn--primary" onClick={() => setCreds(null)}>Done</button>
            </div>
          </div>
        </div>
      )}

      {toast && (
        <div className={`toast toast--${toast.tone}`} role="status" onAnimationEnd={() => setToast(null)}>
          {toast.msg}
          <button
            onClick={() => setToast(null)}
            style={{ background: 'transparent', border: 0, color: 'inherit', fontWeight: 800, cursor: 'pointer', justifySelf: 'end' }}
          >
            Dismiss
          </button>
        </div>
      )}
    </div>
  );
}

function Metric({ label, value, tone }: { label: string; value: number | undefined; tone?: 'warning' | 'danger' | 'success' }) {
  return (
    <div className={`metric-block ${tone ? `metric-block--${tone}` : ''}`}>
      <span>{label}</span>
      <strong>{value ?? '—'}</strong>
    </div>
  );
}
