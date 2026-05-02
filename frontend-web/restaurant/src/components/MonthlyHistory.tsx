import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer } from "recharts";
import type { MonthlyHistoryDay } from "../api/restaurantApi";

const TrendIcon = () => (
  <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#10b981" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
    <polyline points="23 6 13.5 15.5 8.5 10.5 1 18" />
    <polyline points="17 6 23 6 23 12" />
  </svg>
);

export default function MonthlyHistory({ data }: { data: MonthlyHistoryDay[] }) {
  return (
    <div style={cardStyle}>
      <div style={{ marginBottom: 20 }}>
        <div style={{ display: "flex", alignItems: "center", gap: 8, marginBottom: 4 }}>
          <TrendIcon />
          <h3 style={{ fontSize: 17, fontWeight: 700, color: "#111827", margin: 0 }}>Monthly history</h3>
        </div>
        <p style={{ fontSize: 13, color: "#6b7280", margin: 0 }}>Revenue and meals saved trend</p>
      </div>

      <ResponsiveContainer width="100%" height={220}>
        <LineChart data={data} margin={{ top: 5, right: 10, left: 0, bottom: 0 }}>
          <CartesianGrid strokeDasharray="3 3" stroke="#e5e7eb" vertical={false} />
          <XAxis dataKey="month" stroke="#9ca3af" fontSize={12} tickLine={false} axisLine={false} />
          <YAxis stroke="#9ca3af" fontSize={12} tickLine={false} axisLine={false} />
          <Tooltip
            contentStyle={{ borderRadius: 10, border: "1px solid #e5e7eb", fontSize: 13 }}
            formatter={(val, name) => [
              name === "Revenue (€)" ? `€${Number(val).toFixed(2)}` : val,
              name,
            ]}
          />
          <Legend iconType="circle" iconSize={8} wrapperStyle={{ fontSize: 13, paddingTop: 16 }} />
          <Line
            type="monotone"
            dataKey="revenue"
            name="Revenue (€)"
            stroke="#10b981"
            strokeWidth={2.5}
            dot={{ r: 4, fill: "#10b981", strokeWidth: 0 }}
            activeDot={{ r: 6 }}
          />
          <Line
            type="monotone"
            dataKey="mealsSaved"
            name="Meals saved"
            stroke="#6ee7b7"
            strokeWidth={2}
            dot={{ r: 4, fill: "#6ee7b7", strokeWidth: 0 }}
            activeDot={{ r: 6 }}
          />
        </LineChart>
      </ResponsiveContainer>
    </div>
  );
}

const cardStyle: React.CSSProperties = {
  flex: 1,
  backgroundColor: "#fff",
  borderRadius: 12,
  padding: "24px 28px",
  boxShadow: "0 1px 4px rgba(0,0,0,0.06)",
  border: "1px solid #f1f5f9",
  minWidth: 0,
};
