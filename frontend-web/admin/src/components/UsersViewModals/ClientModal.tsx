import {
  FaCheckCircle,
  FaCopy,
  FaEnvelope,
  FaPhone,
  FaMapMarkerAlt,
  FaRegFileAlt,
  FaRegClock,
  FaRegIdCard,
  FaStar,
} from "react-icons/fa";
import { MdClose } from "react-icons/md";
import { useState } from "react";

// Status badge color classes
const clientStatusColor: Record<string, string> = {
  active: "bg-green-100 text-green-700",
  suspended: "bg-red-100 text-red-700",
};

type ClientModalProps = {
  open: boolean;
  onClose: () => void;
  client: {
    fullName?: string;
    status: "active" | "suspended";
    email?: string;
    phone?: string;
    defaultAddress?: string;
    joinedAt?: string;
    lastActiveAt?: string;
    totalOrders?: number;
    totalSpent?: number;
    avgRating?: number;
    accountHistory?: Array<{
      date: string;
      actor: string;
      action: string;
      description: string;
      actionType: string;
    }>;
  };
};

export function ClientModal({ open, onClose, client }: ClientModalProps) {
  const [copied, setCopied] = useState<{ [key: string]: boolean }>({});

  if (!open || !client) return null;
  const address = client.defaultAddress || client.defaultAddress || "";
  const mapsUrl = address
    ? `https://maps.google.com/?q=${encodeURIComponent(address)}`
    : undefined;

  const handleCopy = (value: string, key: string) => {
    navigator.clipboard.writeText(value || "");
    setCopied((c) => ({ ...c, [key]: true }));
    setTimeout(() => setCopied((c) => ({ ...c, [key]: false })), 1200);
  };

  // Icon mapping for account history timeline
  function getHistoryIcon(actionType: string) {
    switch (actionType) {
      case "SUSPEND":
      case "ACCOUNT_SUSPENDED":
        return <FaRegIdCard className="text-red-500" />;
      case "PROFILE_EDIT":
      case "PROFILE_UPDATED":
        return <FaRegFileAlt className="text-green-500" />;
      case "ACCOUNT_CREATED":
        return <FaRegClock className="text-gray-400" />;
      case "EMAIL_VERIFIED":
      case "ACCOUNT_VERIFIED":
        return <FaCheckCircle className="text-green-500" />;
      case "WARNING":
        return <FaRegFileAlt className="text-yellow-500" />;
      default:
        return <FaRegClock className="text-gray-400" />;
    }
  }
  console.log("Modal received accountHistory:", client.accountHistory);

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black bg-opacity-30"
      style={{ fontFamily: "inherit" }}
    >
      <div className="bg-[#FCFCF9] w-[440px] max-h-[95vh] overflow-y-auto rounded-2xl shadow-xl relative p-0">
        {/* Close button */}
        <button
          onClick={onClose}
          className="absolute right-4 top-4 text-2xl text-gray-400 hover:text-green-600"
        >
          <MdClose size={28} />
        </button>
        {/* Header */}
        <div className="flex items-center gap-4 px-8 pt-8 pb-2">
          <div className="w-14 h-14 rounded-xl bg-green-100 flex items-center justify-center overflow-hidden">
            {/* Default user icon */}
            <FaRegIdCard className="text-green-700" size={36} />
          </div>
          <div>
            <div className="text-xl font-bold text-gray-900">
              {client.fullName ?? "(no name)"}
            </div>
            <div className="flex items-center gap-2 mt-1">
              <span className="text-sm text-gray-500">Client account</span>
              <span
                className={`ml-2 px-2 py-[2px] rounded-full text-xs font-semibold capitalize ${
                  clientStatusColor[client.status?.toLowerCase() || "active"]
                }`}
              >
                {client.status}
              </span>
            </div>
          </div>
        </div>

        {/* PERSONAL INFORMATION */}
        <SectionTitle>Personal Information</SectionTitle>
        <SectionCard>
          <InfoRow icon={<FaEnvelope />} label="Email">
            <span>
              {client.email ?? (
                <span className="text-gray-400">Not provided</span>
              )}
            </span>
            {client.email && (
              <>
                <button
                  onClick={() => handleCopy(client.email!, "email")}
                  title="Copy Email"
                  className="ml-2 text-gray-400 hover:text-green-600"
                >
                  <FaCopy />
                </button>
                {copied["email"] && (
                  <span className="ml-1 text-green-600 text-xs">Copied!</span>
                )}
              </>
            )}
          </InfoRow>
          <InfoRow icon={<FaPhone />} label="Phone">
            <span>
              {client.phone ?? (
                <span className="text-gray-400">Not provided</span>
              )}
            </span>
            {client.phone && (
              <>
                <button
                  onClick={() => handleCopy(client.phone!, "phone")}
                  title="Copy Phone"
                  className="ml-2 text-gray-400 hover:text-green-600"
                >
                  <FaCopy />
                </button>
                {copied["phone"] && (
                  <span className="ml-1 text-green-600 text-xs">Copied!</span>
                )}
              </>
            )}
          </InfoRow>
          <InfoRow icon={<FaMapMarkerAlt />} label="Address">
            {mapsUrl ? (
              <a
                href={mapsUrl}
                target="_blank"
                rel="noopener noreferrer"
                className="hover:underline text-green-700"
              >
                {address}
              </a>
            ) : (
              <span className="text-gray-400">Not provided</span>
            )}
          </InfoRow>
          <InfoRow icon={<FaRegClock />} label="Joined">
            {client.joinedAt ? (
              client.joinedAt.slice(0, 10)
            ) : (
              <span className="text-gray-400">N/A</span>
            )}
          </InfoRow>
          {client.lastActiveAt && (
            <InfoRow icon={<FaRegClock />} label="Last active">
              {client.lastActiveAt.slice(0, 10)}
            </InfoRow>
          )}
        </SectionCard>

        {/* ACTIVITY */}
        <SectionTitle>Activity</SectionTitle>
        <div className="flex justify-between items-stretch px-8 mb-2">
          <PerfBox value={client.totalOrders ?? 0} label="Orders" />
          <PerfBox
            value={`€${(client.totalSpent ?? 0).toFixed(2)}`}
            label="Total Spent"
          />
          <PerfBox
            value={
              client.avgRating ? (
                <span>
                  {client.avgRating.toFixed(1)}{" "}
                  <FaStar className="inline -mt-1 text-yellow-400" />
                </span>
              ) : (
                "N/A"
              )
            }
            label="Avg Rating"
          />
        </div>

        {/* ACCOUNT HISTORY */}
        <SectionTitle>
          <span className="inline-flex items-center">
            <FaRegClock className="mr-1" />
            Account History
          </span>
        </SectionTitle>
        <div className="px-8 pb-4 mb-4">
          <ol className="border-l-2 border-green-100 pl-3">
            {client.accountHistory?.map((entry, i) => (
              <li key={i} className="mb-4 flex items-start gap-2">
                <span className="mt-1 flex-shrink-0">
                  {getHistoryIcon(entry.actionType)}
                </span>
                <div>
                  <div className="font-semibold text-green-900 text-sm">
                    {entry.action}
                  </div>
                  {entry.description && (
                    <div className="text-xs text-gray-500">
                      {entry.description}
                    </div>
                  )}
                  <div className="text-xs text-gray-400">
                    {entry.date}
                    {entry.actor && ` • by ${entry.actor}`}
                  </div>
                </div>
              </li>
            ))}
          </ol>
          {(!client.accountHistory || client.accountHistory.length === 0) && (
            <div className="text-xs text-gray-400 italic mt-2">
              No account history found.
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

// Helper components
function SectionTitle({ children }: { children: React.ReactNode }) {
  return (
    <div className="uppercase text-xs font-bold text-gray-400 px-8 pt-3 pb-1">
      {children}
    </div>
  );
}
function SectionCard({ children }: { children: React.ReactNode }) {
  return (
    <div className="bg-white rounded-xl border px-5 py-3 my-2 mx-8 mb-3">
      {children}
    </div>
  );
}
function InfoRow({
  icon,
  label,
  children,
}: {
  icon: React.ReactNode;
  label: string;
  children: React.ReactNode;
}) {
  return (
    <div className="flex items-center py-[5px] text-[15px] border-b border-gray-50 last:border-none">
      <span className="text-green-700 mr-2">{icon}</span>
      <span className="font-semibold mr-1 min-w-[104px]">{label}:</span>
      <span className="flex-1 flex items-center">{children}</span>
    </div>
  );
}
function PerfBox({ value, label }: { value: React.ReactNode; label: string }) {
  return (
    <div className="flex flex-col items-center justify-center min-w-[80px] px-1 py-2 bg-white rounded-xl border">
      <div className="font-bold text-green-700 text-lg">{value}</div>
      <div className="text-xs text-gray-500">{label}</div>
    </div>
  );
}
