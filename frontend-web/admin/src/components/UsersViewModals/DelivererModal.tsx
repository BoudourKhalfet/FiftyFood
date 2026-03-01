import {
  FaCheckCircle,
  FaCopy,
  FaEnvelope,
  FaPhone,
  FaMapMarkerAlt,
  FaRegFileAlt,
  FaRegClock,
  FaRegIdCard,
  FaMotorcycle,
  FaStar,
} from "react-icons/fa";
import { MdClose } from "react-icons/md";
import { useState } from "react";

const statusColor: Record<string, string> = {
  active: "bg-green-100 text-green-700",
  approved: "bg-green-100 text-green-700",
  pending: "bg-yellow-100 text-yellow-700",
  rejected: "bg-red-100 text-red-700",
  suspended: "bg-red-100 text-red-700",
};

type DelivererModalProps = {
  open: boolean;
  onClose: () => void;
  deliverer: {
    fullName?: string;
    status: "active" | "approved" | "pending" | "suspended" | "rejected";
    email?: string;
    phone?: string;
    zone?: string;
    cinOrPassportNumber?: string;
    vehicleType?: string;
    completedOrders?: number;
    avgRating?: number;
    licensePhotoUrl?: string | null;
    vehicleOwnershipDocUrl?: string | null;
    vehiclePhotoUrl?: string | null;
    termsAcceptedAt?: string | null;
    termsAcceptedName?: string | null;
    payoutMethod?: string | null;
    payoutIban?: string | null;
    payoutHolderName?: string | null;
    payoutBankName?: string | null;
    payoutPaypalEmail?: string | null;
    payoutWavePhone?: string | null;
    payoutWalletProvider?: string | null;
    payoutWalletPhone?: string | null;
    payoutWalletOmId?: string | null;
    accountHistory?: Array<{
      date: string;
      actor: string;
      action: string;
      description: string;
      actionType: string;
    }>;
  };
};

export function DelivererModal({
  open,
  onClose,
  deliverer,
}: DelivererModalProps) {
  const [copied, setCopied] = useState<{ [key: string]: boolean }>({});

  if (!open || !deliverer) return null;

  // Use zone as the address location (Google Map link)
  const zone = deliverer.zone || "";
  const mapsUrl =
    zone && zone.trim() !== ""
      ? `https://maps.google.com/?q=${encodeURIComponent(zone)}`
      : undefined;

  const handleCopy = (value: string, key: string) => {
    navigator.clipboard.writeText(value || "");
    setCopied((c) => ({ ...c, [key]: true }));
    setTimeout(() => setCopied((c) => ({ ...c, [key]: false })), 1200);
  };

  function getHistoryIcon(actionType: string) {
    switch (actionType) {
      case "SUSPEND":
      case "REJECT":
      case "REJECTED":
        return <FaRegIdCard className="text-red-500" />;
      case "PROFILE_EDIT":
      case "PROFILE_UPDATED":
        return <FaRegFileAlt className="text-yellow-500" />;
      case "ACCOUNT_CREATED":
        return <FaRegClock className="text-gray-400" />;
      case "EMAIL_VERIFIED":
      case "ACCOUNT_VERIFIED":
      case "DELIVERER_APPROVED":
      case "APPROVED":
        return <FaCheckCircle className="text-green-500" />;
      case "WARNING":
        return <FaRegFileAlt className="text-yellow-500" />;
      default:
        return <FaRegClock className="text-gray-400" />;
    }
  }

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black bg-opacity-30"
      style={{ fontFamily: "inherit" }}
    >
      <div className="bg-[#FCFCF9] w-[430px] max-h-[95vh] overflow-y-auto rounded-2xl shadow-xl relative p-0">
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
            <FaMotorcycle className="text-green-700" size={36} />
          </div>
          <div>
            <div className="text-xl font-bold text-gray-900">
              {deliverer.fullName ?? "(no name)"}
            </div>
            <div className="flex items-center gap-2 mt-1">
              <span className="text-sm text-gray-500">Deliverer account</span>
              <span
                className={`ml-2 px-2 py-[2px] rounded-full capitalize text-xs font-semibold ${statusColor[deliverer.status?.toLowerCase()] || ""}`}
              >
                {deliverer.status}
              </span>
            </div>
          </div>
        </div>

        {/* CONTACT & LOCATION */}
        <SectionTitle>Contact & Location</SectionTitle>
        <SectionCard>
          <InfoRow icon={<FaEnvelope />} label="Email">
            <span>
              {deliverer.email ?? (
                <span className="text-gray-400">Not provided</span>
              )}
            </span>
            {deliverer.email && (
              <>
                <button
                  onClick={() => handleCopy(deliverer.email!, "email")}
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
              {deliverer.phone ?? (
                <span className="text-gray-400">Not provided</span>
              )}
            </span>
            {deliverer.phone && (
              <>
                <button
                  onClick={() => handleCopy(deliverer.phone!, "phone")}
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
          <InfoRow icon={<FaMapMarkerAlt />} label="Zone">
            {mapsUrl ? (
              <a
                href={mapsUrl}
                target="_blank"
                rel="noopener noreferrer"
                className="hover:underline text-green-700"
              >
                {zone}
              </a>
            ) : (
              <span className="text-gray-400">Not provided</span>
            )}
          </InfoRow>
        </SectionCard>

        {/* IDENTITY & VEHICLE */}
        <SectionTitle>Identity & Vehicle</SectionTitle>
        <SectionCard>
          <InfoRow icon={<FaRegIdCard />} label="CIN/Passport">
            {deliverer.cinOrPassportNumber ?? (
              <span className="text-gray-400">Not provided</span>
            )}
          </InfoRow>
          <InfoRow icon={<FaMotorcycle />} label="Vehicle Type">
            {deliverer.vehicleType ?? (
              <span className="text-gray-400">N/A</span>
            )}
          </InfoRow>
        </SectionCard>
        {(deliverer.termsAcceptedAt || deliverer.termsAcceptedName) && (
          <>
            <SectionTitle>Terms Accepted</SectionTitle>
            <SectionCard>
              <InfoRow icon={<FaCheckCircle />} label="Date">
                {deliverer.termsAcceptedAt ? (
                  deliverer.termsAcceptedAt.slice(0, 10)
                ) : (
                  <span className="text-gray-400">N/A</span>
                )}
                {deliverer.termsAcceptedName && (
                  <span className="text-xs text-gray-400 ml-2">
                    (by {deliverer.termsAcceptedName})
                  </span>
                )}
              </InfoRow>
            </SectionCard>
          </>
        )}

        {/* DOCUMENTS */}
        <SectionTitle>Documents</SectionTitle>
        <div className="flex flex-wrap gap-2 px-8 mb-2">
          {deliverer.licensePhotoUrl && (
            <DocTag href={deliverer.licensePhotoUrl}>License Photo</DocTag>
          )}
          {deliverer.vehicleOwnershipDocUrl && (
            <DocTag href={deliverer.vehicleOwnershipDocUrl}>
              Ownership Document
            </DocTag>
          )}
          {deliverer.vehiclePhotoUrl && (
            <DocTag href={deliverer.vehiclePhotoUrl}>Vehicle Photo</DocTag>
          )}
          {!(
            deliverer.licensePhotoUrl ||
            deliverer.vehicleOwnershipDocUrl ||
            deliverer.vehiclePhotoUrl
          ) && (
            <span className="text-xs text-gray-400">
              No documents uploaded.
            </span>
          )}
        </div>

        <SectionTitle>Payout Information</SectionTitle>
        <SectionCard>
          <InfoRow icon={<FaRegFileAlt />} label="Method">
            {deliverer.payoutMethod ? (
              deliverer.payoutMethod.charAt(0).toUpperCase() +
              deliverer.payoutMethod.slice(1)
            ) : (
              <span className="text-gray-400">Not provided</span>
            )}
          </InfoRow>

          {/* BANK TRANSFER */}
          {deliverer.payoutMethod === "bank" && (
            <>
              <InfoRow icon={<FaRegFileAlt />} label="IBAN">
                {deliverer.payoutIban || (
                  <span className="text-gray-400">N/A</span>
                )}
              </InfoRow>
              <InfoRow icon={<FaRegIdCard />} label="Holder Name">
                {deliverer.payoutHolderName || (
                  <span className="text-gray-400">N/A</span>
                )}
              </InfoRow>
              <InfoRow icon={<FaRegFileAlt />} label="Bank Name">
                {deliverer.payoutBankName || (
                  <span className="text-gray-400">N/A</span>
                )}
              </InfoRow>
            </>
          )}

          {/* PAYPAL */}
          {deliverer.payoutMethod === "paypal" && (
            <InfoRow icon={<FaEnvelope />} label="PayPal Email">
              {deliverer.payoutPaypalEmail || (
                <span className="text-gray-400">N/A</span>
              )}
            </InfoRow>
          )}

          {/* WAVE */}
          {deliverer.payoutMethod === "wave" && (
            <InfoRow icon={<FaPhone />} label="Wave Phone">
              {deliverer.payoutWavePhone || (
                <span className="text-gray-400">N/A</span>
              )}
            </InfoRow>
          )}

          {/* ELECTRONIC WALLET (dynamic provider logic) */}
          {deliverer.payoutMethod === "ewallet" && (
            <>
              <InfoRow icon={<FaRegFileAlt />} label="Wallet Provider">
                {deliverer.payoutWalletProvider ? (
                  deliverer.payoutWalletProvider.charAt(0).toUpperCase() +
                  deliverer.payoutWalletProvider.slice(1)
                ) : (
                  <span className="text-gray-400">N/A</span>
                )}
              </InfoRow>
              {/* Example: Orange Money */}
              {deliverer.payoutWalletProvider === "orange" && (
                <InfoRow icon={<FaPhone />} label="Orange Phone">
                  {deliverer.payoutWalletPhone || (
                    <span className="text-gray-400">N/A</span>
                  )}
                </InfoRow>
              )}
              {/* Example: INWI */}
              {deliverer.payoutWalletProvider === "inwi" && (
                <InfoRow icon={<FaPhone />} label="INWI Phone">
                  {deliverer.payoutWalletPhone || (
                    <span className="text-gray-400">N/A</span>
                  )}
                </InfoRow>
              )}
              {/* Example: Wave as wallet (redundant if you also use "wave" as payoutMethod itself) */}
              {deliverer.payoutWalletProvider === "wave" && (
                <InfoRow icon={<FaPhone />} label="Wave Phone">
                  {deliverer.payoutWalletPhone || (
                    <span className="text-gray-400">N/A</span>
                  )}
                </InfoRow>
              )}
              {/* Add more e-wallet providers as needed */}
              {/* Example: if provider has QR or account email/id */}
              {deliverer.payoutWalletProvider === "om" && (
                <InfoRow icon={<FaRegFileAlt />} label="OM Account ID">
                  {deliverer.payoutWalletOmId || (
                    <span className="text-gray-400">N/A</span>
                  )}
                </InfoRow>
              )}
            </>
          )}

          {/* CASH (if you support cash payout) */}
          {deliverer.payoutMethod === "cash" && (
            <InfoRow icon={<FaRegFileAlt />} label="Details">
              <span>Cash — see accounting</span>
            </InfoRow>
          )}

          {/* FALLBACK: nothing else applied */}
          {!deliverer.payoutMethod && (
            <InfoRow icon={<FaRegFileAlt />} label="Details">
              <span className="text-gray-400">No payout info provided.</span>
            </InfoRow>
          )}
        </SectionCard>

        {/* ACTIVITY */}
        <SectionTitle>Activity</SectionTitle>
        <div className="flex justify-between items-stretch px-8 mb-2">
          <PerfBox value={deliverer.completedOrders ?? 0} label="Orders" />
          <PerfBox
            value={
              deliverer.avgRating ? (
                <span>
                  {deliverer.avgRating.toFixed(1)}{" "}
                  <FaStar className="inline -mt-1 text-yellow-400" />
                </span>
              ) : (
                "N/A"
              )
            }
            label="Avg Rating"
          />
          <PerfBox value={deliverer.vehicleType ?? "N/A"} label="Vehicle" />
        </div>

        {/* ACCOUNT HISTORY */}
        <SectionTitle>Account History</SectionTitle>
        <div className="px-8 pb-4 mb-4">
          <ol className="border-l-2 border-green-100 pl-3">
            {(deliverer.accountHistory ?? []).map((entry, i) => (
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
          {(!deliverer.accountHistory ||
            deliverer.accountHistory.length === 0) && (
            <div className="text-xs text-gray-400 italic mt-2">
              No account history found.
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

// Helper components (unchanged)
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
function DocTag({
  href,
  children,
}: {
  href: string;
  children: React.ReactNode;
}) {
  return (
    <a
      href={href}
      target="_blank"
      rel="noopener noreferrer"
      className="bg-gray-100 px-3 py-1 rounded-full text-xs font-semibold text-gray-500 hover:bg-green-700 hover:text-white transition"
    >
      {children}
    </a>
  );
}
