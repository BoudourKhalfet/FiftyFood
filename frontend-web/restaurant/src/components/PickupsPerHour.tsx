import { BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, Cell } from "recharts";
import type { PickupPerHour } from "../api/restaurantApi";

const ClockIcon = () => (
  <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#f59e0b" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
    <circle cx="12" cy="12" r="10" />
    <polyline points="12 6 12 12 16 14" />
  </svg>
);

const PEAK_COLOR = "#10b981";
const BASE_COLOR = "#9ca3af";

export default function PickupsPerHour({ data }: { data: PickupPerHour[] }) {
  const maxCount = Math.max(...data.map((d) => d.count), 1);

  return (
    <div style={cardStyle}>
      <div style={{ marginBottom: 20 }}>
        <div style={{ display: "flex", alignItems: "center", gap: 8, marginBottom: 4 }}>
          <ClockIcon />
          <h3 style={{ fontSize: 17, fontWeight: 700, color: "#111827", margin: 0 }}>Pickups per hour</h3>
        </div>
        <p style={{ fontSize: 13, color: "#6b7280", margin: 0 }}>When customers come to collect</p>
      </div>

      {data.length === 0 ? (
        <div style={{ height: 220, display: "flex", alignItems: "center", justifyContent: "center" }}>
          <p style={{ color: "#9ca3af", fontSize: 13 }}>No pickup data yet</p>
        </div>
      ) : (
        <ResponsiveContainer width="100%" height={220}>
          <BarChart data={data} margin={{ top: 5, right: 10, left: 0, bottom: 0 }} barSize={22}>
            <CartesianGrid strokeDasharray="3 3" stroke="#e5e7eb" vertical={false} />
            <XAxis dataKey="hour" stroke="#9ca3af" fontSize={12} tickLine={false} axisLine={false} />
            <YAxis stroke="#9ca3af" fontSize={12} tickLine={false} axisLine={false} />
            <Tooltip
              contentStyle={{ borderRadius: 10, border: "1px solid #e5e7eb", fontSize: 13 }}
              formatter={(val) => [val, "Pickups"]}
            />
            <Bar dataKey="count" radius={[4, 4, 0, 0]}>
              {data.map((entry, i) => (
                <Cell
                  key={i}
                  fill={entry.count === maxCount ? PEAK_COLOR : BASE_COLOR}
                  opacity={entry.count === maxCount ? 1 : 0.55}
                />
              ))}
            </Bar>
          </BarChart>
        </ResponsiveContainer>
      )}
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
