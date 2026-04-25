interface OrderStatusBadgeProps {
  status: string;
}

const orderStatusColorMap: Record<string, string> = {
  pending: "bg-[#DCFCE7] text-[#10B981]",
  confirmed: "bg-[#DBEAFE] text-[#2563EB]",
  assigned: "bg-[#DBEAFE] text-[#2563EB]",
  ready: "bg-[#FFF3E0] text-[#FFA726]",
  paid: "bg-[#E8F5F0] text-[#1F9D7A]",
  delivering: "bg-[#E8F5F0] text-[#1F9D7A]",
  picked_up: "bg-[#FEE2E2] text-[#EF4444]",
  cancelled: "bg-[#FEE2E2] text-[#EF4444]",
  rejected: "bg-[#FEE2E2] text-[#EF4444]",
  delivered: "bg-[#F3F4F6] text-[#6B7280]",
  expired: "bg-[#F3F4F6] text-[#6B7280]",
  completed: "bg-[#DCFCE7] text-[#10B981]",
  refunded: "bg-[#FEF3C7] text-[#F59E0B]",
};

export function OrderStatusBadge({ status }: OrderStatusBadgeProps) {
  const colorClasses =
    orderStatusColorMap[status.toLowerCase()] || "bg-gray-200 text-gray-600";
  const label = status
    .toLowerCase()
    .split("_")
    .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
    .join(" ");
  return (
    <span
      className={`px-2.5 py-1 rounded-full text-xs font-semibold ${colorClasses}`}
    >
      {label}
    </span>
  );
}
