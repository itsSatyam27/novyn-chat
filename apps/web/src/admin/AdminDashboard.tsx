import { useEffect, useState } from 'react';
import {
  Activity,
  ArrowUpRight,
  Clock3,
  Inbox,
  MessageSquare,
  MessagesSquare,
  RefreshCw,
  Search,
  ShieldCheck,
  Users,
  UsersRound,
} from 'lucide-react';
import { apiRequest } from '../services/api';

interface AdminDashboardData {
  generatedAt: string;
  admin: { username: string; email: string };
  metrics: {
    registeredUsers: number;
    onlineUsers: number;
    newUsersLast7Days: number;
    conversations: number;
    messages: number;
    groups: number;
    feedback: number;
  };
  users: Array<{
    username: string;
    displayName: string;
    email: string;
    createdAt: string;
    lastSeenAt: string;
    isGoogleUser: boolean;
    isOnline: boolean;
  }>;
  feedback: Array<{
    id: string;
    type: string;
    message: string;
    rating: number | null;
    email: string;
    fromUser: string;
    createdAt: string;
  }>;
}

function formatDate(value: string): string {
  const date = new Date(value);
  return Number.isNaN(date.getTime())
    ? 'Not available'
    : new Intl.DateTimeFormat(undefined, { dateStyle: 'medium', timeStyle: 'short' }).format(date);
}

function MetricCard({
  label,
  value,
  detail,
  icon: Icon,
}: {
  label: string;
  value: number;
  detail: string;
  icon: typeof Users;
}) {
  return (
    <article className="admin-metric">
      <div className="admin-metric-top">
        <span>{label}</span>
        <Icon size={18} aria-hidden="true" />
      </div>
      <strong>{value.toLocaleString()}</strong>
      <small>{detail}</small>
    </article>
  );
}

export function AdminDashboard() {
  const [data, setData] = useState<AdminDashboardData | null>(null);
  const [error, setError] = useState('');
  const [status, setStatus] = useState(0);
  const [loading, setLoading] = useState(true);
  const [query, setQuery] = useState('');

  const loadDashboard = async () => {
    const response = await apiRequest<AdminDashboardData & { error?: string }>('/api/admin/dashboard');
    if (!response.ok) {
      setStatus(response.status);
      setError(response.data?.error || 'Could not load the admin dashboard.');
      setLoading(false);
      return;
    }
    setData(response.data);
    setError('');
    setStatus(200);
    setLoading(false);
  };

  useEffect(() => {
    void loadDashboard();
    const intervalId = window.setInterval(() => void loadDashboard(), 30_000);
    return () => window.clearInterval(intervalId);
  }, []);

  const filteredUsers = (data?.users || []).filter((user) => {
    const searchable = `${user.username} ${user.displayName} ${user.email}`.toLowerCase();
    return searchable.includes(query.trim().toLowerCase());
  });

  if (loading) {
    return <main className="admin-state"><RefreshCw className="admin-spin" /> Loading admin dashboard…</main>;
  }

  if (error && !data) {
    const needsSignIn = status === 401;
    return (
      <main className="admin-state">
        <ShieldCheck size={30} />
        <h1>{needsSignIn ? 'Sign in required' : status === 403 ? 'Admin access only' : 'Dashboard unavailable'}</h1>
        <p>{needsSignIn ? 'Sign in to your Novyn account, then return to this page.' : error}</p>
        {needsSignIn && <a className="admin-button" href="/">Open Novyn <ArrowUpRight size={16} /></a>}
      </main>
    );
  }

  if (!data) return null;

  const metrics = data.metrics;
  return (
    <main className="admin-shell">
      <header className="admin-header">
        <div className="admin-brand">
          <div className="admin-brand-mark"><Activity size={20} /></div>
          <div>
            <p>Novyn</p>
            <h1>App monitor</h1>
          </div>
        </div>
        <div className="admin-header-actions">
          <span className="admin-account">{data.admin.email}</span>
          <button className="admin-button admin-refresh" onClick={() => void loadDashboard()} type="button">
            <RefreshCw size={16} /> Refresh
          </button>
          <a className="admin-icon-button" href="/" aria-label="Open Novyn app"><ArrowUpRight size={18} /></a>
        </div>
      </header>

      <section className="admin-content">
        <div className="admin-welcome">
          <div>
            <p className="admin-eyebrow">OVERVIEW</p>
            <h2>Welcome, {data.admin.username}</h2>
            <p className="admin-muted">Usage and feedback at a glance. Data refreshes every 30 seconds.</p>
          </div>
          <span className="admin-updated"><Clock3 size={14} /> Updated {formatDate(data.generatedAt)}</span>
        </div>

        {error && <p className="admin-inline-error" role="status">{error} Showing the last loaded data.</p>}

        <div className="admin-metrics">
          <MetricCard label="Registered users" value={metrics.registeredUsers} detail={`+${metrics.newUsersLast7Days} in the last 7 days`} icon={Users} />
          <MetricCard label="Online now" value={metrics.onlineUsers} detail="Connected accounts" icon={Activity} />
          <MetricCard label="Conversations" value={metrics.conversations} detail={`${metrics.messages.toLocaleString()} messages`} icon={MessagesSquare} />
          <MetricCard label="Groups" value={metrics.groups} detail="Created groups" icon={UsersRound} />
          <MetricCard label="Feedback" value={metrics.feedback} detail="Submissions received" icon={Inbox} />
        </div>

        <section className="admin-panel">
          <div className="admin-panel-heading">
            <div>
              <p className="admin-eyebrow">ACCOUNTS</p>
              <h2>Recent users <span>{metrics.registeredUsers.toLocaleString()} total</span></h2>
            </div>
            <label className="admin-search">
              <Search size={16} />
              <input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Search latest users" />
            </label>
          </div>
          <div className="admin-table-wrap">
            <table>
              <thead><tr><th>User</th><th>Email</th><th>Joined</th><th>Last seen</th><th>Status</th></tr></thead>
              <tbody>
                {filteredUsers.map((user) => (
                  <tr key={user.username}>
                    <td><strong>{user.displayName}</strong><small>@{user.username}</small></td>
                    <td>{user.email || '—'}</td>
                    <td>{formatDate(user.createdAt)}</td>
                    <td>{formatDate(user.lastSeenAt)}</td>
                    <td><span className={`admin-pill ${user.isOnline ? 'is-online' : ''}`}>{user.isOnline ? 'Online' : user.isGoogleUser ? 'Google' : 'Offline'}</span></td>
                  </tr>
                ))}
                {!filteredUsers.length && <tr><td className="admin-empty" colSpan={5}>No users match that search.</td></tr>}
              </tbody>
            </table>
          </div>
          <p className="admin-note">Showing the latest {data.users.length} accounts. This view is read-only.</p>
        </section>

        <section className="admin-panel">
          <div className="admin-panel-heading">
            <div>
              <p className="admin-eyebrow">INBOX</p>
              <h2>Recent feedback <span>{metrics.feedback.toLocaleString()} total</span></h2>
            </div>
            <MessageSquare size={19} className="admin-heading-icon" />
          </div>
          {data.feedback.length ? (
            <div className="admin-feedback-list">
              {data.feedback.map((item) => (
                <article className="admin-feedback-item" key={item.id}>
                  <div className="admin-feedback-meta">
                    <span className={`admin-feedback-type type-${item.type}`}>{item.type}</span>
                    {item.rating !== null && <span className="admin-rating">{'★'.repeat(Math.max(0, Math.min(5, item.rating)))}</span>}
                    <time>{formatDate(item.createdAt)}</time>
                  </div>
                  <p>{item.message}</p>
                  <small>{item.fromUser}{item.email ? ` · ${item.email}` : ''}</small>
                </article>
              ))}
            </div>
          ) : <p className="admin-empty-block">No feedback submissions yet.</p>}
          <p className="admin-note">Latest 100 submissions; private chat messages are not shown here.</p>
        </section>
      </section>
    </main>
  );
}
