'use client';

import { useQuery } from '@tanstack/react-query';
import { useMemo, useState } from 'react';

import { createClient } from '@/lib/api';
import { API } from '@/lib/config';

import { DetailGrid, Drawer, Metric, Mono, PageHeader, StatusPill, money, shortId } from '../ui';

const orderClient = createClient(API.order);
const campusClient = createClient(API.campus);
const catalogClient = createClient(API.catalog);

type Order = {
  orderId: string;
  orderNumber: string;
  status: string;
  paymentState: string;
  campusId: string;
  vendorId: string;
  pickupLocationId: string | null;
  currency: string;
  subtotalMinor: number;
  taxMinor: number;
  deliveryFeeMinor: number;
  platformFeeMinor: number;
  discountMinor: number;
  totalMinor: number;
  paymentMethod: string | null;
  clientReference: string | null;
  createdAt: string;
};

type Summary = {
  orderCount: number;
  grossMinor: number;
  platformFeeMinor: number;
  byStatus: Record<string, number>;
};

type Named = { id: string; displayName: string };

export default function OrdersPage() {
  const [status, setStatus] = useState('');
  const [query, setQuery] = useState('');
  const [campusId, setCampusId] = useState('');
  const [vendorId, setVendorId] = useState('');
  const [selected, setSelected] = useState<Order | null>(null);

  const campuses = useQuery({
    queryKey: ['order-campuses'],
    queryFn: () => campusClient.get('/api/v1/campuses').then((r) => r.data as Named[]),
  });
  const vendors = useQuery({
    queryKey: ['order-vendors'],
    queryFn: () => catalogClient.get('/api/v1/platform/vendors').then((r) => r.data as Named[]),
  });
  const orders = useQuery({
    queryKey: ['platform-orders', status, query, campusId, vendorId],
    queryFn: () =>
      orderClient
        .get('/api/v1/platform/orders', {
          params: { status: status || undefined, query: query || undefined, campusId: campusId || undefined, vendorId: vendorId || undefined },
        })
        .then((r) => r.data as Order[]),
  });
  const summary = useQuery({
    queryKey: ['platform-order-summary', campusId, vendorId],
    queryFn: () =>
      orderClient
        .get('/api/v1/platform/orders/summary', { params: { campusId: campusId || undefined, vendorId: vendorId || undefined } })
        .then((r) => r.data as Summary),
  });

  const campusName = useMemo(() => nameLookup(campuses.data), [campuses.data]);
  const vendorName = useMemo(() => nameLookup(vendors.data), [vendors.data]);

  // Vendors scoped to the selected campus, when a campus filter is active.
  const scopedVendors = useMemo(() => {
    const all = vendors.data ?? [];
    return all;
  }, [vendors.data]);

  const rows = orders.data ?? [];

  return (
    <div className="console-page">
      <PageHeader eyebrow="Command center" title="Orders" subtitle="Monitor every order across campuses, vendors, payments, and fulfillment." />

      <div className="metric-strip">
        <Metric label="Orders" value={summary.data?.orderCount ?? '—'} />
        <Metric label="Gross value" value={money(summary.data?.grossMinor)} />
        <Metric label="Platform fees" value={money(summary.data?.platformFeeMinor)} />
        <Metric
          label="Needs attention"
          value={(summary.data?.byStatus?.PAYMENT_FAILED ?? 0) + (summary.data?.byStatus?.DELIVERY_FAILED ?? 0)}
          tone="warning"
        />
      </div>

      <section className="console-toolbar">
        <label className="toolbar-search">
          <span>Search order</span>
          <input className="b-input" value={query} onChange={(e) => setQuery(e.target.value)} placeholder="Order number or ID" />
        </label>
        <label>
          <span>Campus</span>
          <select className="b-input" value={campusId} onChange={(e) => setCampusId(e.target.value)}>
            <option value="">All campuses</option>
            {(campuses.data ?? []).map((c) => <option key={c.id} value={c.id}>{c.displayName}</option>)}
          </select>
        </label>
        <label>
          <span>Vendor / restaurant</span>
          <select className="b-input" value={vendorId} onChange={(e) => setVendorId(e.target.value)}>
            <option value="">All vendors</option>
            {scopedVendors.map((v) => <option key={v.id} value={v.id}>{v.displayName}</option>)}
          </select>
        </label>
        <label>
          <span>Status</span>
          <select className="b-input" value={status} onChange={(e) => setStatus(e.target.value)}>
            <option value="">All statuses</option>
            {Object.keys(summary.data?.byStatus ?? {}).map((s) => <option key={s}>{s}</option>)}
          </select>
        </label>
        <div className="console-toolbar__end">
          {(campusId || vendorId || status || query) && (
            <button className="link-btn" onClick={() => { setCampusId(''); setVendorId(''); setStatus(''); setQuery(''); }} style={{ paddingBottom: 10 }}>
              Clear filters
            </button>
          )}
        </div>
      </section>

      <div className="note-bar">
        Delivery-partner allocation is tracked per campus in the Delivery staff console — orders here reflect campus &amp; vendor assignment.
      </div>

      <section className="console-table-wrap">
        <table className="b-table">
          <thead>
            <tr>
              <th>Order</th>
              <th>Status</th>
              <th>Payment</th>
              <th>Campus</th>
              <th>Vendor</th>
              <th>Value</th>
              <th>Created</th>
            </tr>
          </thead>
          <tbody>
            {orders.isLoading && <tr><td colSpan={7} className="b-empty">Loading order stream…</td></tr>}
            {!orders.isLoading && rows.length === 0 && <tr><td colSpan={7} className="b-empty">No orders match this view.</td></tr>}
            {rows.map((order) => (
              <tr key={order.orderId} className="row-click" onClick={() => setSelected(order)}>
                <td><strong>{order.orderNumber}</strong><small>{shortId(order.orderId)}</small></td>
                <td><StatusPill status={order.status} /></td>
                <td><StatusPill status={order.paymentState} /></td>
                <td>{campusName(order.campusId)}</td>
                <td>{vendorName(order.vendorId)}</td>
                <td className="numeric">{money(order.totalMinor, order.currency)}</td>
                <td><small>{new Date(order.createdAt).toLocaleString()}</small></td>
              </tr>
            ))}
          </tbody>
        </table>
      </section>

      {selected && (
        <Drawer
          eyebrow="Order detail"
          title={selected.orderNumber}
          onClose={() => setSelected(null)}
          width={560}
        >
          <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
            <StatusPill status={selected.status} />
            <StatusPill status={selected.paymentState} />
          </div>

          <DetailGrid
            rows={[
              ['Order ID', <Mono key="id">{selected.orderId}</Mono>],
              ['Campus', campusName(selected.campusId)],
              ['Vendor', vendorName(selected.vendorId)],
              ['Pickup point', selected.pickupLocationId ? <Mono key="p">{selected.pickupLocationId}</Mono> : '—'],
              ['Payment method', selected.paymentMethod ?? '—'],
              ['Client ref', selected.clientReference ?? '—'],
              ['Created', new Date(selected.createdAt).toLocaleString()],
            ]}
          />

          <div className="console-card">
            <div className="console-card__head"><h2>Amount breakdown</h2></div>
            <div style={{ padding: '4px 0' }}>
              <Line label="Subtotal" value={money(selected.subtotalMinor, selected.currency)} />
              <Line label="Tax" value={money(selected.taxMinor, selected.currency)} />
              <Line label="Delivery fee" value={money(selected.deliveryFeeMinor, selected.currency)} />
              <Line label="Platform fee" value={money(selected.platformFeeMinor, selected.currency)} />
              {selected.discountMinor > 0 && <Line label="Discount" value={`- ${money(selected.discountMinor, selected.currency)}`} />}
              <Line label="Total" value={money(selected.totalMinor, selected.currency)} strong />
            </div>
          </div>
        </Drawer>
      )}
    </div>
  );
}

function Line({ label, value, strong }: { label: string; value: string; strong?: boolean }) {
  return (
    <div style={{ display: 'flex', justifyContent: 'space-between', padding: '9px 18px', borderTop: '1px solid var(--color-divider)', fontWeight: strong ? 800 : 500, color: strong ? 'var(--color-ink-strong)' : 'var(--color-ink)' }}>
      <span>{label}</span>
      <span style={{ fontVariantNumeric: 'tabular-nums' }}>{value}</span>
    </div>
  );
}

function nameLookup(list?: Named[]) {
  const map = new Map((list ?? []).map((x) => [x.id, x.displayName]));
  return (id?: string | null) => (id ? map.get(id) ?? `${id.slice(0, 8)}…` : '—');
}
