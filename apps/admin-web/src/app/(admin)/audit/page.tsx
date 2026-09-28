'use client';

import { useQuery } from '@tanstack/react-query';
import { useState } from 'react';

import { createClient } from '@/lib/api';
import { API } from '@/lib/config';

import { PageHeader } from '../ui';

const operations = createClient(API.operations);

export default function AuditPage() {
  const [eventType, setEventType] = useState('');
  const audit = useQuery({
    queryKey: ['audit', eventType],
    queryFn: () =>
      operations
        .get('/api/v1/platform/audit-log', {
          params: { size: 50, eventType: eventType || undefined },
        })
        .then((r) => r.data),
    refetchInterval: 5_000,
  });

  return (
    <div style={{ display: 'grid', gap: 24 }}>
      <PageHeader
        eyebrow="System"
        title="Audit log"
        subtitle="Live stream of every domain event published to the outbox. Auto-refreshes every 5s."
      />

      <input
        placeholder="Filter by event-type (e.g. order.created)"
        value={eventType}
        onChange={(e) => setEventType(e.target.value)}
        className="b-input"
        style={{ maxWidth: 360, fontFamily: 'ui-monospace, SFMono-Regular, Menlo, monospace' }}
      />

      <section className="b-card" style={{ padding: 0, overflow: 'hidden' }}>
        {audit.isLoading && <div className="b-empty">Loading events…</div>}
        {(audit.data?.content ?? []).length === 0 && !audit.isLoading && (
          <div className="b-empty">No matching events.</div>
        )}
        {(audit.data?.content ?? []).length > 0 && (
          <table className="b-table">
            <thead>
              <tr>
                <th>When</th>
                <th>Event</th>
                <th>Aggregate</th>
                <th>Actor</th>
              </tr>
            </thead>
            <tbody>
              {(audit.data?.content ?? []).map((row: any) => (
                <tr key={row.id}>
                  <td style={{ color: 'var(--color-ink-muted)', whiteSpace: 'nowrap' }}>{row.createdAt}</td>
                  <td>
                    <div style={{ fontFamily: 'ui-monospace, SFMono-Regular, Menlo, monospace', fontWeight: 600, color: 'var(--color-ink-strong)' }}>{row.eventType}</div>
                  </td>
                  <td>
                    <div style={{ fontWeight: 600 }}>{row.aggregateType}</div>
                    <div style={{ color: 'var(--color-ink-faint)', fontSize: 12, marginTop: 2 }}>{row.aggregateId}</div>
                  </td>
                  <td style={{ color: 'var(--color-ink-muted)' }}>{row.actorUserId ?? row.actorType ?? '—'}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </section>
    </div>
  );
}
