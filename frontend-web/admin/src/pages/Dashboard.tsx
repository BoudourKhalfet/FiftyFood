import { useEffect, useState } from "react";
import {
  BarChart,
  Bar,
  AreaChart,
  Area,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
} from "recharts";

// Icon Components
const DollarIcon = () => (
  <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
    <line x1="12" y1="1" x2="12" y2="23"></line>
    <path d="M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6"></path>
  </svg>
);

const BoxIcon = () => (
  <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
    <path d="M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16z"></path>
    <polyline points="3.27 6.96 12 12.01 20.73 6.96"></polyline>
    <line x1="12" y1="22.08" x2="12" y2="12"></line>
  </svg>
);

const UsersIcon = () => (
  <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
    <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"></path>
    <circle cx="9" cy="7" r="4"></circle>
    <path d="M23 21v-2a4 4 0 0 0-3-3.87"></path>
    <path d="M16 3.13a4 4 0 0 1 0 7.75"></path>
  </svg>
);

const LeafIcon = () => (
  <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
    <path d="M11 20A7 7 0 0 1 9.8 6.1C15.5 5 17 4.48 19 2c1 2 2 4.18 2 8 0 5.5-4.78 10-10 10z"></path>
    <path d="M2 21c0-3 1.85-5.36 5.08-6C9.5 14.52 12 13 13 12"></path>
  </svg>
);

const PercentIcon = () => (
  <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
    <line x1="19" y1="5" x2="5" y2="19"></line>
    <circle cx="6.5" cy="6.5" r="2.5"></circle>
    <circle cx="17.5" cy="17.5" r="2.5"></circle>
  </svg>
);

const StarIcon = () => (
  <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
    <polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"></polygon>
  </svg>
);

const CartIcon = () => (
  <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
    <circle cx="9" cy="21" r="1"></circle>
    <circle cx="20" cy="21" r="1"></circle>
    <path d="M1 1h4l2.68 13.39a2 2 0 0 0 2 1.61h9.72a2 2 0 0 0 2-1.61L23 6H6"></path>
  </svg>
);

const TrendUpIcon = () => (
  <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="3" strokeLinecap="round" strokeLinejoin="round">
    <polyline points="23 6 13.5 15.5 8.5 10.5 1 18"></polyline>
    <polyline points="17 6 23 6 23 12"></polyline>
  </svg>
);

const TrendDownIcon = () => (
  <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="3" strokeLinecap="round" strokeLinejoin="round">
    <polyline points="23 18 13.5 8.5 8.5 13.5 1 6"></polyline>
    <polyline points="17 18 23 18 23 12"></polyline>
  </svg>
);

interface DashboardStats {
  userStats: {
    byRole: Array<{ role: string; _count: { id: number } }>;
    byStatus: Array<{ status: string; _count: { id: number } }>;
    total: number;
  };
  orderStats: {
    total: number;
    totalRevenue: number;
    byStatus: Array<{ status: string; _count: { id: number } }>;
    weeklyData?: Array<{ day: string; revenue: number; orders: number }>;
    hourlyData?: Array<{ hour: string; count: number }>;
  };
  ratingStats: {
    avgRestaurantRating: number;
    avgDelivererRating: number;
  };
  restaurants: Array<{
    id: string;
    email: string;
    status: string;
    name: string;
    totalReviews: number;
    totalOrders: number;
    complaints: number;
    reportPercentage: number;
    isFlagged: boolean;
    avgRating: number;
  }>;
  flaggedRestaurants: Array<{
    id: string;
    name: string;
    reportPercentage: number;
    email: string;
    totalOrders: number;
    complaints: number;
  }>;
  environmentalData?: Array<{
    month: string;
    mealsSaved: number;
    mealsWasted: number;
  }>;
  dashboard: {
    totalRestaurants: number;
    flaggedCount: number;
    approvedRestaurants: number;
    avgReportPercentage: number;
    newUsersThisMonth?: number;
    newUsersLastMonth?: number;
    mealsSavedThisMonth?: number;
    mealsWastedThisMonth?: number;
    offerConversionRate?: number;
    avgOrderValue?: number;
  };
}

// Metric Card Component
function MetricCard({
  icon,
  iconBg,
  iconColor,
  value,
  label,
  change,
  changePositive,
}: {
  icon: React.ReactNode;
  iconBg: string;
  iconColor: string;
  value: string;
  label: string;
  change: string;
  changePositive: boolean;
}) {
  return (
    <div className="bg-white rounded-xl p-5 shadow-sm border border-gray-100">
      <div className="flex justify-between items-start mb-4">
        <div
          className="w-10 h-10 rounded-full flex items-center justify-center"
          style={{ backgroundColor: iconBg, color: iconColor }}
        >
          {icon}
        </div>
        <div
          className={`inline-flex items-center gap-1 px-2 py-1 rounded-full text-xs font-semibold ${
            changePositive
              ? "bg-green-50 text-green-600"
              : "bg-red-50 text-red-600"
          }`}
        >
          {changePositive ? <TrendUpIcon /> : <TrendDownIcon />}
          {change}
        </div>
      </div>
      <div>
        <p className="text-2xl font-bold text-gray-900">{value}</p>
        <p className="text-sm text-green-600 font-medium mt-1">{label}</p>
      </div>
    </div>
  );
}

// Bottom Stat Card
function StatCard({
  icon,
  value,
  label,
  subtext,
  subtextPositive,
}: {
  icon: React.ReactNode;
  value: string;
  label: string;
  subtext: string;
  subtextPositive: boolean;
}) {
  return (
    <div className="bg-white rounded-xl p-6 shadow-sm border border-gray-100 text-center">
      <div className="flex justify-center mb-3">
        <div className="w-12 h-12 rounded-full bg-gray-50 flex items-center justify-center text-gray-600">
          {icon}
        </div>
      </div>
      <p className="text-3xl font-bold text-gray-900 mb-1">{value}</p>
      <p className="text-sm text-gray-500 mb-2">{label}</p>
      <p
        className={`text-xs font-medium ${
          subtextPositive ? "text-green-600" : "text-red-500"
        }`}
      >
        {subtext}
      </p>
    </div>
  );
}

export default function Dashboard() {
  const [stats, setStats] = useState<DashboardStats | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    fetchDashboardStats();
  }, []);

  const fetchDashboardStats = async () => {
    try {
      setLoading(true);
      const token = localStorage.getItem("access_token");
      const response = await fetch("/admin/dashboard", {
        method: "GET",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${token}`,
        },
      });

      if (!response.ok) {
        throw new Error(`Failed to fetch dashboard stats: ${response.status}`);
      }

      const data = await response.json();
      setStats(data);
      setError(null);
    } catch (err) {
      const errorMsg = err instanceof Error ? err.message : "Unknown error";
      setError(errorMsg);
      console.error("Error fetching dashboard:", err);
    } finally {
      setLoading(false);
    }
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center h-screen bg-gray-50">
        <div className="text-center">
          <div className="w-10 h-10 border-3 border-gray-200 border-t-green-500 rounded-full animate-spin mx-auto mb-4"></div>
          <p className="text-gray-600">Loading dashboard...</p>
        </div>
      </div>
    );
  }

  if (error || !stats) {
    return (
      <div className="p-8 bg-gray-50 min-h-screen">
        <div className="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded">
          <p className="font-bold">Error loading dashboard</p>
          <p>{error}</p>
          <button
            onClick={fetchDashboardStats}
            className="mt-4 bg-red-500 hover:bg-red-700 text-white font-bold py-2 px-4 rounded"
          >
            Retry
          </button>
        </div>
      </div>
    );
  }

  // Real data from backend only
  const weeklyData = stats.orderStats.weeklyData || [];
  const hourlyData = stats.orderStats.hourlyData || [];
  const environmentalData = stats.environmentalData || [];

  // Calculate percentage changes
  const revenueChange = weeklyData.length >= 2
    ? ((weeklyData[weeklyData.length - 1].revenue - weeklyData[weeklyData.length - 2].revenue) / Math.max(weeklyData[weeklyData.length - 2].revenue, 1) * 100).toFixed(1)
    : "0.0";
  const ordersChange = ((stats.orderStats.total - (stats.dashboard.newUsersLastMonth || 0)) / Math.max(stats.dashboard.newUsersLastMonth || 1, 1) * 100).toFixed(1);
  const usersChange = (((stats.dashboard.newUsersThisMonth || 0) - (stats.dashboard.newUsersLastMonth || 0)) / Math.max(stats.dashboard.newUsersLastMonth || 1, 1) * 100).toFixed(1);
  const mealsChange = (((stats.dashboard.mealsSavedThisMonth || 0) - (stats.dashboard.mealsWastedThisMonth || 0)) / Math.max(stats.dashboard.mealsWastedThisMonth || 1, 1) * 100).toFixed(1);

  return (
    <div className="p-6 bg-gray-50 min-h-screen">
      <h1 className="text-3xl font-bold text-gray-900 mb-2">Admin Dashboard</h1>
      <p className="text-gray-500 mb-6">Platform governance and supervision</p>

      {/* Top Metric Cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
        <MetricCard
          icon={<DollarIcon />}
          iconBg="#ecfdf5"
          iconColor="#16a34a"
          value={`€${(stats.orderStats.totalRevenue / 100).toFixed(0).replace(/\B(?=(\d{3})+(?!\d))/g, ",")}`}
          label="Revenue This Week"
          change={`${Number(revenueChange) >= 0 ? "+" : ""}${revenueChange}%`}
          changePositive={Number(revenueChange) >= 0}
        />
        <MetricCard
          icon={<BoxIcon />}
          iconBg="#fff7ed"
          iconColor="#ea580c"
          value={stats.orderStats.total.toString()}
          label="Orders This Week"
          change={`${Number(ordersChange) >= 0 ? "+" : ""}${ordersChange}%`}
          changePositive={Number(ordersChange) >= 0}
        />
        <MetricCard
          icon={<UsersIcon />}
          iconBg="#f0fdf4"
          iconColor="#16a34a"
          value={`+${stats.dashboard.newUsersThisMonth || 0}`}
          label="New Users (Month)"
          change={`${Number(usersChange) >= 0 ? "+" : ""}${usersChange}%`}
          changePositive={Number(usersChange) >= 0}
        />
        <MetricCard
          icon={<LeafIcon />}
          iconBg="#f0fdf4"
          iconColor="#16a34a"
          value={(stats.dashboard.mealsSavedThisMonth || 0).toString()}
          label="Meals Saved (Month)"
          change={`${Number(mealsChange) >= 0 ? "+" : ""}${mealsChange}%`}
          changePositive={Number(mealsChange) >= 0}
        />
      </div>

      {/* Charts Row */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-6">
        {/* Weekly Revenue & Orders */}
        <div className="bg-white rounded-xl p-6 shadow-sm border border-gray-100">
          <h3 className="text-lg font-semibold text-gray-900 mb-1">
            Weekly Revenue & Orders
          </h3>
          <p className="text-sm text-gray-500 mb-4">Daily breakdown this week</p>
          <ResponsiveContainer width="100%" height={250}>
            <AreaChart data={weeklyData}>
              <defs>
                <linearGradient id="colorRevenue" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="5%" stopColor="#14b8a6" stopOpacity={0.3} />
                  <stop offset="95%" stopColor="#14b8a6" stopOpacity={0} />
                </linearGradient>
              </defs>
              <CartesianGrid strokeDasharray="3 3" stroke="#f1f5f9" />
              <XAxis
                dataKey="day"
                axisLine={false}
                tickLine={false}
                tick={{ fill: "#94a3b8", fontSize: 12 }}
              />
              <YAxis
                axisLine={false}
                tickLine={false}
                tick={{ fill: "#94a3b8", fontSize: 12 }}
              />
              <Tooltip
                contentStyle={{
                  backgroundColor: "#fff",
                  border: "1px solid #e2e8f0",
                  borderRadius: "8px",
                  boxShadow: "0 4px 6px -1px rgba(0, 0, 0, 0.1)",
                }}
              />
              <Area
                type="monotone"
                dataKey="revenue"
                stroke="#14b8a6"
                strokeWidth={2}
                fillOpacity={1}
                fill="url(#colorRevenue)"
              />
            </AreaChart>
          </ResponsiveContainer>
        </div>

        {/* Hourly Activity */}
        <div className="bg-white rounded-xl p-6 shadow-sm border border-gray-100">
          <h3 className="text-lg font-semibold text-gray-900 mb-1">
            Hourly Activity (Today)
          </h3>
          <p className="text-sm text-gray-500 mb-4">Peak hours for order placement</p>
          <ResponsiveContainer width="100%" height={250}>
            <BarChart data={hourlyData}>
              <CartesianGrid strokeDasharray="3 3" stroke="#f1f5f9" vertical={false} />
              <XAxis
                dataKey="hour"
                axisLine={false}
                tickLine={false}
                tick={{ fill: "#94a3b8", fontSize: 12 }}
              />
              <YAxis
                axisLine={false}
                tickLine={false}
                tick={{ fill: "#94a3b8", fontSize: 12 }}
              />
              <Tooltip
                contentStyle={{
                  backgroundColor: "#fff",
                  border: "1px solid #e2e8f0",
                  borderRadius: "8px",
                  boxShadow: "0 4px 6px -1px rgba(0, 0, 0, 0.1)",
                }}
                cursor={{ fill: "#f1f5f9" }}
              />
              <Bar dataKey="count" fill="#14b8a6" radius={[4, 4, 0, 0]} />
            </BarChart>
          </ResponsiveContainer>
        </div>
      </div>

      {/* Environmental Impact Chart */}
      <div className="bg-white rounded-xl p-6 shadow-sm border border-gray-100 mb-6">
        <div className="flex items-center gap-2 mb-1">
          <LeafIcon />
          <h3 className="text-lg font-semibold text-gray-900">
            Environmental Impact — Meals Saved vs Wasted
          </h3>
        </div>
        <p className="text-sm text-gray-500 mb-4">Monthly food waste reduction progress</p>
        <ResponsiveContainer width="100%" height={280}>
          <AreaChart data={environmentalData}>
            <defs>
              <linearGradient id="colorSaved" x1="0" y1="0" x2="0" y2="1">
                <stop offset="5%" stopColor="#22c55e" stopOpacity={0.3} />
                <stop offset="95%" stopColor="#22c55e" stopOpacity={0} />
              </linearGradient>
              <linearGradient id="colorWasted" x1="0" y1="0" x2="0" y2="1">
                <stop offset="5%" stopColor="#ef4444" stopOpacity={0.3} />
                <stop offset="95%" stopColor="#ef4444" stopOpacity={0} />
              </linearGradient>
            </defs>
            <CartesianGrid strokeDasharray="3 3" stroke="#f1f5f9" />
            <XAxis
              dataKey="month"
              axisLine={false}
              tickLine={false}
              tick={{ fill: "#94a3b8", fontSize: 12 }}
            />
            <YAxis
              axisLine={false}
              tickLine={false}
              tick={{ fill: "#94a3b8", fontSize: 12 }}
            />
            <Tooltip
              contentStyle={{
                backgroundColor: "#fff",
                border: "1px solid #e2e8f0",
                borderRadius: "8px",
                boxShadow: "0 4px 6px -1px rgba(0, 0, 0, 0.1)",
              }}
            />
            <Area
              type="monotone"
              dataKey="mealsSaved"
              stroke="#22c55e"
              strokeWidth={2}
              fillOpacity={1}
              fill="url(#colorSaved)"
              name="Meals Saved"
            />
            <Area
              type="monotone"
              dataKey="mealsWasted"
              stroke="#ef4444"
              strokeWidth={2}
              fillOpacity={1}
              fill="url(#colorWasted)"
              name="Meals Wasted"
            />
          </AreaChart>
        </ResponsiveContainer>
        <div className="flex justify-center gap-6 mt-4">
          <div className="flex items-center gap-2">
            <div className="w-3 h-3 rounded-full bg-green-500"></div>
            <span className="text-sm text-gray-600">Meals Saved</span>
          </div>
          <div className="flex items-center gap-2">
            <div className="w-3 h-3 rounded-full bg-red-500"></div>
            <span className="text-sm text-gray-600">Meals Wasted</span>
          </div>
        </div>
      </div>

      {/* Bottom Stat Cards */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <StatCard
          icon={<PercentIcon />}
          value={`${stats.dashboard.offerConversionRate ?? 0}%`}
          label="Offer Conversion Rate"
          subtext={`${(stats.dashboard.offerConversionRate ?? 0) > 50 ? "+" : ""}${((stats.dashboard.offerConversionRate ?? 0) - 50).toFixed(1)}% vs last month`}
          subtextPositive={((stats.dashboard.offerConversionRate ?? 0) - 50) >= 0}
        />
        <StatCard
          icon={<StarIcon />}
          value={stats.ratingStats.avgRestaurantRating.toFixed(1)}
          label="Avg Restaurant Rating"
          subtext={`${stats.ratingStats.avgRestaurantRating >= 4 ? "+" : ""}${(stats.ratingStats.avgRestaurantRating - 4).toFixed(1)} vs last month`}
          subtextPositive={stats.ratingStats.avgRestaurantRating >= 4}
        />
        <StatCard
          icon={<CartIcon />}
          value={`€${(stats.dashboard.avgOrderValue ?? 0).toFixed(2)}`}
          label="Avg Order Value"
          subtext={`${(stats.dashboard.avgOrderValue ?? 0) >= 7 ? "+" : ""}€${((stats.dashboard.avgOrderValue ?? 0) - 7).toFixed(2)} vs last month`}
          subtextPositive={(stats.dashboard.avgOrderValue ?? 0) >= 7}
        />
      </div>
    </div>
  );
}
