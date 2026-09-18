'use client';

import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useEffect, useMemo, useState } from 'react';

import { createClient } from '@/lib/api';
import { API } from '@/lib/config';

import { Drawer, Field, Mono, PageHeader, SegmentedTabs, StatusPill, useToast } from '../ui';

const catalog = createClient(API.catalog);
const identity = createClient(API.identity);

type Vendor = {
  id: string;
  campusId: string;
  legalName: string;
  displayName: string;
  description: string | null;
  contactEmail: string | null;
  contactPhone: string | null;
  operatingHours: string | null;
  lifecycleStatus: string;
  commissionPercent: number | null;
};

type Campus = { id: string; displayName: string };

const STATUSES = ['APPLICATION', 'UNDER_REVIEW', 'APPROVED', 'ACTIVE', 'SUSPENDED', 'REJECTED', 'CLOSED'];
const DEFAULT_PREFERENCE = ['ACTIVE', 'APPROVED', 'APPLICATION', 'UNDER_REVIEW', 'SUSPENDED', 'REJECTED', 'CLOSED'];

export default function VendorsPage() {
  const qc = useQueryClient();
  const toast = useToast();
  const [status, setStatus] = useState('ACTIVE');
  const [initDone, setInitDone] = useState(false);
  const [creating, setCreating] = useState(false);
  const [creds, setCreds] = useState<{ email: string; password: string | null; name: string } | null>(null);
  const [editing, setEditing] = useState<Vendor | null>(null);
  const [decision, setDecision] = useState<{ id: string; name: string; action: 'approve' | 'reject' | 'suspend' } | null>(null);
  const [decisionReason, setDecisionReason] = useState('');

  const campuses = useQuery({
    queryKey: ['campuses-for-vendors'],
    queryFn: () => createClient(API.campus).get('/api/v1/campuses').then((r) => r.data as Campus[]),
  });
  const list = useQuery({
    queryKey: ['vendors-admin-all'],
    queryFn: () => catalog.get('/api/v1/platform/vendors').then((r) => r.data as Vendor[]),
  });

  const campusName = useMemo(() => {
    const map = new Map((campuses.data ?? []).map((c) => [c.id, c.displayName]));
    return (id: string) => map.get(id) ?? `${id.slice(0, 8)}…`;
  }, [campuses.data]);

  const counts = useMemo(() => {
    const c: Record<string, number> = {};
    (list.data ?? []).forEach((v) => { c[v.lifecycleStatus] = (c[v.lifecycleStatus] ?? 0) + 1; });
    return c;
  }, [list.data]);

  // Land on the most useful non-empty queue instead of an empty Application tab.
  useEffect(() => {
    if (!initDone && list.data) {
      const best = DEFAULT_PREFERENCE.find((s) => (counts[s] ?? 0) > 0) ?? 'ACTIVE';
      setStatus(best);
      setInitDone(true);
    }
  }, [initDone, list.data, counts]);

  const rows = (list.data ?? []).filter((v) => v.lifecycleStatus === status);

  const invalidate = () => { qc.invalidateQueries({ queryKey: ['vendors-admin-all'] }); };

  const approve = useMutation({
    mutationFn: ({ id, reason }: { id: string; reason: string }) => catalog.post(`/api/v1/platform/vendors/${id}/approve`, { reason }).then((r) => r.data),
    onSuccess: () => { invalidate(); toast.show('success', 'Vendor approved'); },
    onError: () => toast.show('error', 'Approval failed. Check the catalog service and try again.'),
  });
  const reject = useMutation({
    mutationFn: ({ id, reason }: { id: string; reason: string }) => catalog.post(`/api/v1/platform/vendors/${id}/reject`, { reason }).then((r) => r.data),
    onSuccess: () => { invalidate(); toast.show('success', 'Vendor rejected'); },
    onError: () => toast.show('error', 'Rejection failed. Try again.'),
  });
  const suspend = useMutation({
    mutationFn: ({ id, reason }: { id: string; reason: string }) => catalog.post(`/api/v1/platform/vendors/${id}/suspend`, { reason }).then((r) => r.data),
    onSuccess: () => { invalidate(); toast.show('success', 'Vendor suspended'); },
    onError: () => toast.show('error', 'Suspension failed. Try again.'),
  });
  const create = useMutation({
    mutationFn: async (body: { campusId: string; legalName: string; displayName: string; description?: string; ownerName: string; ownerEmail: string; contactPhone?: string; password?: string }) => {
      const provisioned = await identity
        .post('/api/v1/platform/users', {
          email: body.ownerEmail,
          displayName: body.ownerName,
          phoneE164: body.contactPhone || undefined,
          roles: ['VENDOR_OWNER'],
          password: body.password || undefined,
        })
        .then((r) => r.data as { userId: string; email: string; temporaryPassword: string | null });
      await catalog.post('/api/v1/platform/vendors', {
        campusId: body.campusId,
        legalName: body.legalName,
        displayName: body.displayName,
        description: body.description,
        ownerEmail: body.ownerEmail,
        contactPhone: body.contactPhone,
        ownerUserId: provisioned.userId,
      });
      return { email: provisioned.email, password: provisioned.temporaryPassword ?? (body.password || null), name: body.displayName };
    },
    onSuccess: (result) => { setCreds(result); setCreating(false); invalidate(); toast.show('success', 'Vendor and owner account created'); },
    onError: () => toast.show('error', 'Could not create vendor. The owner email may already be registered.'),
  });
  const update = useMutation({
    mutationFn: ({ id, body }: { id: string; body: Partial<Vendor> }) => catalog.patch(`/api/v1/platform/vendors/${id}`, body).then((r) => r.data),
    onSuccess: () => { invalidate(); setEditing(null); toast.show('success', 'Vendor updated'); },
    onError: () => toast.show('error', 'Update failed. Check the fields and try again.'),
  });

  const busy = approve.isPending || reject.isPending || suspend.isPending;

  return (
    <div className="console-page">
      <PageHeader
        eyebrow="Onboarding"
        title="Vendors"
        subtitle="Approve applications, monitor lifecycle, edit profiles and act on incidents."
        actions={<button className="b-btn b-btn--primary" onClick={() => { setCreds(null); setCreating(true); }}>Add vendor</button>}
      />

      <section className="info-panel">
        <h3>Lifecycle: Approved vs Active</h3>
        <p>
          <b>Application / Under review</b> — a new vendor awaiting your decision. <b>Approved</b> — you have greenlit them, but they
          are not yet serving orders (the owner still needs to finish menu setup and go live). <b>Active</b> — live and accepting
          orders on their campus. <b>Suspended</b> pauses an active vendor; <b>Rejected / Closed</b> are terminal.
        </p>
      </section>

      <SegmentedTabs
        value={status}
        onChange={setStatus}
        options={STATUSES.map((s) => ({ value: s, label: s.replaceAll('_', ' '), count: counts[s] ?? 0 }))}
      />

      {creds && (
        <section className="info-panel" style={{ borderLeftColor: 'var(--color-primary)' }}>
          <h3>Vendor owner account created — share these credentials securely</h3>
          <div style={{ display: 'flex', gap: 16, flexWrap: 'wrap', alignItems: 'center' }}>
            <span>Login: <Mono>{creds.email}</Mono></span>
            <span>Password: {creds.password ? <Mono>{creds.password}</Mono> : 'set by you'}</span>
            {creds.password && <button className="link-btn" onClick={() => navigator.clipboard?.writeText(`${creds.email} / ${creds.password}`)}>Copy</button>}
          </div>
          <p>The password is shown only once. The owner can sign in immediately and finish onboarding their menu.</p>
        </section>
      )}

      <section className="console-table-wrap">
        <table className="b-table">
          <thead>
            <tr>
              <th>Vendor</th>
              <th>Contact</th>
              <th>Campus</th>
              <th>Status</th>
              <th style={{ textAlign: 'right' }}>Actions</th>
            </tr>
          </thead>
          <tbody>
            {list.isLoading && <tr><td colSpan={5} className="b-empty">Loading vendors…</td></tr>}
            {!list.isLoading && rows.length === 0 && <tr><td colSpan={5} className="b-empty">No vendors in {status.replaceAll('_', ' ').toLowerCase()}.</td></tr>}
            {rows.map((v) => (
              <tr key={v.id}>
                <td><strong>{v.displayName}</strong><small>{v.legalName}</small></td>
                <td>{v.contactEmail ?? '—'}</td>
                <td>{campusName(v.campusId)}</td>
                <td><StatusPill status={v.lifecycleStatus} /></td>
                <td style={{ textAlign: 'right' }}>
                  <div style={{ display: 'inline-flex', gap: 6 }}>
                    <button className="b-btn b-btn--ghost" style={miniBtn} onClick={() => setEditing(v)}>Edit</button>
                    {(v.lifecycleStatus === 'APPLICATION' || v.lifecycleStatus === 'UNDER_REVIEW') && (
                      <>
                        <button className="b-btn b-btn--ghost" style={miniBtn} disabled={busy} onClick={() => { setDecision({ id: v.id, name: v.displayName, action: 'reject' }); setDecisionReason(''); }}>Reject</button>
                        <button className="b-btn b-btn--primary" style={miniBtn} disabled={busy} onClick={() => { setDecision({ id: v.id, name: v.displayName, action: 'approve' }); setDecisionReason(''); }}>Approve</button>
                      </>
                    )}
                    {(v.lifecycleStatus === 'ACTIVE' || v.lifecycleStatus === 'APPROVED') && (
                      <button className="b-btn b-btn--ghost" style={miniBtn} disabled={busy} onClick={() => { setDecision({ id: v.id, name: v.displayName, action: 'suspend' }); setDecisionReason(''); }}>Suspend</button>
                    )}
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </section>

      {creating && (
        <CreateVendorForm
          campuses={campuses.data ?? []}
          campusesLoading={campuses.isLoading}
          busy={create.isPending}
          error={create.error ? 'Vendor could not be created. Check the details and try again.' : null}
          onCancel={() => setCreating(false)}
          onSubmit={(body) => create.mutate(body)}
        />
      )}

      {editing && (
        <EditVendorDrawer
          vendor={editing}
          busy={update.isPending}
          onClose={() => setEditing(null)}
          onSave={(body) => update.mutate({ id: editing.id, body })}
        />
      )}

      {decision && (
        <div className="modal-backdrop" role="presentation" onMouseDown={(e) => { if (e.target === e.currentTarget) setDecision(null); }}>
          <section className="modal-panel" role="dialog" aria-modal="true">
            <div className="modal-kicker">Lifecycle control</div>
            <h2>{decision.action === 'approve' ? 'Approve' : decision.action === 'reject' ? 'Reject' : 'Suspend'} {decision.name}</h2>
            <p className="modal-copy">This is recorded in the audit stream. Add a short operational reason.</p>
            <Field label="Reason"><textarea className="b-input" rows={4} value={decisionReason} onChange={(e) => setDecisionReason(e.target.value)} placeholder="Explain the decision for the next operator…" autoFocus /></Field>
            <div className="modal-actions">
              <button className="b-btn b-btn--ghost" onClick={() => setDecision(null)}>Cancel</button>
              <button className="b-btn b-btn--primary" disabled={!decisionReason.trim() || busy} onClick={() => {
                const payload = { id: decision.id, reason: decisionReason.trim() };
                if (decision.action === 'approve') approve.mutate(payload);
                if (decision.action === 'reject') reject.mutate(payload);
                if (decision.action === 'suspend') suspend.mutate(payload);
                setDecision(null); setDecisionReason('');
              }}>{busy ? 'Saving…' : 'Confirm action'}</button>
            </div>
          </section>
        </div>
      )}

      {toast.node}
    </div>
  );
}

function EditVendorDrawer({ vendor, busy, onClose, onSave }: { vendor: Vendor; busy: boolean; onClose: () => void; onSave: (body: Partial<Vendor>) => void }) {
  const [legalName, setLegalName] = useState(vendor.legalName ?? '');
  const [displayName, setDisplayName] = useState(vendor.displayName ?? '');
  const [description, setDescription] = useState(vendor.description ?? '');
  const [contactEmail, setContactEmail] = useState(vendor.contactEmail ?? '');
  const [contactPhone, setContactPhone] = useState(vendor.contactPhone ?? '');
  const [operatingHours, setOperatingHours] = useState(vendor.operatingHours ?? '');
  const [commissionPercent, setCommissionPercent] = useState(vendor.commissionPercent?.toString() ?? '15');
  return (
    <Drawer eyebrow="Edit vendor" title={vendor.displayName} onClose={onClose} width={520}
      footer={<>
        <button className="b-btn b-btn--ghost" onClick={onClose}>Cancel</button>
        <button className="b-btn b-btn--primary" disabled={busy} onClick={() => onSave({ legalName, displayName, description, contactEmail, contactPhone, operatingHours, commissionPercent: Number(commissionPercent) })}>{busy ? 'Saving…' : 'Save changes'}</button>
      </>}>
      <div style={{ display: 'grid', gap: 12 }}>
        <Field label="Display name"><input className="b-input" value={displayName} onChange={(e) => setDisplayName(e.target.value)} /></Field>
        <Field label="Legal name"><input className="b-input" value={legalName} onChange={(e) => setLegalName(e.target.value)} /></Field>
        <Field label="Contact email"><input className="b-input" type="email" value={contactEmail} onChange={(e) => setContactEmail(e.target.value)} /></Field>
        <Field label="Contact phone"><input className="b-input" value={contactPhone} onChange={(e) => setContactPhone(e.target.value)} /></Field>
        <Field label="Operating hours" hint="e.g. Mon–Sat 09:00–22:00"><input className="b-input" value={operatingHours} onChange={(e) => setOperatingHours(e.target.value)} /></Field>
        <Field label="Description"><textarea className="b-input" rows={4} value={description} onChange={(e) => setDescription(e.target.value)} /></Field>
        <Field label="Commission percentage" hint="Applied to completed orders for this vendor."><input className="b-input" type="number" min="0" max="100" step="0.5" value={commissionPercent} onChange={(e) => setCommissionPercent(e.target.value)} /></Field>
      </div>
    </Drawer>
  );
}

function CreateVendorForm({
  campuses,
  campusesLoading,
  busy,
  error,
  onCancel,
  onSubmit,
}: {
  campuses: Campus[];
  campusesLoading: boolean;
  busy: boolean;
  error: string | null;
  onCancel: () => void;
  onSubmit: (body: { campusId: string; legalName: string; displayName: string; description?: string; ownerName: string; ownerEmail: string; contactPhone?: string; password?: string }) => void;
}) {
  const [campusId, setCampusId] = useState('');
  const [legalName, setLegalName] = useState('');
  const [displayName, setDisplayName] = useState('');
  const [ownerName, setOwnerName] = useState('');
  const [ownerEmail, setOwnerEmail] = useState('');
  const [contactPhone, setContactPhone] = useState('');
  const [description, setDescription] = useState('');
  const [password, setPassword] = useState('');

  return (
    <div className="modal-backdrop" role="presentation" onMouseDown={(e) => { if (e.target === e.currentTarget) onCancel(); }}>
      <form
        className="modal-panel"
        onSubmit={(event) => { event.preventDefault(); onSubmit({ campusId, legalName, displayName, ownerName, ownerEmail, contactPhone, description, password }); }}
      >
        <div className="modal-kicker">Onboarding</div>
        <h2>Add a partnered vendor</h2>
        <p className="modal-copy">Assign the vendor to a campus and create the owner&rsquo;s login account. You&rsquo;ll receive credentials to hand over.</p>
        <Field label="Campus"><select required value={campusId} onChange={(e) => setCampusId(e.target.value)} className="b-input" disabled={campusesLoading}>
          <option value="">{campusesLoading ? 'Loading campuses…' : 'Select a campus'}</option>
          {campuses.map((c) => <option key={c.id} value={c.id}>{c.displayName}</option>)}
        </select></Field>
        <Field label="Legal name"><input required value={legalName} onChange={(e) => setLegalName(e.target.value)} className="b-input" /></Field>
        <Field label="Display name" hint="Business name shown to customers"><input required value={displayName} onChange={(e) => setDisplayName(e.target.value)} className="b-input" /></Field>
        <Field label="Owner name" hint="Person who will log in"><input required value={ownerName} onChange={(e) => setOwnerName(e.target.value)} className="b-input" /></Field>
        <Field label="Owner email" hint="Becomes their login username"><input required type="email" value={ownerEmail} onChange={(e) => setOwnerEmail(e.target.value)} className="b-input" /></Field>
        <Field label="Contact phone"><input value={contactPhone} onChange={(e) => setContactPhone(e.target.value)} className="b-input" /></Field>
        <Field label="Temporary password" hint="Leave blank to auto-generate"><input value={password} onChange={(e) => setPassword(e.target.value)} className="b-input" /></Field>
        <Field label="Description"><input value={description} onChange={(e) => setDescription(e.target.value)} className="b-input" /></Field>
        {error && <div className="inline-error">{error}</div>}
        <div className="modal-actions">
          <button type="button" className="b-btn b-btn--ghost" onClick={onCancel}>Cancel</button>
          <button type="submit" className="b-btn b-btn--primary" disabled={busy || campusesLoading}>{busy ? 'Creating…' : 'Create vendor'}</button>
        </div>
      </form>
    </div>
  );
}

const miniBtn: React.CSSProperties = { padding: '6px 12px', fontSize: 12 };
