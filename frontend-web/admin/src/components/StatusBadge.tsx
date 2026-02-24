interface StatusBadgeProps {
  status: "pending" | "approved" | "suspended" | "active";
}
const colorMap: Record<string, string> = {
  pending: "bg-yellow-100 text-yellow-800",
  approved: "bg-green-100 text-green-800",
  suspended: "bg-red-100 text-red-800",
  active: "bg-green-100 text-green-800",
};
export function StatusBadge({ status }: StatusBadgeProps) {
  return (
    <span className={`px-2 py-1 rounded-full text-xs font-semibold ${colorMap[status] || "bg-gray-200 text-gray-600"}`}>
      {status}
    </span>
  );
}