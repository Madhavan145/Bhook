'use client';

import { useQuery } from '@tanstack/react-query';
import { useMemo, useState } from 'react';

import { createClient } from '@/lib/api';
import { API } from '@/lib/config';

import { PageHeader, SegmentedTabs, money } from '../ui';

const financial = createClient(API.financial);
const catalog = createClient(API.catalog);
const orderClient = createClient(API.order);

type LedgerEntry = {
  id: string;
  orderId: string;
  vendorId: string | null;
  entryType: string;
  currency: string;
  amountMinor: number;
  notes: string | null;
  createdAt: string;
};

type Named = { id: string; displayName: string; commissionPercent: number | null };
type OrderLite = { orderId: string; orderNumber: string; vendorId: string; createdAt: string };

const ENTRY_META: Record<string, { color: string; label: string }> = {
  PAYMENT_RECEIVED: { color: '#2563EB', label: 'Customer paid the platform' },
  PLATFORM_COMMISSION: { color: '#A60F2D', label: 'Platform commission earned' },
  VENDOR_PAYABLE: { color: '#16A34A', label: 'Owed to the vendor' },
  DELIVERY_PARTNER_PAYABLE: { color: '#F59E0B', label: 'Owed to the delivery partner' },
  PAYMENT_REFUNDED: { color: '#DC2626', label: 'Refunded to the customer' },
};

export default function FinancePage() {
  const [tab, setTab] = useState('vendor');
  return (
    <div className="console-page">
      <PageHeader eyebrow="Ledger" title="Finance" subtitle="Double-entry booking of every rupee that moves through the platform." />

      <section className="info-panel">
        <h3>How money flows through Bhook</h3>
        <p>
          When a customer pays, the payment service books <b>PAYMENT_RECEIVED</b> against the order. The financial service then
          splits that amount into what the platform keeps (<b>PLATFORM_COMMISSION</b>), what the vendor is owed
          (<b>VENDOR_PAYABLE</b>) and what the delivery partner is owed (<b>DELIVERY_PARTNER_PAYABLE</b>). Refunds reverse the
          relevant entries as negative amounts. A vendor&rsquo;s current balance is simply the sum of their payable entries.
        </p>
      </section>

      <div className="legend">
        {Object.entries(ENTRY_META).map(([k, m]) => (
          <span key={k} className="legend__item"><span className="legend__dot" style={{ background: m.color }} />{k.replaceAll('_', ' ')} — {m.label}</span>
        ))}
      </div>

      <SegmentedTabs value={tab} onChange={setTab} options={[{ value: 'vendor', label: 'By vendor' }, { value: 'order', label: 'By order' }]} />

      {tab === 'vendor' ? <VendorView /> : <OrderView />}
    </div>
  );
}

function VendorView() {
  const [vendorId, setVendorId] = useState('');
  const vendors = useQuery({
    queryKey: ['finance-vendors'],
    queryFn: () => catalog.get('/api/v1/platform/vendors').then((r) => r.data as Named[]),
  });
  return (
    <section className="console-card">
      <div className="console-card__head">
        <div><h2>Vendor payables</h2><div className="console-card__sub">Outstanding balance and the entries behind it</div></div>
        <select className="b-input" style={{ maxWidth: 320 }} value={vendorId} onChange={(e) => setVendorId(e.target.value)}>
          <option value="">Select a vendor…</option>
          {(vendors.data ?? []).map((v) => <option key={v.id} value={v.id}>{v.displayName}</option>)}
        </select>
      </div>
      {vendorId && <div className="info-panel" style={{ margin: '0 18px 12px' }}>
        Configured commission: <strong>{(vendors.data ?? []).find((v) => v.id === vendorId)?.commissionPercent ?? 'Global default'}{(vendors.data ?? []).find((v) => v.id === vendorId)?.commissionPercent != null ? '%' : ''}</strong>
      </div>}
      {!vendorId && <div className="b-empty">Choose a vendor to see their balance and ledger.</div>}
      {vendorId && <VendorPanel vendorId={vendorId} />}
    </section>
  );
}

function OrderView() {
  const [orderId, setOrderId] = useState('');
  const orders = useQuery({
    queryKey: ['finance-orders'],
    queryFn: () => orderClient.get('/api/v1/platform/orders').then((r) => r.data as OrderLite[]),
  });
  const recent = (orders.data ?? []).slice(0, 100);
  return (
    <section className="console-card">
      <div className="console-card__head">
        <div><h2>Order breakdown</h2><div className="console-card__sub">Every entry booked against a single order</div></div>
        <select className="b-input" style={{ maxWidth: 320 }} value={orderId} onChange={(e) => setOrderId(e.target.value)}>
          <option value="">Select an order…</option>
          {recent.map((o) => <option key={o.orderId} value={o.orderId}>{o.orderNumber}</option>)}
        </select>
      </div>
      {!orderId && <div className="b-empty">Choose an order to see how its total was split.</div>}
      {orderId && <OrderPanel orderId={orderId} />}
    </section>
  );
}

function EntryType({ type }: { type: string }) {
  const m = ENTRY_META[type];
  return <span className="s-pill s-pill--neutral" style={m ? { color: m.color, background: `color-mix(in srgb, ${m.color} 12%, transparent)`, borderColor: `color-mix(in srgb, ${m.color} 26%, transparent)` } : undefined}>{type.replaceAll('_', ' ')}</span>;
}

function Amount({ minor, currency }: { minor: number; currency: string }) {
  return <span className={minor < 0 ? 'amount-neg' : 'amount-pos'}>{money(minor, currency)}</span>;
}

function VendorPanel({ vendorId }: { vendorId: string }) {
  const earnings = useQuery({
    queryKey: ['vendor-earnings', vendorId],
    queryFn: () => financial.get(`/api/v1/platform/financial/vendors/${vendorId}/earnings`).then((r) => r.data as { vendorId: string; completedSalesMinor: number; platformCommissionMinor: number; totalPayableMinor: number }),
  });
  const entries = useQuery({
    queryKey: ['vendor-entries', vendorId],
    queryFn: () => financial.get(`/api/v1/platform/financial/vendors/${vendorId}/entries`).then((r) => r.data as LedgerEntry[]),
  });
  if (earnings.isLoading) return <div className="b-empty">Loading…</div>;
  if (earnings.error) return <div className="b-empty">No ledger entries for this vendor yet.</div>;
  const list = entries.data ?? [];
  return (
    <div>
      <div className="metric-strip" style={{ margin: '0 18px 12px' }}>
        <div className="metric-block"><div className="metric-block__hint">Completed sales</div><div className="metric-block__value">{money(earnings.data?.completedSalesMinor ?? 0)}</div></div>
        <div className="metric-block"><div className="metric-block__hint">Platform commission</div><div className="metric-block__value">{money(earnings.data?.platformCommissionMinor ?? 0)}</div></div>
        <div className="metric-block"><div className="metric-block__hint">Vendor payable</div><div className="metric-block__value">{money(earnings.data?.totalPayableMinor ?? 0)}</div></div>
      </div>
      <LedgerTable list={list} column="order" />
    </div>
  );
}

function OrderPanel({ orderId }: { orderId: string }) {
  const entries = useQuery({
    queryKey: ['order-entries', orderId],
    queryFn: () => financial.get(`/api/v1/platform/financial/orders/${orderId}/entries`).then((r) => r.data as LedgerEntry[]),
  });
  if (entries.isLoading) return <div className="b-empty">Loading…</div>;
  const list = entries.data ?? [];
  if (list.length === 0) return <div className="b-empty">No ledger entries booked for this order yet.</div>;
  const net = list.reduce((a, e) => a + e.amountMinor, 0);
  return (
    <div>
      <div style={{ padding: '18px 18px 4px' }}>
        <div className="metric-block__hint" style={{ textTransform: 'uppercase', letterSpacing: '.08em', fontWeight: 800 }}>Net booked</div>
        <div className="big-figure">{money(net)}</div>
      </div>
      <LedgerTable list={list} column="vendor" />
    </div>
  );
}

function LedgerTable({ list, column }: { list: LedgerEntry[]; column: 'order' | 'vendor' }) {
  return (
    <div className="console-table-wrap" style={{ border: 0, borderTop: '1px solid var(--color-divider)', borderRadius: 0 }}>
      <table className="b-table">
        <thead>
          <tr>
            <th>When</th>
            <th>Type</th>
            <th>{column === 'order' ? 'Order' : 'Vendor'}</th>
            <th style={{ textAlign: 'right' }}>Amount</th>
            <th>Notes</th>
          </tr>
        </thead>
        <tbody>
          {list.map((e) => (
            <tr key={e.id}>
              <td style={{ whiteSpace: 'nowrap', color: 'var(--color-ink-muted)' }}>{new Date(e.createdAt).toLocaleString()}</td>
              <td><EntryType type={e.entryType} /></td>
              <td><code className="mono-chip">{(column === 'order' ? e.orderId : e.vendorId)?.slice(0, 8) ?? '—'}…</code></td>
              <td style={{ textAlign: 'right' }}><Amount minor={e.amountMinor} currency={e.currency} /></td>
              <td style={{ color: 'var(--color-ink-muted)' }}>{e.notes ?? ''}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
