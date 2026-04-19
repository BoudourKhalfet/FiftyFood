import { useEffect, useState } from "react";
import {
  BarChart,
  Bar,
  PieChart,
  Pie,
  Cell,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
} from "recharts";

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
    negativeReviews: number;
    reportPercentage: number;
    isFlagged: boolean;
    avgRating: number;
  }>;
  flaggedRestaurants: Array<{
    id: string;
    name: string;
    reportPercentage: number;
    email: string;
  }>;
  dashboard: {
    totalRestaurants: number;
    flaggedCount: number;
    approvedRestaurants: number;
    avgReportPercentage: number;
  };
}

// Modern, visually distinct palette for roles: Admin, Client, Restaurant
const COLORS = ["#00C49F", "#FFBB28", "#FF8042", "#0088FE", "#FF4444"];

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
        throw new Error("Failed to fetch dashboard stats");
      }

      const data = await response.json();
      setStats(data);
      setError(null);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Unknown error");
      console.error("Error fetching dashboard:", err);
    } finally {
      setLoading(false);
    }
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center h-screen">
        <div className="text-2xl font-bold text-gray-600">
          Loading dashboard...
        </div>
      </div>
    );
  }

  if (error || !stats) {
    return (
      <div className="p-8">
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

  // Only show roles that exist in your system (ADMIN, CLIENT, RESTAURANT)
  const roleData = stats.userStats.byRole
    .filter((item) => ["ADMIN", "CLIENT", "RESTAURANT"].includes(item.role))
    .map((item) => ({
      name: item.role,
      value: item._count.id,
    }));

  const orderData = stats.orderStats.byStatus.map((item) => ({
    name: item.status,
    orders: item._count.id,
  }));

  const ratingData = [
    { name: "Restaurant Avg", rating: stats.ratingStats.avgRestaurantRating },
    { name: "Deliverer Avg", rating: stats.ratingStats.avgDelivererRating },
  ];

  const flaggedRestaurantData = stats.flaggedRestaurants
    .slice(0, 10)
    .map((r) => ({
      name: r.name.substring(0, 12),
      percentage: parseFloat(r.reportPercentage.toFixed(2)),
      fullName: r.name,
    }));

  return (
    <div className="p-8 bg-gray-50 min-h-screen">
      <h1 className="text-4xl font-bold text-gray-800 mb-8">Admin Dashboard</h1>

      {/* Key Stats Cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
        <div className="bg-white rounded-lg shadow p-6">
          <h3 className="text-gray-500 text-sm font-semibold mb-2">
            Total Users
          </h3>
          <p className="text-3xl font-bold text-blue-600">
            {stats.userStats.total}
          </p>
        </div>

        <div className="bg-white rounded-lg shadow p-6">
          <h3 className="text-gray-500 text-sm font-semibold mb-2">
            Total Orders
          </h3>
          <p className="text-3xl font-bold text-green-600">
            {stats.orderStats.total}
          </p>
        </div>

        <div className="bg-white rounded-lg shadow p-6">
          <h3 className="text-gray-500 text-sm font-semibold mb-2">
            Total Revenue
          </h3>
          <p className="text-3xl font-bold text-purple-600">
            ${(stats.orderStats.totalRevenue / 1000).toFixed(1)}K
          </p>
        </div>

        <div className="bg-white rounded-lg shadow p-6">
          <h3 className="text-gray-500 text-sm font-semibold mb-2">
            Approved Restaurants
          </h3>
          <p className="text-3xl font-bold text-amber-600">
            {stats.dashboard.approvedRestaurants}
          </p>
        </div>
      </div>

      {/* Alerts Section */}
      {stats.dashboard.flaggedCount > 0 && (
        <div className="mb-8 bg-red-50 border-l-4 border-red-500 p-6 rounded">
          <h2 className="text-xl font-bold text-red-700 mb-4">
            ⚠️ {stats.dashboard.flaggedCount} Restaurant(s) with High Report
            Rate
          </h2>
          <div className="space-y-3">
            {stats.flaggedRestaurants.map((rest) => (
              <div
                key={rest.id}
                className="bg-white p-4 rounded border-l-4 border-red-500 flex justify-between items-center"
              >
                <div>
                  <p className="font-semibold text-gray-800">{rest.name}</p>
                  <p className="text-sm text-gray-600">{rest.email}</p>
                </div>
                <div className="text-right">
                  <p className="text-2xl font-bold text-red-600">
                    {rest.reportPercentage.toFixed(1)}%
                  </p>
                  <p className="text-xs text-gray-500">Report Rate</p>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Charts Grid */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-8 mb-8">
        {/* Users by Role */}
        <div className="bg-white rounded-lg shadow p-6">
          <h2 className="text-xl font-bold text-gray-800 mb-4">
            Users by Role
          </h2>
          <ResponsiveContainer width="100%" height={300}>
            <PieChart>
              <Pie
                data={roleData}
                cx="50%"
                cy="50%"
                innerRadius={60}
                outerRadius={100}
                paddingAngle={2}
                labelLine={false}
                label={({ name, value }) => `${name}: ${value}`}
                fill="#8884d8"
                dataKey="value"
              >
                {roleData.map((entry, index) => (
                  <Cell
                    key={`cell-${index}`}
                    fill={COLORS[index % COLORS.length]}
                  />
                ))}
              </Pie>
              <Tooltip />
            </PieChart>
          </ResponsiveContainer>
        </div>

        {/* Orders by Status */}
        <div className="bg-white rounded-lg shadow p-6">
          <h2 className="text-xl font-bold text-gray-800 mb-4">
            Orders by Status
          </h2>
          <ResponsiveContainer width="100%" height={300}>
            <BarChart data={orderData}>
              <CartesianGrid strokeDasharray="3 3" />
              <XAxis dataKey="name" angle={-45} textAnchor="end" height={80} />
              <YAxis />
              <Tooltip />
              <Bar dataKey="orders" fill="#3273dc" />
            </BarChart>
          </ResponsiveContainer>
        </div>

        {/* Average Ratings */}
        <div className="bg-white rounded-lg shadow p-6">
          <h2 className="text-xl font-bold text-gray-800 mb-4">
            Average Ratings
          </h2>
          <ResponsiveContainer width="100%" height={300}>
            <BarChart data={ratingData}>
              <CartesianGrid strokeDasharray="3 3" />
              <XAxis dataKey="name" />
              <YAxis domain={[0, 5]} />
              <Tooltip />
              <Bar dataKey="rating" fill="#48c774" />
            </BarChart>
          </ResponsiveContainer>
        </div>

        {/* Flagged Restaurants Report Rate */}
        {flaggedRestaurantData.length > 0 && (
          <div className="bg-white rounded-lg shadow p-6">
            <h2 className="text-xl font-bold text-gray-800 mb-4">
              Top Flagged Restaurants (Report %)
            </h2>
            <ResponsiveContainer width="100%" height={300}>
              <BarChart data={flaggedRestaurantData}>
                <CartesianGrid strokeDasharray="3 3" />
                <XAxis
                  dataKey="name"
                  angle={-45}
                  textAnchor="end"
                  height={80}
                />
                <YAxis />
                <Tooltip
                  content={({ active, payload }) => {
                    if (active && payload && payload.length) {
                      return (
                        <div className="bg-white p-2 border border-gray-300 rounded shadow">
                          <p className="font-semibold">
                            {payload[0].payload.fullName}
                          </p>
                          <p className="text-red-600 font-bold">
                            {payload[0].value}% Report Rate
                          </p>
                        </div>
                      );
                    }
                    return null;
                  }}
                />
                <Bar dataKey="percentage" fill="#f14668" />
              </BarChart>
            </ResponsiveContainer>
          </div>
        )}
      </div>

      {/* Restaurants Overview Table */}
      <div className="bg-white rounded-lg shadow p-6">
        <h2 className="text-xl font-bold text-gray-800 mb-4">
          Restaurants Overview
        </h2>
        <div className="overflow-x-auto">
          <table className="min-w-full">
            <thead className="bg-gray-100">
              <tr>
                <th className="px-4 py-2 text-left text-sm font-semibold text-gray-700">
                  Restaurant
                </th>
                <th className="px-4 py-2 text-left text-sm font-semibold text-gray-700">
                  Status
                </th>
                <th className="px-4 py-2 text-left text-sm font-semibold text-gray-700">
                  Avg Rating
                </th>
                <th className="px-4 py-2 text-left text-sm font-semibold text-gray-700">
                  Reviews
                </th>
                <th className="px-4 py-2 text-left text-sm font-semibold text-gray-700">
                  Report Rate
                </th>
                <th className="px-4 py-2 text-left text-sm font-semibold text-gray-700">
                  Status
                </th>
              </tr>
            </thead>
            <tbody>
              {stats.restaurants.slice(0, 20).map((rest) => (
                <tr key={rest.id} className="border-t hover:bg-gray-50">
                  <td className="px-4 py-3 text-sm text-gray-800">
                    {rest.name}
                  </td>
                  <td className="px-4 py-3 text-sm">
                    <span
                      className={`px-2 py-1 rounded text-xs font-semibold ${
                        rest.status === "APPROVED"
                          ? "bg-green-100 text-green-800"
                          : rest.status === "PENDING"
                            ? "bg-yellow-100 text-yellow-800"
                            : "bg-red-100 text-red-800"
                      }`}
                    >
                      {rest.status}
                    </span>
                  </td>
                  <td className="px-4 py-3 text-sm text-gray-800">
                    ⭐ {rest.avgRating.toFixed(2)}
                  </td>
                  <td className="px-4 py-3 text-sm text-gray-800">
                    {rest.totalReviews}
                  </td>
                  <td className="px-4 py-3 text-sm font-semibold">
                    <span
                      className={
                        rest.reportPercentage > 20
                          ? "text-red-600"
                          : rest.reportPercentage > 10
                            ? "text-orange-600"
                            : "text-green-600"
                      }
                    >
                      {rest.reportPercentage.toFixed(1)}%
                    </span>
                  </td>
                  <td className="px-4 py-3 text-sm">
                    {rest.isFlagged && (
                      <span className="bg-red-100 text-red-800 px-2 py-1 rounded text-xs font-semibold">
                        🚨 FLAGGED
                      </span>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
