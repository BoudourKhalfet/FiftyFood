import { AreaChart, Area, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer } from "recharts";
import type { WeeklyChartDay } from "../api/restaurantApi";

const CalendarIcon = () => (
  <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#10b981" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
    <rect x="3" y="4" width="18" height="18" rx="2" ry="2" />
    <line x1="16" y1="2" x2="16" y2="6" />
    <line x1="8" y1="2" x2="8" y2="6" />
    <line x1="3" y1="10" x2="21" y2="10" />
  </svg>
);

export default function WeeklyChart({ data }: { data: WeeklyChartDay[] }) {
  return (
    <div style={cardStyle}>
      <div style={{ marginBottom: 20 }}>
        <div style={{ display: "flex", alignItems: "center", gap: 8, marginBottom: 4 }}>
          <CalendarIcon />
          <h3 style={{ fontSize: 17, fontWeight: 700, color: "#111827", margin: 0 }}>Weekly performance</h3>
        </div>
        <p style={{ fontSize: 13, color: "#6b7280", margin: 0 }}>Revenue and orders over the last 7 days</p>
      </div>

      <ResponsiveContainer width="100%" height={280}>
        <AreaChart data={data} margin={{ top: 5, right: 10, left: 0, bottom: 0 }}>
          <defs>
            <linearGradient id="revGrad" x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" stopColor="#10b981" stopOpacity={0.35} />
              <stop offset="100%" stopColor="#10b981" stopOpacity={0.03} />
            </linearGradient>
          </defs>
          <CartesianGrid strokeDasharray="3 3" stroke="#e5e7eb" vertical={false} />
          <XAxis dataKey="day" stroke="#9ca3af" fontSize={12} tickLine={false} axisLine={false} />
          <YAxis stroke="#9ca3af" fontSize={12} tickLine={false} axisLine={false} />
          <Tooltip
            contentStyle={{ borderRadius: 10, border: "1px solid #e5e7eb", fontSize: 13 }}
            formatter={(val, name) => [
              name === "Revenue (€)" ? `€${Number(val).toFixed(2)}` : val,
              name,
            ]}
          />
          <Legend iconType="circle" iconSize={8} wrapperStyle={{ fontSize: 13, paddingTop: 16 }} />
          <Area
            type="monotone"
            dataKey="revenue"
            name="Revenue (€)"
            stroke="#10b981"
            strokeWidth={2.5}
            fill="url(#revGrad)"
            dot={false}
            activeDot={{ r: 5 }}
          />
          <Area
            type="monotone"
            dataKey="orders"
            name="Orders"
            stroke="#f97316"
            strokeWidth={2}
            fill="transparent"
            dot={false}
            activeDot={{ r: 5 }}
          />
        </AreaChart>
      </ResponsiveContainer>
    </div>
  );
}

const cardStyle: React.CSSProperties = {
  backgroundColor: "#fff",
  borderRadius: 12,
  padding: "24px 28px",
  boxShadow: "0 1px 4px rgba(0,0,0,0.06)",
  border: "1px solid #f1f5f9",
  marginTop: 24,
};
