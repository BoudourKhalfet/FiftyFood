import { useState, useEffect } from 'react';
import restaurantApi, { RestaurantStats } from '../api/restaurantApi';

const Dashboard = () => {
  const [stats, setStats] = useState<RestaurantStats | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const fetchStats = async () => {
      try {
        setLoading(true);
        console.log('Fetching restaurant stats...');
        const data = await restaurantApi.getRestaurantStats();
        console.log('Stats received:', data);
        setStats(data);
      } catch (err) {
        const errorMsg = err instanceof Error ? err.message : 'Failed to load restaurant stats';
        console.error('Dashboard Error:', errorMsg);
        setError(errorMsg);
      } finally {
        setLoading(false);
      }
    };

    fetchStats();
  }, []);

  if (loading) {
    return (
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', minHeight: '100vh', backgroundColor: '#f9fafb', fontFamily: 'sans-serif' }}>
        <div style={{ textAlign: 'center' }}>
          <div style={{ width: '48px', height: '48px', border: '4px solid #dbeafe', borderTop: '4px solid #2563eb', borderRadius: '50%', animation: 'spin 1s linear infinite', margin: '0 auto 16px' }}></div>
          <p style={{ color: '#4b5563' }}>Loading dashboard...</p>
        </div>
      </div>
    );
  }

  if (error || !stats) {
    return (
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', minHeight: '100vh', backgroundColor: '#f9fafb', fontFamily: 'sans-serif' }}>
        <div style={{ backgroundColor: 'white', padding: '32px', borderRadius: '8px', boxShadow: '0 10px 15px rgba(0,0,0,0.1)', textAlign: 'center', maxWidth: '448px' }}>
          <div style={{ color: '#ef4444', fontSize: '36px', marginBottom: '16px' }}>⚠️</div>
          <h2 style={{ fontSize: '24px', fontWeight: 'bold', color: '#111827', marginBottom: '8px' }}>Error Loading Dashboard</h2>
          <p style={{ color: '#4b5563' }}>{error}</p>
        </div>
      </div>
    );
  }

  return (
    <div style={{ minHeight: '100vh', backgroundColor: '#f9fafb', padding: '32px', fontFamily: 'sans-serif' }}>
      <div style={{ maxWidth: '80rem', margin: '0 auto' }}>
        <div style={{ marginBottom: '32px' }}>
          <h1 style={{ fontSize: '30px', fontWeight: 'bold', color: '#111827', marginBottom: '8px' }}>Dashboard</h1>
          <p style={{ color: '#4b5563' }}>Your restaurant performance overview</p>
        </div>

        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(250px, 1fr))', gap: '24px', marginBottom: '32px' }}>
          <StatCard label="Total Sales" value={`€${stats.totalSales.toFixed(2)}`} icon="💶" />
          <StatCard label="Meals Saved" value={stats.totalMealsSaved} icon="🌿" />
          <StatCard label="Avg Rating" value={stats.avgRating.toFixed(1)} icon="⭐" />
          <StatCard label="Active Offers" value={stats.activeOffers} icon="📈" />
        </div>

        <div style={{ marginBottom: '32px' }}>
          <h2 style={{ fontSize: '20px', fontWeight: 'bold', color: '#111827', marginBottom: '16px' }}>Overview</h2>
          <p style={{ color: '#4b5563', fontSize: '14px', marginBottom: '24px' }}>Your performance, history and personalized tips</p>

          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(250px, 1fr))', gap: '24px' }}>
            <StatCardPerf label="Revenue (7d)" value={`€${stats.revenue7d.toFixed(2)}`} icon="💰" change={stats.revenueChangePercent} subtitle="Last 7 days" />
            <StatCardPerf label="Orders (7d)" value={stats.orders7d} icon="📦" change={stats.ordersChangePercent} subtitle="Last 7 days" />
            <StatCardPerf label="Meals saved (7d)" value={stats.mealsSaved7d} icon="🍽️" change={15.2} subtitle="Last 7 days" />
            <StatCardPerf label="Avg rating" value={stats.avgRating.toFixed(1)} icon="⭐" change={-0.1} subtitle="Current" />
          </div>
        </div>

        <div style={{ backgroundColor: 'white', borderRadius: '8px', boxShadow: '0 1px 3px rgba(0,0,0,0.1)', padding: '24px' }}>
          <h3 style={{ fontSize: '18px', fontWeight: 'bold', color: '#111827', marginBottom: '16px' }}>Quick Stats</h3>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(150px, 1fr))', gap: '16px', textAlign: 'center' }}>
            <QuickStat label="Total Orders" value={stats.totalOrders} />
            <QuickStat label="Avg. Order Value" value={`€${stats.totalOrders > 0 ? (stats.totalSales / stats.totalOrders).toFixed(2) : '0.00'}`} />
            <QuickStat label="Active Offers" value={stats.activeOffers} valueColor="#10b981" />
            <QuickStat label="Rating" value={`${stats.avgRating.toFixed(1)} ⭐`} valueColor="#eab308" />
            <QuickStat label="This Week Orders" value={stats.orders7d} valueColor="#3b82f6" />
            <QuickStat label="This Week Revenue" value={`€${stats.revenue7d.toFixed(2)}`} valueColor="#22c55e" />
          </div>
        </div>
      </div>
    </div>
  );
};

function StatCard({ label, value, icon }: { label: string; value: string | number; icon: string }) {
  return (
    <div style={{ backgroundColor: 'white', borderRadius: '8px', boxShadow: '0 1px 3px rgba(0,0,0,0.1)', padding: '24px', display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }} onMouseOver={(e) => (e.currentTarget.style.boxShadow = '0 4px 6px rgba(0,0,0,0.1)')} onMouseOut={(e) => (e.currentTarget.style.boxShadow = '0 1px 3px rgba(0,0,0,0.1)')}>
      <div>
        <p style={{ color: '#4b5563', fontSize: '14px', fontWeight: '500' }}>{label}</p>
        <p style={{ fontSize: '30px', fontWeight: 'bold', color: '#111827', marginTop: '8px' }}>{value}</p>
      </div>
      <span style={{ fontSize: '30px' }}>{icon}</span>
    </div>
  );
}

function StatCardPerf({ label, value, icon, change, subtitle }: { label: string; value: string | number; icon: string; change?: number; subtitle?: string }) {
  return (
    <div style={{ backgroundColor: 'white', borderRadius: '8px', boxShadow: '0 1px 3px rgba(0,0,0,0.1)', padding: '24px', display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }} onMouseOver={(e) => (e.currentTarget.style.boxShadow = '0 4px 6px rgba(0,0,0,0.1)')} onMouseOut={(e) => (e.currentTarget.style.boxShadow = '0 1px 3px rgba(0,0,0,0.1)')}>
      <div>
        <p style={{ color: '#4b5563', fontSize: '14px', fontWeight: '500' }}>{label}</p>
        <p style={{ fontSize: '30px', fontWeight: 'bold', color: '#111827', marginTop: '12px' }}>{value}</p>
        {subtitle && <p style={{ color: '#6b7280', fontSize: '12px', marginTop: '8px' }}>{subtitle}</p>}
      </div>
      <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'flex-end', gap: '8px' }}>
        <span style={{ fontSize: '30px' }}>{icon}</span>
        {change !== undefined && (
          <div style={{ display: 'inline-flex', alignItems: 'center', padding: '4px 12px', borderRadius: '9999px', fontSize: '12px', fontWeight: '600', backgroundColor: change > 0 ? '#dcfce7' : change < 0 ? '#fee2e2' : '#f3f4f6', color: change > 0 ? '#166534' : change < 0 ? '#991b1b' : '#374151' }}>
            <span style={{ marginRight: '4px' }}>{change > 0 ? '📈' : change < 0 ? '📉' : '➡️'}</span>
            {change === 0 ? '±0%' : change > 0 ? `+${change.toFixed(1)}%` : `${change.toFixed(1)}%`}
          </div>
        )}
      </div>
    </div>
  );
}

function QuickStat({ label, value, valueColor = '#111827' }: { label: string; value: string | number; valueColor?: string }) {
  return (
    <div>
      <p style={{ color: '#4b5563', fontSize: '14px' }}>{label}</p>
      <p style={{ fontSize: '24px', fontWeight: 'bold', color: valueColor, marginTop: '8px' }}>{value}</p>
    </div>
  );
}

export default Dashboard;
