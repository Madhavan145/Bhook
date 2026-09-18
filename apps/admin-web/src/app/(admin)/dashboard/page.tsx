'use client';

import { useQuery } from '@tanstack/react-query';
import Link from 'next/link';

import { createClient } from '@/lib/api';
import { API } from '@/lib/config';

import { Metric, PageHeader, StatusPill, timeAgo } from '../ui';

const operations = createClient(API.operations);
const order = createClient(API.order);
const delivery = createClient(API.delivery);

type Ticket = { id: string; category: string; subject: string; status: string; createdAt: string };
type OrderSummary = { orderCount: number; grossMinor: number; byStatus: Record<string, number> };
type StaffSummary = { total: number; active: number; online: number; applied: number };

export default function DashboardPage() {
  const audit = useQuery({
    queryKey: ['audit-recent'],
    queryFn: () => operations.get('/api/v1/platform/audit-log', { params: { size: 12 } }).then((r) => r.data),
  });
  const tickets = useQuery({
    queryKey: ['tickets-open'],
    queryFn: () => operations.get('/api/v1/platform/support/tickets', { params: { status: 'OPEN' } }).then((r) => r.data as Ticket[]),
  });
  const orders = useQuery({
    queryKey: ['dash-order-summary'],
    queryFn: () => order.get('/api/v1/platform/orders/summary').then((r) => r.data as OrderSummary),
  });
  const staff = useQuery({
    queryKey: ['dash-staff-summary'],
    queryFn: () => delivery.get('/api/v1/platform/delivery-partners/summary').then((r) => r.data as StaffSummary),
  });

  const events: any[] = audit.data?.content ?? [];
  const openTickets = tickets.data ?? [];
  const live = orders.data?.byStatus
    ? Object.entries(orders.data.byStatus)
        .filter(([s]) => !['DELIVERED', 'CANCELLED', 'CANCELED', 'CLOSED', 'REFUNDED'].includes(s))
        .reduce((a, [, n]) => a + (n as number), 0)
    : undefined;

  return (
    <div className="console-page">
      <PageHeader eyebrow="Operations" title="Overview" subtitle="Real-time platform health across orders, support, delivery and audit." />

      <div className="metric-strip">
        <Metric label="Open tickets" value={openTickets.length} tone={openTickets.length > 0 ? 'warning' : 'success'} hint="Awaiting triage" />
        <Metric label="Live orders" value={live ?? '—'} hint="In flight now" />
        <Metric label="Orders total" value={orders.data?.orderCount ?? '—'} hint="All time" />
        <Metric label="Active staff" value={staff.data?.active ?? '—'} tone="success" hint={`${staff.data?.online ?? 0} online`} />
        <Metric label="Recent events" value={events.length} tone="info" hint="Last published" />
      </div>

      <div className="console-grid-2">
        <section className="console-card">
          <div className="console-card__head">
            <div>
              <h2>Recent events</h2>
              <div className="console-card__sub">Domain events from the audit stream</div>
            </div>
            <Link href="/audit" className="link-btn">View audit log →</Link>
          </div>
          <div className="console-card__body">
            {audit.isLoading && <div className="b-empty">Loading events…</div>}
            {!audit.isLoading && events.length === 0 && <div className="b-empty">No events recorded yet.</div>}
            {events.slice(0, 10).map((row) => (
              <div key={row.id} className="feed-row">
                <span className="feed-dot" />
                <div style={{ minWidth: 0 }}>
                  <div className="feed-row__title">{row.eventType}</div>
                  <div className="feed-row__meta">{row.aggregateType} · {row.aggregateId?.slice(0, 8)}…</div>
                </div>
                <div className="feed-row__when">{timeAgo(row.createdAt)}</div>
              </div>
            ))}
          </div>
        </section>

        <section className="console-card">
          <div className="console-card__head">
            <div>
              <h2>Open tickets</h2>
              <div className="console-card__sub">Escalations waiting for an operator</div>
            </div>
            <Link href="/tickets" className="link-btn">Support queue →</Link>
          </div>
          <div className="console-card__body">
            {tickets.isLoading && <div className="b-empty">Loading tickets…</div>}
            {!tickets.isLoading && openTickets.length === 0 && <div className="b-empty">No open tickets. All clear.</div>}
            {openTickets.slice(0, 8).map((t) => (
              <div key={t.id} className="feed-row" style={{ gridTemplateColumns: '1fr auto' }}>
                <div style={{ minWidth: 0 }}>
                  <div className="feed-row__title" style={{ whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{t.subject}</div>
                  <div className="feed-row__meta">{t.category} · {timeAgo(t.createdAt)}</div>
                </div>
                <StatusPill status={t.status} />
              </div>
            ))}
          </div>
        </section>
      </div>
    </div>
  );
}
