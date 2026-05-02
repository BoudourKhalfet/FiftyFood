import { BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, Cell } from "recharts";
import type { RatingsDistribution } from "../api/restaurantApi";

const StarIcon = () => (
  <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#f59e0b" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
    <polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2" />
  </svg>
);

export default function CustomerRatings({ data }: { data: RatingsDistribution }) {
  const chartData = data.distribution.map((d) => ({
    name: `${d.stars}★`,
    count: d.count,
  }));

  return (
    <div style={cardStyle}>
      <div style={{ marginBottom: 20 }}>
        <div style={{ display: "flex", alignItems: "center", gap: 8, marginBottom: 4 }}>
          <StarIcon />
          <h3 style={{ fontSize: 17, fontWeight: 700, color: "#111827", margin: 0 }}>Customer ratings</h3>
        </div>
        <p style={{ fontSize: 13, color: "#6b7280", margin: 0 }}>
          Distribution of {data.total} review{data.total !== 1 ? "s" : ""}
        </p>
      </div>

      <ResponsiveContainer width="100%" height={220}>
        <BarChart
          data={chartData}
          layout="vertical"
          margin={{ top: 0, right: 16, left: 8, bottom: 0 }}
          barSize={18}
        >
          <CartesianGrid strokeDasharray="3 3" stroke="#e5e7eb" horizontal={false} />
          <XAxis type="number" stroke="#9ca3af" fontSize={12} tickLine={false} axisLine={false} />
          <YAxis
            type="category"
            dataKey="name"
            stroke="#9ca3af"
            fontSize={12}
            tickLine={false}
            axisLine={false}
            width={30}
          />
          <Tooltip
            contentStyle={{ borderRadius: 10, border: "1px solid #e5e7eb", fontSize: 13 }}
            formatter={(val) => [val, "Reviews"]}
          />
          <Bar dataKey="count" radius={[0, 6, 6, 0]}>
            {chartData.map((_, i) => (
              <Cell key={i} fill="#f59e0b" />
            ))}
          </Bar>
        </BarChart>
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
