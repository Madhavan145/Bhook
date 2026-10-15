'use client';

import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useMemo, useState } from 'react';

import { createClient } from '@/lib/api';
import { API } from '@/lib/config';
import { session } from '@/lib/session';

import { Drawer, DetailGrid, Field, Mono, PageHeader, SegmentedTabs, StatusPill, useToast, timeAgo } from '../ui';

const operations = createClient(API.operations);
const catalog = createClient(API.catalog);
const orderClient = createClient(API.order);

type Ticket = {
  id: string;
  openerUserId: string;
  category: string;
  subject: string;
  body: string;
  status: string;
  assignedTo: string | null;
  relatedOrderId: string | null;
  relatedVendorId: string | null;
  resolutionNotes: string | null;
  createdAt: string;
  updatedAt: string;
};

type Named = { id: string; displayName: string };
type OrderLite = { orderId: string; orderNumber: string };

const STATUSES = ['OPEN', 'IN_PROGRESS', 'RESOLVED', 'CLOSED'];

export default function TicketsPage() {
  const qc = useQueryClient();
  const toast = useToast();
  const me = session.user();
  const [status, setStatus] = useState('OPEN');
  const [creating, setCreating] = useState(false);
  const [createError, setCreateError] = useState('');
  const [selected, setSelected] = useState<Ticket | null>(null);
  const [resolutionNotes, setResolutionNotes] = useState('');
  const [draft, setDraft] = useState({ category: 'GENERAL', subject: '', body: '', relatedOrderId: '', relatedVendorId: '' });

  const tickets = useQuery({
    queryKey: ['tickets', status],
    queryFn: () => operations.get('/api/v1/platform/support/tickets', { params: { status } }).then((r) => r.data as Ticket[]),
  });
  const vendors = useQuery({
    queryKey: ['tickets-vendors'],
    queryFn: () => catalog.get('/api/v1/platform/vendors').then((r) => r.data as Named[]),
  });
  const orders = useQuery({
    queryKey: ['tickets-orders'],
    queryFn: () => orderClient.get('/api/v1/platform/orders').then((r) => r.data as OrderLite[]),
  });

  const vendorName = useMemo(() => {
    const map = new Map((vendors.data ?? []).map((v) => [v.id, v.displayName]));
    return (id?: string | null) => (id ? map.get(id) ?? `${id.slice(0, 8)}…` : null);
  }, [vendors.data]);
  const orderNumber = useMemo(() => {
    const map = new Map((orders.data ?? []).map((o) => [o.orderId, o.orderNumber]));
    return (id?: string | null) => (id ? map.get(id) ?? `${id.slice(0, 8)}…` : null);
  }, [orders.data]);
  const person = (id?: string | null) => {
    if (!id) return null;
    if (me && id === me.userId) return 'You';
    return `${id.slice(0, 8)}…`;
  };

  const assign = useMutation({
    mutationFn: (id: string) => operations.post(`/api/v1/platform/support/tickets/${id}/assign`).then((r) => r.data),
    onSuccess: () => { qc.invalidateQueries({ queryKey: ['tickets'] }); toast.show('success', 'Assigned to you'); },
    onError: () => toast.show('error', 'Could not assign the ticket.'),
  });
  const resolve = useMutation({
    mutationFn: ({ id, notes }: { id: string; notes: string }) =>
      operations.patch(`/api/v1/platform/support/tickets/${id}/status`, { status: 'RESOLVED', resolutionNotes: notes }).then((r) => r.data),
    onSuccess: () => { qc.invalidateQueries({ queryKey: ['tickets'] }); toast.show('success', 'Ticket resolved'); setSelected(null); setResolutionNotes(''); },
    onError: () => toast.show('error', 'Could not resolve the ticket.'),
  });
  const create = useMutation({
    mutationFn: () =>
      operations.post('/api/v1/platform/support/tickets', {
        ...draft, relatedOrderId: draft.relatedOrderId || null, relatedVendorId: draft.relatedVendorId || null,
      }).then((r) => r.data),
    onSuccess: () => {
      setCreating(false); setCreateError('');
      setDraft({ category: 'GENERAL', subject: '', body: '', relatedOrderId: '', relatedVendorId: '' });
      qc.invalidateQueries({ queryKey: ['tickets'] });
      toast.show('success', 'Ticket created');
    },
    onError: (error) => setCreateError(error instanceof Error ? error.message : 'Ticket creation failed. Check your access and try again.'),
  });

  const rows = tickets.data ?? [];

  return (
    <div className="console-page">
      <PageHeader
        eyebrow="Support"
        title="Tickets"
        subtitle="Customer, vendor and partner escalations — assign quickly, resolve with notes."
        actions={<button className="b-btn b-btn--primary" onClick={() => { setCreateError(''); setCreating(true); }}>New ticket</button>}
      />

      <SegmentedTabs value={status} onChange={setStatus} options={STATUSES.map((s) => ({ value: s, label: s.replaceAll('_', ' ') }))} />

      <section className="console-table-wrap">
        <table className="b-table">
          <thead>
            <tr>
              <th>Subject</th>
              <th>Category</th>
              <th>Linked</th>
              <th>Opened by</th>
              <th>Assignee</th>
              <th>Age</th>
              <th style={{ textAlign: 'right' }}>Actions</th>
            </tr>
          </thead>
          <tbody>
            {tickets.isLoading && <tr><td colSpan={7} className="b-empty">Loading tickets…</td></tr>}
            {!tickets.isLoading && rows.length === 0 && <tr><td colSpan={7} className="b-empty">No tickets in {status.replaceAll('_', ' ').toLowerCase()}.</td></tr>}
            {rows.map((t) => (
              <tr key={t.id} className="row-click" onClick={() => setSelected(t)}>
                <td><strong>{t.subject}</strong><small><StatusPill status={t.status} /></small></td>
                <td>{t.category}</td>
                <td>
                  {t.relatedVendorId && <span className="mono-chip" style={{ marginRight: 4 }}>{vendorName(t.relatedVendorId)}</span>}
                  {t.relatedOrderId && <span className="mono-chip">{orderNumber(t.relatedOrderId)}</span>}
                  {!t.relatedVendorId && !t.relatedOrderId && '—'}
                </td>
                <td>{person(t.openerUserId)}</td>
                <td>{person(t.assignedTo) ?? <span style={{ color: 'var(--color-ink-faint)' }}>Unassigned</span>}</td>
                <td><small>{timeAgo(t.createdAt)}</small></td>
                <td style={{ textAlign: 'right' }} onClick={(e) => e.stopPropagation()}>
                  {t.status !== 'RESOLVED' && t.status !== 'CLOSED' && (
                    <div style={{ display: 'inline-flex', gap: 6 }}>
                      <button className="b-btn b-btn--ghost" style={miniBtn} onClick={() => assign.mutate(t.id)}>Take</button>
                      <button className="b-btn b-btn--primary" style={miniBtn} onClick={() => { setSelected(t); setResolutionNotes(''); }}>Resolve</button>
                    </div>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </section>

      {selected && (
        <Drawer
          eyebrow={`Ticket · ${selected.category}`}
          title={selected.subject}
          onClose={() => setSelected(null)}
          width={560}
          footer={
            selected.status !== 'RESOLVED' && selected.status !== 'CLOSED' ? (
              <>
                <button className="b-btn b-btn--ghost" onClick={() => assign.mutate(selected.id)} disabled={assign.isPending}>Assign to me</button>
                <button className="b-btn b-btn--primary" disabled={!resolutionNotes.trim() || resolve.isPending} onClick={() => resolve.mutate({ id: selected.id, notes: resolutionNotes })}>{resolve.isPending ? 'Saving…' : 'Resolve ticket'}</button>
              </>
            ) : undefined
          }
        >
          <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}><StatusPill status={selected.status} /></div>
          <DetailGrid
            rows={[
              ['Opened by', person(selected.openerUserId) ?? '—'],
              ['Assignee', person(selected.assignedTo) ?? 'Unassigned'],
              ['Linked vendor', vendorName(selected.relatedVendorId) ?? '—'],
              ['Linked order', orderNumber(selected.relatedOrderId) ?? '—'],
              ['Created', new Date(selected.createdAt).toLocaleString()],
              ['Updated', new Date(selected.updatedAt).toLocaleString()],
              ['Ticket ID', <Mono key="id">{selected.id}</Mono>],
            ]}
          />
          <div className="console-card">
            <div className="console-card__head"><h2>Description</h2></div>
            <p style={{ padding: '12px 18px', margin: 0, lineHeight: 1.6, color: 'var(--color-ink)', fontSize: 14 }}>{selected.body}</p>
          </div>
          {selected.resolutionNotes && (
            <div className="console-card">
              <div className="console-card__head"><h2>Resolution</h2></div>
              <p style={{ padding: '12px 18px', margin: 0, lineHeight: 1.6, color: 'var(--color-ink)', fontSize: 14 }}>{selected.resolutionNotes}</p>
            </div>
          )}
          {selected.status !== 'RESOLVED' && selected.status !== 'CLOSED' && (
            <Field label="Resolution notes" hint="Required to resolve">
              <textarea className="b-input" rows={4} value={resolutionNotes} onChange={(e) => setResolutionNotes(e.target.value)} placeholder="Describe how this was resolved…" />
            </Field>
          )}
        </Drawer>
      )}

      {creating && (
        <div className="modal-backdrop" role="presentation" onMouseDown={(e) => { if (e.target === e.currentTarget) setCreating(false); }}>
          <form className="modal-panel" onSubmit={(event) => { event.preventDefault(); setCreateError(''); create.mutate(); }}>
            <div className="modal-kicker">Support intake</div>
            <h2>Open an operations ticket</h2>
            <p className="modal-copy">Create an internal case for a campus, vendor, customer, or delivery issue.</p>
            {createError && <div className="inline-error" role="alert">{createError}</div>}
            <Field label="Category">
              <select className="b-input" value={draft.category} onChange={(e) => setDraft({ ...draft, category: e.target.value })}>
                {['GENERAL', 'PAYMENT', 'DELIVERY', 'VENDOR', 'ACCOUNT'].map((c) => <option key={c}>{c}</option>)}
              </select>
            </Field>
            <Field label="Subject"><input className="b-input" required value={draft.subject} onChange={(e) => setDraft({ ...draft, subject: e.target.value })} /></Field>
            <Field label="Linked vendor" hint="Optional">
              <select className="b-input" value={draft.relatedVendorId} onChange={(e) => setDraft({ ...draft, relatedVendorId: e.target.value })}>
                <option value="">None</option>
                {(vendors.data ?? []).map((v) => <option key={v.id} value={v.id}>{v.displayName}</option>)}
              </select>
            </Field>
            <Field label="Linked order" hint="Optional">
              <select className="b-input" value={draft.relatedOrderId} onChange={(e) => setDraft({ ...draft, relatedOrderId: e.target.value })}>
                <option value="">None</option>
                {(orders.data ?? []).slice(0, 100).map((o) => <option key={o.orderId} value={o.orderId}>{o.orderNumber}</option>)}
              </select>
            </Field>
            <Field label="Details"><textarea className="b-input" required rows={5} value={draft.body} onChange={(e) => setDraft({ ...draft, body: e.target.value })} /></Field>
            <div className="modal-actions">
              <button type="button" className="b-btn b-btn--ghost" onClick={() => setCreating(false)}>Cancel</button>
              <button className="b-btn b-btn--primary" disabled={create.isPending}>{create.isPending ? 'Creating…' : 'Create ticket'}</button>
            </div>
          </form>
        </div>
      )}

      {toast.node}
    </div>
  );
}

const miniBtn: React.CSSProperties = { padding: '6px 12px', fontSize: 12 };
