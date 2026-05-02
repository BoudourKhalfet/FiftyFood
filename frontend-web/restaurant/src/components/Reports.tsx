import { useState, useEffect } from "react";
import restaurantApi from "../api/restaurantApi";
import type { Complaint } from "../api/restaurantApi";
// Inline SVG icons to match codebase pattern
const WarningIcon = () => (
  <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
    <path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z" />
    <line x1="12" y1="9" x2="12" y2="13" />
    <line x1="12" y1="17" x2="12.01" y2="17" />
  </svg>
);

const UserIcon = () => (
  <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
    <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2" />
    <circle cx="12" cy="7" r="4" />
  </svg>
);

const CalendarIcon = () => (
  <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
    <rect x="3" y="4" width="18" height="18" rx="2" ry="2" />
    <line x1="16" y1="2" x2="16" y2="6" />
    <line x1="8" y1="2" x2="8" y2="6" />
    <line x1="3" y1="10" x2="21" y2="10" />
  </svg>
);

const ShoppingBagIcon = () => (
  <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
    <path d="M6 2L3 6v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V6l-3-4z" />
    <line x1="3" y1="6" x2="21" y2="6" />
    <path d="M16 10a4 4 0 0 1-8 0" />
  </svg>
);

const CommentIcon = () => (
  <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
    <path d="M21 11.5a8.38 8.38 0 0 1-.9 3.8 8.5 8.5 0 0 1-7.6 4.7 8.38 8.38 0 0 1-3.8-.9L3 21l1.9-5.7a8.38 8.38 0 0 1-.9-3.8 8.5 8.5 0 0 1 4.7-7.6 8.38 8.38 0 0 1 3.8-.9h.5a8.48 8.48 0 0 1 8 8v.5z" />
  </svg>
);

const CheckIcon = () => (
  <svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="#10b981" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
    <path d="M22 11.08V12a10 10 0 1 1-5.93-9.14" />
    <polyline points="22 4 12 14.01 9 11.01" />
  </svg>
);

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
  borderTop: "3px solid #ef4444",
  borderRadius: "50%",
  animation: "spin 0.8s linear infinite",
};

const cardStyle: React.CSSProperties = {
  backgroundColor: "#fff",
  borderRadius: 16,
  padding: "24px 28px",
  boxShadow: "0 1px 3px rgba(0,0,0,0.06)",
  marginBottom: 20,
};

const complaintCardStyle: React.CSSProperties = {
  backgroundColor: "#fef2f2",
  borderRadius: 12,
  padding: "20px 24px",
  marginBottom: 16,
  borderLeft: "4px solid #ef4444",
};

const badgeStyle = (color: string): React.CSSProperties => ({
  display: "inline-flex",
  alignItems: "center",
  padding: "4px 12px",
  borderRadius: 20,
  fontSize: 12,
  fontWeight: 600,
  backgroundColor: color + "20",
  color: color,
  gap: 6,
});

export default function Reports() {
  const [complaints, setComplaints] = useState<Complaint[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const load = async () => {
      try {
        setLoading(true);
        const data = await restaurantApi.getComplaints();
        setComplaints(data);
      } catch (err) {
        setError(err instanceof Error ? err.message : "Failed to load complaints");
      } finally {
        setLoading(false);
      }
    };
    load();
  }, []);

  // Group complaints by reason
  const complaintReasons = complaints.reduce((acc, complaint) => {
    acc[complaint.reason] = (acc[complaint.reason] || 0) + 1;
    return acc;
  }, {} as Record<string, number>);

  const sortedReasons = Object.entries(complaintReasons)
    .sort(([, a], [, b]) => b - a)
    .slice(0, 5);

  const formatDate = (dateStr: string) => {
    return new Date(dateStr).toLocaleDateString("en-US", {
      year: "numeric",
      month: "short",
      day: "numeric",
      hour: "2-digit",
      minute: "2-digit",
    });
  };

  if (loading) {
    return (
      <div style={centerFillStyle}>
        <div style={spinnerStyle} />
        <p style={{ color: "#6b7280", marginTop: 16 }}>Loading reports…</p>
      </div>
    );
  }

  if (error) {
    return (
      <div style={centerFillStyle}>
        <p style={{ color: "#ef4444" }}>⚠️ {error}</p>
      </div>
    );
  }

  return (
    <div style={pageStyle}>
      <div style={{ marginBottom: 28 }}>
        <h1 style={{ fontSize: 24, fontWeight: 700, color: "#111827", margin: 0, marginBottom: 8 }}>
          <span style={{ color: "#ef4444", marginRight: 10 }}><WarningIcon /></span>
          Reports & Complaints
        </h1>
        <p style={{ fontSize: 14, color: "#6b7280", margin: 0 }}>
          View customer complaints and feedback about your service
        </p>
      </div>

      {/* Stats Cards */}
      <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(200px, 1fr))", gap: 20, marginBottom: 28 }}>
        <div style={cardStyle}>
          <div style={{ fontSize: 32, fontWeight: 700, color: "#ef4444" }}>{complaints.length}</div>
          <div style={{ fontSize: 14, color: "#6b7280", marginTop: 4 }}>Total Complaints</div>
        </div>
        
        {sortedReasons.length > 0 && (
          <div style={cardStyle}>
            <div style={{ fontSize: 14, fontWeight: 600, color: "#374151", marginBottom: 8 }}>
              Top Complaint Reasons
            </div>
            <div style={{ display: "flex", flexWrap: "wrap", gap: 8 }}>
              {sortedReasons.slice(0, 3).map(([reason, count]) => (
                <span key={reason} style={badgeStyle("#ef4444")}>
                  {reason} ({count})
                </span>
              ))}
            </div>
          </div>
        )}
      </div>

      {/* Complaints List */}
      <div>
        <h2 style={{ fontSize: 18, fontWeight: 600, color: "#374151", margin: "0 0 16px 0" }}>
          Recent Complaints
        </h2>
        
        {complaints.length === 0 ? (
          <div style={{ ...cardStyle, textAlign: "center", padding: 40 }}>
            <div style={{ marginBottom: 16 }}><CheckIcon /></div>
            <p style={{ color: "#6b7280", fontSize: 16 }}>No complaints received. Great job!</p>
          </div>
        ) : (
          complaints.map((complaint) => (
            <div key={complaint.id} style={complaintCardStyle}>
              <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start", marginBottom: 12 }}>
                <span style={badgeStyle("#ef4444")}>
                  <WarningIcon />
                  {complaint.reason}
                </span>
                <span style={{ fontSize: 13, color: "#9ca3af", display: "flex", alignItems: "center", gap: 6 }}>
                  <CalendarIcon />
                  {formatDate(complaint.createdAt)}
                </span>
              </div>
              
              <div style={{ display: "flex", flexDirection: "column", gap: 8 }}>
                <div style={{ fontSize: 14, color: "#374151", display: "flex", alignItems: "center", gap: 8 }}>
                  <span style={{ color: "#6b7280" }}><UserIcon /></span>
                  <span style={{ fontWeight: 500 }}>From:</span> {complaint.complainantName}
                </div>
                
                {complaint.orderReference && (
                  <div style={{ fontSize: 14, color: "#374151", display: "flex", alignItems: "center", gap: 8 }}>
                    <span style={{ color: "#6b7280" }}><ShoppingBagIcon /></span>
                    <span style={{ fontWeight: 500 }}>Order:</span> {complaint.orderReference}
                  </div>
                )}
                
                {complaint.description && (
                  <div style={{ marginTop: 8, padding: 12, backgroundColor: "#fff", borderRadius: 8 }}>
                    <div style={{ fontSize: 13, color: "#6b7280", marginBottom: 4, display: "flex", alignItems: "center", gap: 6 }}>
                      <CommentIcon />
                      Description:
                    </div>
                    <p style={{ margin: 0, fontSize: 14, color: "#374151", lineHeight: 1.5 }}>
                      {complaint.description}
                    </p>
                  </div>
                )}
              </div>
            </div>
          ))
        )}
      </div>
    </div>
  );
}
