import { useState, useEffect } from 'react';

type PageType = 'login' | 'dashboard';

interface RestaurantStats {
  totalSales: number;
  mealsSaved: number;
  avgRating: number;
  activeOffers: number;
}

function App() {
  const [currentPage, setCurrentPage] = useState<PageType>('login');
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [restaurantName, setRestaurantName] = useState<string>('');
  const [stats, setStats] = useState<RestaurantStats | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  useEffect(() => {
    const token = localStorage.getItem('access_token') || localStorage.getItem('onboarding_token');
    if (token) {
      setIsAuthenticated(true);
      setCurrentPage('dashboard');
      const savedName = localStorage.getItem('restaurant_name') || 'Restaurant';
      setRestaurantName(savedName);
      fetchStats(token);
    }
  }, []);

  const fetchStats = async (token?: string) => {
    setLoading(true);
    setError('');
    try {
      const authToken = token || localStorage.getItem('access_token') || localStorage.getItem('onboarding_token');
      if (!authToken) {
        throw new Error('No authentication token found');
      }

      const response = await fetch('http://172.16.50.169:3000/restaurant/onboarding/stats', {
        headers: { 
          Authorization: `Bearer ${authToken}`,
          'Content-Type': 'application/json'
        },
      });

      if (!response.ok) {
        if (response.status === 401) {
          throw new Error('Unauthorized - please log in again');
        }
        throw new Error(`HTTP ${response.status}`);
      }

      const data = await response.json();
      setStats(data);
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Failed to fetch dashboard stats';
      setError(message);
      console.error('Stats fetch error:', err);
    } finally {
      setLoading(false);
    }
  };

  const handleLogin = async (token: string, name: string) => {
    localStorage.setItem('access_token', token);
    localStorage.setItem('restaurant_name', name);
    setIsAuthenticated(true);
    setRestaurantName(name);
    setCurrentPage('dashboard');
    fetchStats(token);
  };

  const handleLogout = () => {
    localStorage.removeItem('access_token');
    localStorage.removeItem('onboarding_token');
    localStorage.removeItem('restaurant_name');
    setIsAuthenticated(false);
    setCurrentPage('login');
    setRestaurantName('');
    setStats(null);
    setError('');
  };

  if (currentPage === 'login') {
    return <LoginPage onLogin={handleLogin} />;
  }

  return (
    <div style={{ display: 'flex', minHeight: '100vh', fontFamily: 'sans-serif', backgroundColor: '#fafafa' }}>
      {/* Sidebar */}
      <aside style={{
        position: 'fixed',
        left: 0,
        top: 0,
        bottom: 0,
        width: '200px',
        backgroundColor: 'white',
        borderRight: '1px solid #e5e7eb',
        padding: '24px',
        display: 'flex',
        flexDirection: 'column',
        zIndex: 1000,
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '12px', marginBottom: '32px' }}>
          <div style={{ width: '40px', height: '40px', backgroundColor: '#17987C', borderRadius: '8px', display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'white', fontSize: '20px', fontWeight: 'bold' }}>
            F
          </div>
          <div>
            <h2 style={{ fontSize: '18px', fontWeight: 'bold', color: '#111827', margin: '0' }}>FiftyFood</h2>
            <p style={{ fontSize: '12px', color: '#4b5563', margin: '0' }}>Restaurant Portal</p>
          </div>
        </div>
        
        <nav style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: '8px' }}>
          <SidebarItem icon="📊" label="Overview" active />
          <SidebarItem icon="📦" label="My Offers" />
          <SidebarItem icon="📋" label="Orders" badge="2" />
          <SidebarItem icon="📈" label="Statistics" />
          <SidebarItem icon="🏢" label="Profile" />
        </nav>

        <div style={{ paddingTop: '16px' }}>
          <div style={{ padding: '16px', backgroundColor: '#f0f9f7', borderRadius: '8px', marginBottom: '16px' }}>
            <p style={{ fontSize: '14px', fontWeight: '600', color: '#17987C', margin: '0 0 8px 0' }}>⭐ Mode Fête</p>
            <button style={{
              width: '100%',
              padding: '8px 12px',
              fontSize: '12px',
              fontWeight: '500',
              color: '#17987C',
              backgroundColor: 'white',
              borderRadius: '6px',
              border: '1px solid #17987C',
              cursor: 'pointer',
            }}>
              Declareer un Mode Fête
            </button>
          </div>

          <div style={{ paddingBottom: '16px', borderBottom: '1px solid #e5e7eb', marginBottom: '16px' }}>
            <SidebarItem icon="⚙️" label="Settings" />
          </div>

          <button
            onClick={handleLogout}
            style={{
              width: '100%',
              padding: '12px',
              fontSize: '14px',
              fontWeight: '500',
              color: '#dc2626',
              backgroundColor: 'transparent',
              borderRadius: '8px',
              border: 'none',
              cursor: 'pointer',
              textAlign: 'left',
              display: 'flex',
              alignItems: 'center',
              gap: '8px',
            }}
          >
            <span>🚪</span>
            Sign Out
          </button>
        </div>
      </aside>

      {/* Main Content */}
      <main style={{ marginLeft: '200px', flex: 1, padding: '32px' }}>
        {/* Header */}
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: '32px' }}>
          <div>
            <h1 style={{ fontSize: '28px', fontWeight: 'bold', color: '#111827', margin: '0' }}>
              Welcome back, {restaurantName} 👋
            </h1>
            <p style={{ color: '#4b5563', margin: '8px 0 0 0', fontSize: '14px' }}>
              Manage your offers and track your impact
            </p>
          </div>
          <div style={{ display: 'flex', gap: '12px' }}>
            <button style={{
              padding: '10px 16px',
              fontSize: '14px',
              fontWeight: '500',
              color: '#17987C',
              backgroundColor: 'white',
              borderRadius: '8px',
              border: '1px solid #17987C',
              cursor: 'pointer',
            }}>
              📱 Scan QR
            </button>
            <button style={{
              padding: '10px 16px',
              fontSize: '14px',
              fontWeight: '600',
              color: 'white',
              backgroundColor: '#17987C',
              borderRadius: '8px',
              border: 'none',
              cursor: 'pointer',
            }}>
              ➕ New Offer
            </button>
          </div>
        </div>

        {/* Error message */}
        {error && (
          <div style={{ backgroundColor: '#fee2e2', border: '1px solid #fca5a5', borderRadius: '8px', padding: '16px', marginBottom: '24px', color: '#dc2626' }}>
            <strong>Error:</strong> {error}
            <button 
              onClick={() => fetchStats()} 
              style={{ marginLeft: '12px', background: 'none', border: 'none', color: '#dc2626', textDecoration: 'underline', cursor: 'pointer' }}>
              Retry
            </button>
          </div>
        )}

        {/* Stats Cards */}
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: '16px', marginBottom: '32px' }}>
          <StatCard label="Total Sales" value={loading ? '...' : stats ? `€${stats.totalSales.toFixed(0)}` : '€0'} icon="💶" />
          <StatCard label="Meals Saved" value={loading ? '...' : stats ? stats.mealsSaved.toString() : '0'} icon="🌿" />
          <StatCard label="Avg Rating" value={loading ? '...' : stats ? stats.avgRating.toFixed(1) : '0'} icon="⭐" />
          <StatCard label="Active Offers" value={loading ? '...' : stats ? stats.activeOffers.toString() : '0'} icon="📈" />
        </div>

        {/* Overview Section */}
        <div style={{ backgroundColor: 'white', borderRadius: '12px', padding: '24px', boxShadow: '0 1px 3px rgba(0,0,0,0.1)' }}>
          <h3 style={{ fontSize: '18px', fontWeight: '600', color: '#111827', margin: '0 0 24px 0' }}>Overview</h3>
          <p style={{ fontSize: '13px', color: '#4b5563', margin: '0 0 24px 0' }}>Performance and statistics</p>
          
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: '24px' }}>
            <div>
              <p style={{ fontSize: '13px', color: '#4b5563', margin: '0 0 8px 0' }}>Total Revenue</p>
              <div style={{ fontSize: '28px', fontWeight: 'bold', color: '#111827' }}>€{stats?.totalSales.toFixed(2) || '0.00'}</div>
              <p style={{ fontSize: '12px', color: '#059669', margin: '8px 0 0 0' }}>✓ All time</p>
            </div>
            <div>
              <p style={{ fontSize: '13px', color: '#4b5563', margin: '0 0 8px 0' }}>Total Meals Saved</p>
              <div style={{ fontSize: '28px', fontWeight: 'bold', color: '#111827' }}>{stats?.mealsSaved || '0'}</div>
              <p style={{ fontSize: '12px', color: '#059669', margin: '8px 0 0 0' }}>✓ From all offers</p>
            </div>
            <div>
              <p style={{ fontSize: '13px', color: '#4b5563', margin: '0 0 8px 0' }}>Customer Rating</p>
              <div style={{ fontSize: '28px', fontWeight: 'bold', color: '#111827' }}>{stats?.avgRating.toFixed(1) || '0'}/5</div>
              <p style={{ fontSize: '12px', color: '#059669', margin: '8px 0 0 0' }}>⭐ Average rating</p>
            </div>
          </div>
        </div>
      </main>
    </div>
  );
}

function SidebarItem({ icon, label, badge, active }: { icon: string; label: string; badge?: string; active?: boolean }) {
  return (
    <button 
      style={{
        width: '100%',
        padding: '12px 16px',
        fontSize: '14px',
        fontWeight: '500',
        color: active ? 'white' : '#4b5563',
        backgroundColor: active ? '#17987C' : 'transparent',
        borderRadius: '8px',
        border: 'none',
        cursor: 'pointer',
        textAlign: 'left',
        display: 'flex',
        alignItems: 'center',
        gap: '12px',
      }}
    >
      <span style={{ fontSize: '16px' }}>{icon}</span>
      {label}
      {badge && (
        <span style={{ marginLeft: 'auto', backgroundColor: active ? 'rgba(255,255,255,0.3)' : '#17987C', color: 'white', fontSize: '11px', fontWeight: '600', padding: '2px 6px', borderRadius: '3px' }}>
          {badge}
        </span>
      )}
    </button>
  );
}

function StatCard({ label, value, icon }: { label: string; value: string; icon: string }) {
  return (
    <div style={{ backgroundColor: 'white', borderRadius: '12px', boxShadow: '0 1px 3px rgba(0,0,0,0.1)', padding: '20px', display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
      <div>
        <p style={{ color: '#4b5563', fontSize: '13px', fontWeight: '500', margin: '0' }}>{label}</p>
        <p style={{ fontSize: '28px', fontWeight: 'bold', color: '#111827', margin: '12px 0 0 0' }}>{value}</p>
      </div>
      <span style={{ fontSize: '32px' }}>{icon}</span>
    </div>
  );
}

function LoginPage({ onLogin }: { onLogin: (token: string, name: string) => void }) {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError('');

    try {
      const response = await fetch('http://172.16.50.169:3000/auth/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, password }),
      });

      const data = await response.json();

      if (!response.ok) {
        throw new Error(data.message || 'Invalid email or password');
      }

      const token = data.accessToken || data.onboardingToken;
      if (!token) throw new Error('No token received');

      const restaurantName = email.split('@')[0];
      onLogin(token, restaurantName);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Login failed');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div style={{ background: '#fafafa', minHeight: '100vh', display: 'flex', alignItems: 'center', justifyContent: 'center', fontFamily: 'sans-serif' }}>
      <div style={{ width: '390px' }}>
        <div style={{ marginBottom: '32px', display: 'flex', flexDirection: 'column', alignItems: 'center', textAlign: 'center' }}>
          <div style={{ width: '100px', height: '100px', backgroundColor: '#17987C', borderRadius: '16px', display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'white', fontSize: '48px', fontWeight: 'bold' }}>
            🍽️
          </div>
        </div>

        <h1 style={{ fontSize: '28px', fontWeight: '700', textAlign: 'center', color: '#111827', margin: '0 0 16px 0' }}>
          Welcome to FiftyFood
        </h1>
        
        <p style={{ fontSize: '16px', color: '#818181', textAlign: 'center', margin: '0 0 32px 0' }}>
          Restaurant Management
        </p>

        <div style={{ borderRadius: '12px', padding: '32px 24px', backgroundColor: 'white', boxShadow: '0 1px 3px rgba(0,0,0,0.1)', marginBottom: '16px' }}>
          <form onSubmit={handleSubmit}>
            <div style={{ marginBottom: '20px' }}>
              <label style={{ display: 'block', fontSize: '14px', fontWeight: '500', color: '#111827', marginBottom: '8px' }}>
                Email
              </label>
              <input
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="your@email.com"
                style={{
                  width: '100%',
                  padding: '12px 16px',
                  border: '1px solid #d1d5db',
                  borderRadius: '8px',
                  fontSize: '16px',
                  boxSizing: 'border-box',
                }}
              />
            </div>

            <div style={{ marginBottom: '20px' }}>
              <label style={{ display: 'block', fontSize: '14px', fontWeight: '500', color: '#111827', marginBottom: '8px' }}>
                Password
              </label>
              <input
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                placeholder="••••••••"
                style={{
                  width: '100%',
                  padding: '12px 16px',
                  border: '1px solid #d1d5db',
                  borderRadius: '8px',
                  fontSize: '16px',
                  boxSizing: 'border-box',
                }}
              />
            </div>

            {error && (
              <div style={{ color: '#dc2626', marginBottom: '16px', fontSize: '14px' }}>
                {error}
              </div>
            )}

            <button
              type="submit"
              disabled={loading}
              style={{
                width: '100%',
                backgroundColor: '#17987C',
                color: 'white',
                border: 'none',
                borderRadius: '8px',
                padding: '12px 24px',
                fontSize: '16px',
                fontWeight: '600',
                cursor: loading ? 'not-allowed' : 'pointer',
                opacity: loading ? 0.7 : 1,
              }}
            >
              {loading ? 'Signing in...' : 'Sign In'}
            </button>
          </form>
        </div>

        <div style={{ textAlign: 'center', fontSize: '14px', color: '#818181' }}>
          <p>Demo credentials available upon request</p>
        </div>
      </div>
    </div>
  );
}

export default App;
