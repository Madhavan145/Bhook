'use client';

import { useMutation, useQueries, useQuery, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';

import { createClient } from '@/lib/api';
import { API } from '@/lib/config';

import { Drawer, Field, Metric, PageHeader, StatusPill, money, useToast } from '../ui';

const campus = createClient(API.campus);

type Campus = {
  id: string;
  name: string;
  displayName: string;
  country: string;
  region: string | null;
  timezone: string;
  currency: string;
  status: string;
  deliveryEnabled: boolean;
  hostelPickupEnabled: boolean;
  partnerAccessEnabled: boolean;
  platformFeeMinor: number;
};

type EmailDomain = {
  id: string;
  domain: string;
  membershipType: string;
  autoVerify: boolean;
  status: string;
};

type CampusLocation = { id: string; name: string; locationType: string; instructions: string | null };

export default function CampusesPage() {
  const qc = useQueryClient();
  const toast = useToast();
  const [creating, setCreating] = useState(false);
  const [editing, setEditing] = useState<Campus | null>(null);
  const [deleting, setDeleting] = useState<Campus | null>(null);

  const campuses = useQuery({
    queryKey: ['campuses'],
    queryFn: () => campus.get('/api/v1/campuses').then((r) => r.data as Campus[]),
  });
  const domainQueries = useQueries({
    queries: (campuses.data ?? []).map((c) => ({
      queryKey: ['campus-email-domains', c.id],
      queryFn: () => campus.get(`/api/v1/campuses/${c.id}/email-domains`).then((r) => r.data as EmailDomain[]),
    })),
  });

  const create = useMutation({
    mutationFn: (body: any) => campus.post('/api/v1/campuses', body).then((r) => r.data),
    onSuccess: () => { qc.invalidateQueries({ queryKey: ['campuses'] }); setCreating(false); toast.show('success', 'Campus created'); },
    onError: () => toast.show('error', 'Could not create campus.'),
  });
  const update = useMutation({
    mutationFn: ({ id, body }: { id: string; body: any }) => campus.patch(`/api/v1/campuses/${id}`, body).then((r) => r.data),
    onSuccess: () => { qc.invalidateQueries({ queryKey: ['campuses'] }); setEditing(null); toast.show('success', 'Campus updated'); },
    onError: () => toast.show('error', 'Could not update campus.'),
  });
  const archive = useMutation({
    mutationFn: (id: string) => campus.patch(`/api/v1/campuses/${id}`, { status: 'ARCHIVED' }).then((r) => r.data),
    onSuccess: () => { qc.invalidateQueries({ queryKey: ['campuses'] }); setDeleting(null); toast.show('success', 'Campus archived'); },
    onError: () => toast.show('error', 'Could not archive campus.'),
  });

  const rows = campuses.data ?? [];
  const active = rows.filter((c) => c.status === 'ACTIVE').length;

  return (
    <div className="console-page">
      <PageHeader
        eyebrow="Network"
        title="Campuses"
        subtitle="Manage campus tenants, delivery zones and feature access."
        actions={<button className="b-btn b-btn--primary" onClick={() => setCreating(true)}>New campus</button>}
      />

      <div className="metric-strip">
        <Metric label="Campuses" value={rows.length} />
        <Metric label="Active" value={active} tone="success" />
        <Metric label="Delivery enabled" value={rows.filter((c) => c.deliveryEnabled).length} />
        <Metric label="Hostel pickup" value={rows.filter((c) => c.hostelPickupEnabled).length} />
      </div>

      <section className="console-table-wrap">
        <table className="b-table">
          <thead>
            <tr>
              <th>Campus</th>
              <th>Email domains</th>
              <th>Country</th>
              <th>Timezone</th>
              <th>Currency</th>
              <th>Features</th>
              <th>Platform fee</th>
              <th>Status</th>
              <th style={{ textAlign: 'right' }}>Actions</th>
            </tr>
          </thead>
          <tbody>
            {campuses.isLoading && <tr><td colSpan={9} className="b-empty">Loading campuses…</td></tr>}
            {!campuses.isLoading && rows.length === 0 && <tr><td colSpan={9} className="b-empty">No campuses yet.</td></tr>}
            {rows.map((c, index) => (
              <tr key={c.id}>
                <td><strong>{c.displayName}</strong><small>{c.name}</small></td>
                <td>{(domainQueries[index]?.data ?? []).map((item) => item.domain).join(', ') || '—'}</td>
                <td>{c.country}{c.region ? ` · ${c.region}` : ''}</td>
                <td>{c.timezone}</td>
                <td>{c.currency}</td>
                <td>
                  <div style={{ display: 'flex', gap: 4, flexWrap: 'wrap' }}>
                    {c.deliveryEnabled && <span className="mono-chip">delivery</span>}
                    {c.hostelPickupEnabled && <span className="mono-chip">hostel</span>}
                    {c.partnerAccessEnabled && <span className="mono-chip">partners</span>}
                  </div>
                </td>
                <td>{money(c.platformFeeMinor ?? 1000, c.currency)}</td>
                <td><StatusPill status={c.status} /></td>
                <td style={{ textAlign: 'right' }}>
                  <div style={{ display: 'inline-flex', gap: 6 }}>
                    <button className="b-btn b-btn--ghost" style={{ padding: '6px 12px', fontSize: 12 }} onClick={() => setEditing(c)}>Edit</button>
                    <button className="b-btn b-btn--ghost" style={{ padding: '6px 12px', fontSize: 12, color: 'var(--color-danger)' }} onClick={() => setDeleting(c)}>Delete</button>
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </section>

      {creating && <CreateCampusForm onSubmit={(body) => create.mutate(body)} onCancel={() => setCreating(false)} busy={create.isPending} />}
      {editing && <EditCampusDrawer
        campus={editing}
        domains={domainQueries[campuses.data?.findIndex((c) => c.id === editing.id) ?? -1]?.data ?? []}
        busy={update.isPending}
        onClose={() => setEditing(null)}
        onDomainsChanged={() => qc.invalidateQueries({ queryKey: ['campus-email-domains', editing.id] })}
        onSave={(body) => update.mutate({ id: editing.id, body })}
      />}
      {deleting && (
        <div className="modal-backdrop" role="presentation" onMouseDown={(e) => { if (e.target === e.currentTarget) setDeleting(null); }}>
          <div className="modal-panel">
            <div className="modal-kicker">Archive campus</div>
            <h2>Archive {deleting.displayName}?</h2>
            <p className="modal-copy">Archiving removes the campus from the active roster and hides it from onboarding. Existing vendors, staff and orders are preserved. You can restore it later by setting its status back to Active.</p>
            <div className="modal-actions">
              <button className="b-btn b-btn--ghost" onClick={() => setDeleting(null)}>Cancel</button>
              <button className="b-btn b-btn--danger" disabled={archive.isPending} onClick={() => archive.mutate(deleting.id)}>{archive.isPending ? 'Archiving…' : 'Archive campus'}</button>
            </div>
          </div>
        </div>
      )}

      {toast.node}
    </div>
  );
}

function EditCampusDrawer({ campus, domains, busy, onClose, onDomainsChanged, onSave }: { campus: Campus; domains: EmailDomain[]; busy: boolean; onClose: () => void; onDomainsChanged: () => void; onSave: (body: any) => void }) {
  const campusApi = createClient(API.campus);
  const [displayName, setDisplayName] = useState(campus.displayName ?? '');
  const [name, setName] = useState(campus.name ?? '');
  const [country, setCountry] = useState(campus.country ?? '');
  const [region, setRegion] = useState(campus.region ?? '');
  const [timezone, setTimezone] = useState(campus.timezone ?? '');
  const [currency, setCurrency] = useState(campus.currency ?? '');
  const [status, setStatus] = useState(campus.status ?? 'ACTIVE');
  const [deliveryEnabled, setDeliveryEnabled] = useState(campus.deliveryEnabled);
  const [hostelPickupEnabled, setHostelPickupEnabled] = useState(campus.hostelPickupEnabled);
  const [partnerAccessEnabled, setPartnerAccessEnabled] = useState(campus.partnerAccessEnabled);
  const [platformFee, setPlatformFee] = useState(((campus.platformFeeMinor ?? 1000) / 100).toFixed(2));
  const [domain, setDomain] = useState('');
  const [domainType, setDomainType] = useState('STUDENT');
  const [domainBusy, setDomainBusy] = useState(false);
  const [locationName, setLocationName] = useState('');
  const [locationType, setLocationType] = useState('HOSTEL');
  const [locationInstructions, setLocationInstructions] = useState('');
  const [editingLocation, setEditingLocation] = useState<CampusLocation | null>(null);
  const locations = useQuery({
    queryKey: ['campus-locations', campus.id],
    queryFn: () => campusApi.get(`/api/v1/campuses/${campus.id}/locations`).then((r) => r.data as CampusLocation[]),
  });
  const addLocation = useMutation({
    mutationFn: () => campusApi.post(`/api/v1/campuses/${campus.id}/locations`, {
      name: locationName.trim(), locationType, instructions: locationInstructions.trim() || undefined,
    }),
    onSuccess: () => { setLocationName(''); setLocationInstructions(''); locations.refetch(); },
  });
  const saveLocation = useMutation({
    mutationFn: () => campusApi.patch(`/api/v1/campuses/${campus.id}/locations/${editingLocation?.id}`, {
      name: locationName.trim(), locationType, instructions: locationInstructions.trim(),
    }),
    onSuccess: () => { setEditingLocation(null); setLocationName(''); setLocationInstructions(''); locations.refetch(); },
  });
  const deleteLocation = useMutation({
    mutationFn: (id: string) => campusApi.delete(`/api/v1/campuses/${campus.id}/locations/${id}`),
    onSuccess: () => locations.refetch(),
  });

  async function addDomain() {
    const value = domain.trim().toLowerCase();
    if (!value) return;
    setDomainBusy(true);
    try {
      await campusApi.post(`/api/v1/campuses/${campus.id}/email-domains`, {
        domain: value,
        membershipType: domainType,
        autoVerify: true,
      });
      setDomain('');
      onDomainsChanged();
    } finally {
      setDomainBusy(false);
    }
  }

  async function removeDomain(id: string) {
    setDomainBusy(true);
    try {
      await campusApi.delete(`/api/v1/campuses/${campus.id}/email-domains/${id}`);
      onDomainsChanged();
    } finally {
      setDomainBusy(false);
    }
  }

  return (
    <Drawer eyebrow="Edit campus" title={campus.displayName} onClose={onClose} width={520}
      footer={<>
        <button className="b-btn b-btn--ghost" onClick={onClose}>Cancel</button>
        <button className="b-btn b-btn--primary" disabled={busy} onClick={() => onSave({ displayName, name, country, region, timezone, currency, status, deliveryEnabled, hostelPickupEnabled, partnerAccessEnabled, platformFeeMinor: Math.round(Number(platformFee) * 100) })}>{busy ? 'Saving…' : 'Save changes'}</button>
      </>}>
      <div style={{ display: 'grid', gap: 12 }}>
        <Field label="Display name"><input className="b-input" value={displayName} onChange={(e) => setDisplayName(e.target.value)} /></Field>
        <Field label="Short name"><input className="b-input" value={name} onChange={(e) => setName(e.target.value)} /></Field>
        <div style={{ display: 'grid', gap: 12, gridTemplateColumns: '1fr 1fr' }}>
          <Field label="Country"><input className="b-input" value={country} onChange={(e) => setCountry(e.target.value)} /></Field>
          <Field label="Region"><input className="b-input" value={region} onChange={(e) => setRegion(e.target.value)} /></Field>
          <Field label="Timezone"><input className="b-input" value={timezone} onChange={(e) => setTimezone(e.target.value)} /></Field>
          <Field label="Currency"><input className="b-input" value={currency} onChange={(e) => setCurrency(e.target.value)} /></Field>
            <Field label="Platform fee" hint="Amount in major currency units. Default ₹10."><input className="b-input" type="number" min="0" step="0.50" value={platformFee} onChange={(e) => setPlatformFee(e.target.value)} /></Field>
        </div>
        <Field label="Status"><select className="b-input" value={status} onChange={(e) => setStatus(e.target.value)}>{['ACTIVE', 'SUSPENDED', 'ARCHIVED'].map((s) => <option key={s}>{s}</option>)}</select></Field>
        <div style={{ display: 'grid', gap: 8, paddingTop: 4 }}>
          <Toggle label="Delivery enabled" checked={deliveryEnabled} onChange={setDeliveryEnabled} />
          <Toggle label="Hostel pickup enabled" checked={hostelPickupEnabled} onChange={setHostelPickupEnabled} />
          <Toggle label="Partner access enabled" checked={partnerAccessEnabled} onChange={setPartnerAccessEnabled} />
        </div>
        <div style={{ display: 'grid', gap: 8, paddingTop: 8, borderTop: '1px solid var(--color-line)' }}>
          <Field label="Email domains">
            <div style={{ display: 'grid', gap: 8 }}>
              {domains.map((item) => (
                <div key={item.id} style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 8 }}>
                  <span><strong>{item.domain}</strong><small style={{ display: 'block' }}>{item.membershipType} · {item.autoVerify ? 'auto verify' : 'manual verify'}</small></span>
                  <button type="button" className="b-btn b-btn--ghost" disabled={domainBusy} onClick={() => removeDomain(item.id)} style={{ padding: '5px 9px', color: 'var(--color-danger)' }}>Remove</button>
                </div>
              ))}
              {domains.length === 0 && <small>No email domains configured.</small>}
              <div style={{ display: 'grid', gridTemplateColumns: '1fr auto auto', gap: 8 }}>
                <input className="b-input" value={domain} onChange={(e) => setDomain(e.target.value)} placeholder="vitstudent.ac.in" />
                <select className="b-input" value={domainType} onChange={(e) => setDomainType(e.target.value)}>
                  {['STUDENT', 'POSTGRADUATE', 'PHD_SCHOLAR', 'FACULTY', 'STAFF', 'RESIDENT', 'OTHER'].map((type) => <option key={type}>{type}</option>)}
                </select>
                <button type="button" className="b-btn b-btn--ghost" disabled={domainBusy || !domain.trim()} onClick={addDomain}>Add</button>
              </div>
            </div>
          </Field>
        </div>
        <div style={{ display: 'grid', gap: 8, paddingTop: 8, borderTop: '1px solid var(--color-line)' }}>
          <Field label="Delivery blocks / locations" hint="Customers will select these during checkout.">
            <div style={{ display: 'grid', gap: 8 }}>
              {(locations.data ?? []).map((location) => (
                <div key={location.id} style={{ display: 'flex', justifyContent: 'space-between', gap: 8, alignItems: 'center' }}>
                  <span><strong>{location.name}</strong><small style={{ display: 'block' }}>{location.locationType.replaceAll('_', ' ')}</small></span>
                  <span style={{ display: 'inline-flex', gap: 6 }}>
                    <button type="button" className="b-btn b-btn--ghost" style={{ padding: '5px 9px' }} onClick={() => { setEditingLocation(location); setLocationName(location.name); setLocationType(location.locationType); setLocationInstructions(location.instructions ?? ''); }}>Edit</button>
                    <button type="button" className="b-btn b-btn--ghost" style={{ padding: '5px 9px', color: 'var(--color-danger)' }} disabled={deleteLocation.isPending} onClick={() => { if (window.confirm(`Delete ${location.name}?`)) deleteLocation.mutate(location.id); }}>Delete</button>
                  </span>
                </div>
              ))}
              {locations.data?.length === 0 && <small>No delivery blocks configured.</small>}
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 150px', gap: 8 }}>
                <input className="b-input" value={locationName} onChange={(e) => setLocationName(e.target.value)} placeholder="Men's Hostel F Block" />
                <select className="b-input" value={locationType} onChange={(e) => setLocationType(e.target.value)}>
                  {['HOSTEL', 'BUILDING', 'PICKUP_POINT', 'GATE', 'ZONE', 'OTHER'].map((type) => <option key={type} value={type}>{type.replaceAll('_', ' ')}</option>)}
                </select>
              </div>
              <input className="b-input" value={locationInstructions} onChange={(e) => setLocationInstructions(e.target.value)} placeholder="Delivery instructions (optional)" />
              <button type="button" className="b-btn b-btn--ghost" disabled={!locationName.trim() || addLocation.isPending || saveLocation.isPending} onClick={() => editingLocation ? saveLocation.mutate() : addLocation.mutate()}>{editingLocation ? (saveLocation.isPending ? 'Saving…' : 'Save location') : (addLocation.isPending ? 'Adding…' : 'Add location')}</button>
              {editingLocation && <button type="button" className="link-btn" onClick={() => { setEditingLocation(null); setLocationName(''); setLocationInstructions(''); }}>Cancel edit</button>}
            </div>
          </Field>
        </div>
      </div>
    </Drawer>
  );
}

function Toggle({ label, checked, onChange }: { label: string; checked: boolean; onChange: (v: boolean) => void }) {
  return (
    <label style={{ display: 'flex', alignItems: 'center', gap: 10, fontSize: 13, fontWeight: 600, color: 'var(--color-ink)' }}>
      <input type="checkbox" checked={checked} onChange={(e) => onChange(e.target.checked)} />
      {label}
    </label>
  );
}

function CreateCampusForm({
  onSubmit,
  onCancel,
  busy,
}: {
  onSubmit: (body: any) => void;
  onCancel: () => void;
  busy: boolean;
}) {
  const [name, setName] = useState('');
  const [displayName, setDisplayName] = useState('');
  const [country, setCountry] = useState('IN');
  const [timezone, setTimezone] = useState('Asia/Kolkata');
  const [currency, setCurrency] = useState('INR');
  const [domains, setDomains] = useState<{ domain: string; membershipType: string; autoVerify: boolean }[]>([
    { domain: '', membershipType: 'STUDENT', autoVerify: true },
  ]);

  return (
    <div className="modal-backdrop" role="presentation" onMouseDown={(e) => { if (e.target === e.currentTarget) onCancel(); }}>
      <form
        className="modal-panel"
        onSubmit={(e) => {
          e.preventDefault();
          onSubmit({
            name, displayName, country, timezone, currency,
            status: 'ACTIVE', deliveryEnabled: true, hostelPickupEnabled: true, partnerAccessEnabled: true,
            emailDomains: domains.filter((d) => d.domain.trim().length > 0),
          });
        }}
        style={{ width: 'min(560px, 100%)' }}
      >
        <div className="modal-kicker">New tenant</div>
        <h2>Create a campus</h2>
        <div style={{ display: 'grid', gap: 12, gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))' }}>
          <Field label="Short name"><input required value={name} onChange={(e) => setName(e.target.value)} className="b-input" placeholder="vit-vellore" /></Field>
          <Field label="Display name"><input required value={displayName} onChange={(e) => setDisplayName(e.target.value)} className="b-input" placeholder="VIT Vellore" /></Field>
          <Field label="Country"><input required value={country} onChange={(e) => setCountry(e.target.value)} className="b-input" /></Field>
          <Field label="Timezone"><input required value={timezone} onChange={(e) => setTimezone(e.target.value)} className="b-input" /></Field>
          <Field label="Currency"><input required value={currency} onChange={(e) => setCurrency(e.target.value)} className="b-input" /></Field>
        </div>
        <div>
          <div style={{ fontWeight: 700, margin: '8px 0', fontSize: 13 }}>Email domains</div>
          {domains.map((d, i) => (
            <div key={i} style={{ display: 'grid', gridTemplateColumns: '2fr 1fr auto auto', gap: 8, marginBottom: 8, alignItems: 'center' }}>
              <input placeholder="vitstudent.ac.in" value={d.domain} onChange={(e) => { const next = [...domains]; next[i] = { ...next[i], domain: e.target.value }; setDomains(next); }} className="b-input" />
              <select value={d.membershipType} onChange={(e) => { const next = [...domains]; next[i] = { ...next[i], membershipType: e.target.value }; setDomains(next); }} className="b-input">
                {['STUDENT', 'POSTGRADUATE', 'PHD_SCHOLAR', 'FACULTY', 'STAFF', 'RESIDENT', 'OTHER'].map((t) => <option key={t}>{t}</option>)}
              </select>
              <label style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: 12 }}>
                <input type="checkbox" checked={d.autoVerify} onChange={(e) => { const next = [...domains]; next[i] = { ...next[i], autoVerify: e.target.checked }; setDomains(next); }} />
                auto
              </label>
              <button type="button" onClick={() => setDomains(domains.filter((_, j) => j !== i))} className="b-btn b-btn--ghost" style={{ padding: '6px 10px' }}>✕</button>
            </div>
          ))}
          <button type="button" className="b-btn b-btn--ghost" style={{ padding: '6px 12px', fontSize: 12 }} onClick={() => setDomains([...domains, { domain: '', membershipType: 'STUDENT', autoVerify: true }])}>+ Add domain</button>
        </div>
        <div className="modal-actions">
          <button type="button" onClick={onCancel} className="b-btn b-btn--ghost">Cancel</button>
          <button type="submit" disabled={busy} className="b-btn b-btn--primary">{busy ? 'Saving…' : 'Create campus'}</button>
        </div>
      </form>
    </div>
  );
}
