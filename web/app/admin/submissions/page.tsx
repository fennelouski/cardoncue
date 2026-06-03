'use client';

import { useState, useEffect, useCallback } from 'react';

interface Submission {
  id: string;
  cardId: string;
  cardName: string;
  cardType?: string;
  networkIds: string[];
  locationName: string;
  address?: string;
  city?: string;
  state?: string;
  latitude: number | null;
  longitude: number | null;
  notes?: string;
  status: string;
  source: string;
  suggestedNetworkId?: string;
  reportCount: number;
  createdAt: string;
}

interface CuratedNetwork {
  id: string;
  name: string;
  locationCount: number;
}

export default function SubmissionsPage() {
  const [submissions, setSubmissions] = useState<Submission[]>([]);
  const [networks, setNetworks] = useState<CuratedNetwork[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [statusFilter, setStatusFilter] = useState('pending');
  const [searchTerm, setSearchTerm] = useState('');
  const [approvingId, setApprovingId] = useState<string | null>(null);
  const [approveForm, setApproveForm] = useState({
    networkId: '',
    networkName: '',
    radiusMeters: 100,
    displayName: '',
  });

  const fetchSubmissions = useCallback(async () => {
    try {
      setLoading(true);
      setError(null);
      const params = new URLSearchParams({
        status: statusFilter,
        limit: '100',
      });
      if (searchTerm.trim()) {
        params.set('search', searchTerm.trim());
      }

      const [subRes, netRes] = await Promise.all([
        fetch(`/api/v1/admin/location-submissions?${params}`),
        fetch('/api/v1/admin/curated-networks'),
      ]);

      if (!subRes.ok) {
        const data = await subRes.json().catch(() => ({}));
        throw new Error(data.error || 'Failed to load submissions');
      }

      const subData = await subRes.json();
      setSubmissions(subData.submissions || []);

      if (netRes.ok) {
        const netData = await netRes.json();
        setNetworks(netData.networks || []);
      }
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : 'Failed to load');
    } finally {
      setLoading(false);
    }
  }, [statusFilter, searchTerm]);

  useEffect(() => {
    fetchSubmissions();
  }, [fetchSubmissions]);

  const openApprove = (sub: Submission) => {
    const suggested =
      sub.suggestedNetworkId ||
      sub.networkIds[0] ||
      '';
    const network = networks.find((n) => n.id === suggested);
    setApprovingId(sub.id);
    setApproveForm({
      networkId: suggested,
      networkName: network?.name || '',
      radiusMeters: 100,
      displayName: sub.locationName,
    });
  };

  const handleApprove = async () => {
    if (!approvingId || !approveForm.networkId.trim()) {
      alert('Network ID is required');
      return;
    }

    try {
      const response = await fetch(
        `/api/v1/admin/location-submissions/${approvingId}/approve`,
        {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            networkId: approveForm.networkId.trim(),
            networkName: approveForm.networkName.trim() || undefined,
            radiusMeters: approveForm.radiusMeters,
            displayName: approveForm.displayName.trim() || undefined,
          }),
        }
      );

      if (!response.ok) {
        const data = await response.json();
        throw new Error(data.error || 'Approve failed');
      }

      setApprovingId(null);
      await fetchSubmissions();
    } catch (err: unknown) {
      alert(err instanceof Error ? err.message : 'Approve failed');
    }
  };

  const handleReject = async (id: string, asDuplicate: boolean) => {
    const reason = asDuplicate
      ? 'Marked as duplicate'
      : prompt('Rejection reason (optional)') || '';

    try {
      const response = await fetch(
        `/api/v1/admin/location-submissions/${id}/reject`,
        {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            status: asDuplicate ? 'duplicate' : 'rejected',
            reason,
          }),
        }
      );

      if (!response.ok) {
        const data = await response.json();
        throw new Error(data.error || 'Reject failed');
      }

      await fetchSubmissions();
    } catch (err: unknown) {
      alert(err instanceof Error ? err.message : 'Reject failed');
    }
  };

  const mapsLink = (lat: number | null, lon: number | null) => {
    if (lat == null || lon == null) return null;
    return `https://www.google.com/maps?q=${lat},${lon}`;
  };

  return (
    <div className="px-4 sm:px-0">
      <div className="sm:flex sm:items-center sm:justify-between mb-8">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Location Submissions</h1>
          <p className="mt-1 text-sm text-gray-500">
            User-reported places awaiting approval into curated network locations.
          </p>
        </div>
      </div>

      <div className="mb-6 flex flex-wrap gap-4 items-end">
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">Status</label>
          <select
            value={statusFilter}
            onChange={(e) => setStatusFilter(e.target.value)}
            className="rounded-md border-gray-300 shadow-sm"
          >
            <option value="pending">Pending</option>
            <option value="approved">Approved</option>
            <option value="rejected">Rejected</option>
            <option value="duplicate">Duplicate</option>
            <option value="all">All</option>
          </select>
        </div>
        <div className="flex-1 min-w-[200px]">
          <label className="block text-sm font-medium text-gray-700 mb-1">Search</label>
          <input
            type="text"
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            placeholder="Card or place name..."
            className="w-full rounded-md border-gray-300 shadow-sm"
          />
        </div>
        <button
          type="button"
          onClick={() => fetchSubmissions()}
          className="px-4 py-2 bg-blue-600 text-white rounded-md text-sm font-medium hover:bg-blue-700"
        >
          Refresh
        </button>
      </div>

      {error && (
        <div className="mb-4 p-4 bg-red-50 text-red-700 rounded-md">{error}</div>
      )}

      {loading ? (
        <p className="text-gray-500">Loading...</p>
      ) : submissions.length === 0 ? (
        <p className="text-gray-500">No submissions found.</p>
      ) : (
        <div className="overflow-x-auto shadow ring-1 ring-black ring-opacity-5 rounded-lg">
          <table className="min-w-full divide-y divide-gray-300">
            <thead className="bg-gray-50">
              <tr>
                <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                  Card
                </th>
                <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                  Place
                </th>
                <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                  Reports
                </th>
                <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                  Network hint
                </th>
                <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">
                  Status
                </th>
                <th className="px-4 py-3 text-right text-xs font-medium text-gray-500 uppercase">
                  Actions
                </th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-200 bg-white">
              {submissions.map((sub) => (
                <tr key={sub.id}>
                  <td className="px-4 py-3 text-sm">
                    <div className="font-medium text-gray-900">{sub.cardName}</div>
                    <div className="text-gray-500 text-xs">{sub.source}</div>
                  </td>
                  <td className="px-4 py-3 text-sm">
                    <div className="font-medium">{sub.locationName}</div>
                    {sub.address && (
                      <div className="text-gray-500 text-xs">{sub.address}</div>
                    )}
                    {sub.latitude != null && sub.longitude != null && (
                      <a
                        href={mapsLink(sub.latitude, sub.longitude) || '#'}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="text-blue-600 text-xs hover:underline"
                      >
                        {sub.latitude.toFixed(5)}, {sub.longitude.toFixed(5)}
                      </a>
                    )}
                  </td>
                  <td className="px-4 py-3 text-sm">{sub.reportCount}</td>
                  <td className="px-4 py-3 text-sm text-gray-600">
                    {sub.suggestedNetworkId || sub.networkIds.join(', ') || '—'}
                  </td>
                  <td className="px-4 py-3 text-sm">
                    <span
                      className={`inline-flex px-2 py-0.5 rounded text-xs font-medium ${
                        sub.status === 'pending'
                          ? 'bg-yellow-100 text-yellow-800'
                          : sub.status === 'approved'
                            ? 'bg-green-100 text-green-800'
                            : 'bg-gray-100 text-gray-800'
                      }`}
                    >
                      {sub.status}
                    </span>
                  </td>
                  <td className="px-4 py-3 text-sm text-right space-x-2">
                    {sub.status === 'pending' && (
                      <>
                        <button
                          type="button"
                          onClick={() => openApprove(sub)}
                          className="text-green-600 hover:text-green-800 font-medium"
                        >
                          Approve
                        </button>
                        <button
                          type="button"
                          onClick={() => handleReject(sub.id, false)}
                          className="text-red-600 hover:text-red-800 font-medium"
                        >
                          Reject
                        </button>
                        <button
                          type="button"
                          onClick={() => handleReject(sub.id, true)}
                          className="text-gray-600 hover:text-gray-800 font-medium"
                        >
                          Duplicate
                        </button>
                      </>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}

      {approvingId && (
        <div className="fixed inset-0 bg-black/40 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-lg shadow-xl max-w-md w-full p-6">
            <h2 className="text-lg font-semibold mb-4">Approve location</h2>
            <div className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Network ID
                </label>
                <input
                  list="network-ids"
                  value={approveForm.networkId}
                  onChange={(e) => {
                    const id = e.target.value;
                    const net = networks.find((n) => n.id === id);
                    setApproveForm((f) => ({
                      ...f,
                      networkId: id,
                      networkName: net?.name || f.networkName,
                    }));
                  }}
                  className="w-full rounded-md border-gray-300"
                  placeholder="e.g. costco"
                />
                <datalist id="network-ids">
                  {networks.map((n) => (
                    <option key={n.id} value={n.id}>
                      {n.name}
                    </option>
                  ))}
                </datalist>
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Network display name
                </label>
                <input
                  value={approveForm.networkName}
                  onChange={(e) =>
                    setApproveForm((f) => ({ ...f, networkName: e.target.value }))
                  }
                  className="w-full rounded-md border-gray-300"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Place display name
                </label>
                <input
                  value={approveForm.displayName}
                  onChange={(e) =>
                    setApproveForm((f) => ({ ...f, displayName: e.target.value }))
                  }
                  className="w-full rounded-md border-gray-300"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Radius (meters)
                </label>
                <input
                  type="number"
                  value={approveForm.radiusMeters}
                  onChange={(e) =>
                    setApproveForm((f) => ({
                      ...f,
                      radiusMeters: parseInt(e.target.value, 10) || 100,
                    }))
                  }
                  className="w-full rounded-md border-gray-300"
                />
              </div>
            </div>
            <div className="mt-6 flex justify-end gap-3">
              <button
                type="button"
                onClick={() => setApprovingId(null)}
                className="px-4 py-2 text-gray-700 border rounded-md"
              >
                Cancel
              </button>
              <button
                type="button"
                onClick={handleApprove}
                className="px-4 py-2 bg-green-600 text-white rounded-md hover:bg-green-700"
              >
                Approve & publish
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
