interface OrderStatusBadgeProps {
  status: string;
}

const orderStatusColorMap: Record<string, string> = {
  completed: "bg-green-100 text-green-800",
  paid: "bg-blue-100 text-blue-800",
  ready: "bg-orange-100 text-orange-800",
  pending: "bg-yellow-100 text-yellow-800",
  cancelled: "bg-red-100 text-red-800",
  // Add any other status mappings needed
};

export function OrderStatusBadge({ status }: OrderStatusBadgeProps) {
  const colorClasses =
    orderStatusColorMap[status.toLowerCase()] || "bg-gray-200 text-gray-600";
  // Capitalize first letter for display
  const label = status.charAt(0).toUpperCase() + status.slice(1);
  return (
    <span
      className={`px-2 py-1 rounded-full text-xs font-semibold ${colorClasses}`}
      style={{ textTransform: "capitalize" }}
    >
      {label}
    </span>
  );
}
