import { useNavigate } from "react-router-dom";

const LogOutIcon = () => (
  <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" style={{ marginRight: 6 }}>
    <path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4" />
    <polyline points="16 17 21 12 16 7" />
    <line x1="21" y1="12" x2="9" y2="12" />
  </svg>
);

export default function WelcomeBar({ restaurantName }: { restaurantName: string }) {
  const navigate = useNavigate();

  function handleSignOut() {
    localStorage.removeItem("access_token");
    navigate("/login");
  }

  return (
    <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start", marginBottom: 32 }}>
      <div>
        <h2 style={{ fontSize: 22, fontWeight: 700, color: "#111827", margin: 0, marginBottom: 4 }}>
          Welcome back, {restaurantName} 👋
        </h2>
        <p style={{ fontSize: 14, color: "#6b7280", margin: 0 }}>
          Here's your performance overview — track your impact
        </p>
      </div>
      <button
        onClick={handleSignOut}
        style={signOutStyle}
        onMouseOver={(e) => (e.currentTarget.style.background = "#f3f4f6")}
        onMouseOut={(e) => (e.currentTarget.style.background = "transparent")}
      >
        <LogOutIcon />
        Sign out
      </button>
    </div>
  );
}

const signOutStyle: React.CSSProperties = {
  display: "flex",
  alignItems: "center",
  fontSize: 14,
  fontWeight: 500,
  color: "#374151",
  background: "transparent",
  border: "1px solid #e5e7eb",
  borderRadius: 8,
  padding: "8px 14px",
  cursor: "pointer",
  transition: "background 0.15s",
};
