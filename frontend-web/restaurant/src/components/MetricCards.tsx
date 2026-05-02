import type { RestaurantStats } from "../api/restaurantApi";

const EuroIcon = () => (
  <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
    <path d="M4 10h12M4 14h12M19 6a7 7 0 1 0 0 12" />
  </svg>
);
const BoxIcon = () => (
  <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
    <path d="M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16z" />
    <polyline points="3.27 6.96 12 12.01 20.73 6.96" />
    <line x1="12" y1="22.08" x2="12" y2="12" />
  </svg>
);
const LeafIcon = () => (
  <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
    <path d="M11 20A7 7 0 0 1 9.8 6.1C15.5 5 17 4.48 19 2c1 2 2 4.18 2 8 0 5.5-4.78 10-10 10z" />
    <path d="M2 21c0-3 1.85-5.36 5.08-6C9.5 14.52 12 13 13 12" />
  </svg>
);
const StarIcon = () => (
  <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
    <polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2" />
  </svg>
);

function MetricCard({
  iconBg,
  iconColor,
  icon,
  change,
  value,
  label,
  changeIsPoints,
}: {
  iconBg: string;
  iconColor: string;
  icon: React.ReactNode;
  change: number;
  value: string;
  label: string;
  changeIsPoints?: boolean;
}) {
  const safeChange = isFinite(change) ? change : 0;
  const positive = safeChange > 0;
  const neutral = safeChange === 0;

  const badgeBg = positive ? "#f0fdf4" : neutral ? "#f3f4f6" : "#fef2f2";
  const badgeColor = positive ? "#16a34a" : neutral ? "#6b7280" : "#dc2626";

  const arrowSvg = positive ? (
    <svg width="12" height="12" viewBox="0 0 12 12" fill="none" style={{ marginRight: 3 }}>
      <path d="M2 9 L6 3 L10 9" stroke={badgeColor} strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  ) : (
    <svg width="12" height="12" viewBox="0 0 12 12" fill="none" style={{ marginRight: 3 }}>
      <path d="M2 3 L6 9 L10 3" stroke={badgeColor} strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  );

  const changeLabel = changeIsPoints
    ? `${positive ? "+" : ""}${safeChange.toFixed(1)}`
    : `${positive ? "+" : ""}${safeChange.toFixed(1)}%`;

  return (
    <div style={cardStyle}>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start" }}>
        <div style={{ width: 38, height: 38, borderRadius: "50%", display: "flex", alignItems: "center", justifyContent: "center", backgroundColor: iconBg, color: iconColor }}>
          {icon}
        </div>
        <div style={{ display: "inline-flex", alignItems: "center", fontSize: 12, fontWeight: 600, padding: "3px 9px", borderRadius: 999, backgroundColor: badgeBg, color: badgeColor }}>
          {arrowSvg}
          {changeLabel}
        </div>
      </div>
      <div style={{ marginTop: 20 }}>
        <p style={{ fontSize: 28, fontWeight: 700, color: "#111827", margin: 0, lineHeight: 1.1 }}>{value}</p>
        <p style={{ fontSize: 13, color: "#10b981", margin: 0, marginTop: 4, fontWeight: 500 }}>{label}</p>
      </div>
    </div>
  );
}

const cardStyle: React.CSSProperties = {
  backgroundColor: "#fff",
  borderRadius: 12,
  padding: "20px 20px 22px",
  boxShadow: "0 1px 4px rgba(0,0,0,0.06)",
  border: "1px solid #f1f5f9",
};

export default function MetricCards({ stats }: { stats: RestaurantStats }) {
  return (
    <div style={{ display: "grid", gridTemplateColumns: "repeat(4, 1fr)", gap: 16 }}>
      <MetricCard
        iconBg="#f0fdf4" iconColor="#16a34a" icon={<EuroIcon />}
        change={stats.revenueChangePercent}
        value={`€${Math.round(stats.revenue7d)}`}
        label="Revenue (7d)"
      />
      <MetricCard
        iconBg="#fff7ed" iconColor="#ea580c" icon={<BoxIcon />}
        change={stats.ordersChangePercent}
        value={String(stats.orders7d)}
        label="Orders (7d)"
      />
      <MetricCard
        iconBg="#f0fdf4" iconColor="#16a34a" icon={<LeafIcon />}
        change={stats.mealsSavedChangePercent}
        value={String(stats.mealsSaved7d)}
        label="Meals saved"
      />
      <MetricCard
        iconBg="#fffbeb" iconColor="#d97706" icon={<StarIcon />}
        change={stats.avgRatingChange}
        value={stats.avgRating.toFixed(1)}
        label="Avg rating"
        changeIsPoints
      />
    </div>
  );
}
