'use client';

import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';

import { createClient } from '@/lib/api';
import { API } from '@/lib/config';

import { PageHeader, StatusPill } from '../ui';

const customer = createClient(API.customer);

type Verification = {
  id: string;
  membershipId: string;
  campusId: string;
  submittedEmail: string;
  domainMatch: string | null;
  matchedMembership: string | null;
  autoVerified: boolean;
  status: string;
  createdAt: string;
};

const STATUSES = ['PENDING_REVIEW', 'MANUAL_REQUIRED', 'AUTO_VERIFIED', 'APPROVED', 'REJECTED'];

export default function VerificationsPage() {
  const qc = useQueryClient();
  const [status, setStatus] = useState('PENDING_REVIEW');
  const list = useQuery({
    queryKey: ['verifications', status],
    queryFn: () =>
      customer
        .get('/api/v1/platform/verifications', { params: { status } })
        .then((r) => r.data as Verification[]),
  });
  const decide = useMutation({
    mutationFn: ({ id, approve }: { id: string; approve: boolean }) =>
      customer
        .post(`/api/v1/platform/verifications/${id}/decision`, {
          approve,
          notes: approve ? 'Approved from admin console' : 'Rejected from admin console',
        })
        .then((r) => r.data),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['verifications', status] }),
  });

  return (
    <div style={{ display: 'grid', gap: 24 }}>
      <PageHeader
        eyebrow="Trust & safety"
        title="Verifications"
        subtitle="Manual review queue for hostellers whose email domain didn't match a whitelisted campus rule."
      />

      <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
        {STATUSES.map((s) => {
          const active = status === s;
          return (
            <button
              key={s}
              onClick={() => setStatus(s)}
              style={{
                padding: '8px 14px',
                borderRadius: 999,
                border: `1px solid ${active ? 'var(--color-primary)' : 'var(--color-divider)'}`,
                cursor: 'pointer',
                fontSize: 12,
                fontWeight: 700,
                background: active ? 'var(--color-primary)' : 'var(--color-card)',
                color: active ? 'white' : 'var(--color-ink)',
                letterSpacing: 0.4,
              }}
            >
              {s.replace(/_/g, ' ')}
            </button>
          );
        })}
      </div>

      <section className="b-card" style={{ padding: 0, overflow: 'hidden' }}>
        {list.isLoading && <div className="b-empty">Loading verifications…</div>}
        {!list.isLoading && (list.data?.length ?? 0) === 0 && (
          <div className="b-empty">Nothing in {status.replace(/_/g, ' ').toLowerCase()}.</div>
        )}
        {(list.data?.length ?? 0) > 0 && (
          <table className="b-table">
            <thead>
              <tr>
                <th>Submitted email</th>
                <th>Domain match</th>
                <th>Membership</th>
                <th>Auto</th>
                <th>Status</th>
                <th style={{ textAlign: 'right' }}>Actions</th>
              </tr>
            </thead>
            <tbody>
              {(list.data ?? []).map((v) => (
                <tr key={v.id}>
                  <td>
                    <div style={{ fontWeight: 700, color: 'var(--color-ink-strong)' }}>{v.submittedEmail}</div>
                    <div style={{ color: 'var(--color-ink-faint)', fontSize: 12, marginTop: 2 }}>{v.createdAt}</div>
                  </td>
                  <td>{v.domainMatch ?? '—'}</td>
                  <td>{v.matchedMembership ?? '—'}</td>
                  <td>
                    {v.autoVerified ? (
                      <span className="b-pill b-pill--success">Auto</span>
                    ) : (
                      <span className="b-pill b-pill--neutral">Manual</span>
                    )}
                  </td>
                  <td><StatusPill status={v.status} /></td>
                  <td style={{ textAlign: 'right' }}>
                    {(v.status === 'PENDING_REVIEW' || v.status === 'MANUAL_REQUIRED') && (
                      <div style={{ display: 'inline-flex', gap: 6 }}>
                        <button
                          className="b-btn b-btn--ghost"
                          style={{ padding: '6px 12px', fontSize: 12 }}
                          onClick={() => decide.mutate({ id: v.id, approve: false })}
                        >
                          Reject
                        </button>
                        <button
                          className="b-btn b-btn--primary"
                          style={{ padding: '6px 12px', fontSize: 12 }}
                          onClick={() => decide.mutate({ id: v.id, approve: true })}
                        >
                          Approve
                        </button>
                      </div>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </section>
    </div>
  );
}
