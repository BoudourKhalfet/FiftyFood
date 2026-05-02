import { useState, useEffect } from "react";
import restaurantApi from "../api/restaurantApi";
import type { RestaurantStats, WeeklyChartDay, RatingsDistribution, MonthlyHistoryDay, PickupPerHour } from "../api/restaurantApi";
import WelcomeBar from "./WelcomeBar";
import MetricCards from "./MetricCards";
import WeeklyChart from "./WeeklyChart";
import CustomerRatings from "./CustomerRatings";
import MonthlyHistory from "./MonthlyHistory";
import PickupsPerHour from "./PickupsPerHour";

const pageStyle: React.CSSProperties = {
  minHeight: "100vh",
  backgroundColor: "#f8fafc",
  padding: "36px 40px",
  fontFamily: "-apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif",
};

const centerFillStyle: React.CSSProperties = {
  display: "flex",
  flexDirection: "column",
  alignItems: "center",
  justifyContent: "center",
  minHeight: "100vh",
  backgroundColor: "#f8fafc",
};

const spinnerStyle: React.CSSProperties = {
  width: 40,
  height: 40,
  border: "3px solid #e5e7eb",
  borderTop: "3px solid #10b981",
  borderRadius: "50%",
  animation: "spin 0.8s linear infinite",
};

export default function Dashboard() {
  const [stats, setStats] = useState<RestaurantStats | null>(null);
  const [chartData, setChartData] = useState<WeeklyChartDay[]>([]);
  const [ratings, setRatings] = useState<RatingsDistribution | null>(null);
  const [monthlyHistory, setMonthlyHistory] = useState<MonthlyHistoryDay[]>([]);
  const [pickups, setPickups] = useState<PickupPerHour[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const load = async () => {
      try {
        setLoading(true);
        const [data, weekly, ratingsDist, monthly, pickupsData] = await Promise.all([
          restaurantApi.getRestaurantStats(),
          restaurantApi.getWeeklyChartData(),
          restaurantApi.getRatingsDistribution(),
          restaurantApi.getMonthlyHistory(),
          restaurantApi.getPickupsPerHour(),
        ]);
        setStats(data);
        setChartData(weekly);
        setRatings(ratingsDist);
        setMonthlyHistory(monthly);
        setPickups(pickupsData);
      } catch (err) {
        setError(err instanceof Error ? err.message : "Failed to load dashboard");
      } finally {
        setLoading(false);
      }
    };
    load();
  }, []);

  if (loading) {
    return (
      <div style={centerFillStyle}>
        <div style={spinnerStyle} />
        <p style={{ color: "#6b7280", marginTop: 16 }}>Loading dashboard…</p>
      </div>
    );
  }

  if (error || !stats) {
    return (
      <div style={centerFillStyle}>
        <p style={{ color: "#ef4444" }}>⚠️ {error ?? "No data"}</p>
      </div>
    );
  }

  return (
    <div style={pageStyle}>
      <WelcomeBar restaurantName={stats.restaurantName} />

      <div style={{ marginBottom: 20 }}>
        <h1 style={{ fontSize: 22, fontWeight: 700, color: "#111827", margin: 0, marginBottom: 4 }}>Dashboard</h1>
        <p style={{ fontSize: 13, color: "#10b981", margin: 0 }}>Performance, ML forecasts, and statistics-driven tips</p>
      </div>

      <MetricCards stats={stats} />
      <WeeklyChart data={chartData} />
      <div style={{ display: "flex", gap: 20, marginTop: 24 }}>
        <MonthlyHistory data={monthlyHistory} />
        <PickupsPerHour data={pickups} />
      </div>
      {ratings && <CustomerRatings data={ratings} />}
    </div>
  );
}
