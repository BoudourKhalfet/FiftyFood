import {
  FaCheckCircle,
  FaCalendar,
  FaCopy,
  FaEnvelope,
  FaMapMarkerAlt,
  FaPhone,
  FaRegBuilding,
  FaRegFileAlt,
  FaRegIdCard,
} from "react-icons/fa";
import { MdClose } from "react-icons/md";
import { useState } from "react";

type RestaurantModalProps = {
  open: boolean;
  onClose: () => void;
  restaurant: {
    logoUrl?: string;
    coverImageUrl?: string;
    restaurantName?: string;
    establishmentType?: string;
    status: "approved" | "pending" | "suspended" | "rejected";
    email?: string;
    phone?: string;
    address?: string;
    city?: string;
    legalEntityName?: string;
    registrationNumberRNE?: string;
    businessRegistrationDocumentUrl?: string | null;
    hygieneCertificateUrl?: string | null;
    proofOfOwnershipOrLeaseUrl?: string | null;
    submittedAt?: string;
    termsAcceptedAt?: string;
    termsAcceptedName?: string;
    payoutMethod?: string;
    payoutIban?: string;
    payoutHolderName?: string;
    payoutBankName?: string;
    payoutPaypalEmail?: string;
    payoutWavePhone?: string;
    payoutWalletProvider?: string;
    payoutWalletPhone?: string;
    payoutWalletOmId?: string;
    trustScore?: number;
    offersCount?: number;
    ordersCompleted?: number;
    totalSales?: number;
    accountHistory?: Array<{
      date: string;
      actor: string;
      action: string;
      description: string;
      actionType: string;
      icon?: React.ReactNode;
      color?: string;
    }>;
  };
};

const statusColor: Record<string, string> = {
  approved: "bg-green-100 text-green-700",
  pending: "bg-yellow-100 text-yellow-700",
  rejected: "bg-red-100 text-red-700",
  suspended: "bg-red-100 text-red-700",
};

export function RestaurantModal({
  open,
  onClose,
  restaurant,
}: RestaurantModalProps) {
  const [copied, setCopied] = useState<{ [key: string]: boolean }>({});

  if (!open || !restaurant) return null;

  const fullAddress = [restaurant.address, restaurant.city]
    .filter(Boolean)
    .join(", ");
  const mapsUrl = fullAddress
    ? `https://maps.google.com/?q=${encodeURIComponent(fullAddress)}`
    : undefined;

  const handleCopy = (value: string, key: string) => {
    navigator.clipboard.writeText(value || "");
    setCopied((c) => ({ ...c, [key]: true }));
    setTimeout(() => setCopied((c) => ({ ...c, [key]: false })), 1200);
  };

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black bg-opacity-30"
      style={{ fontFamily: "inherit" }}
    >
      <div className="bg-[#FCFCF9] w-[430px] max-h-[95vh] overflow-y-auto rounded-2xl shadow-xl relative p-0">
        {/* COVER PHOTO */}
        {restaurant.coverImageUrl && (
          <img
            src={restaurant.coverImageUrl}
            alt="Cover"
            style={{
              width: "100%",
              height: "120px",
              objectFit: "cover",
              borderTopLeftRadius: "16px",
              borderTopRightRadius: "16px",
              marginBottom: "0.5em",
            }}
          />
        )}

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
            {restaurant.logoUrl ? (
              <img
                src={restaurant.logoUrl}
                alt="logo"
                className="w-full h-full object-cover"
              />
            ) : (
              <FaRegBuilding className="text-green-700" size={36} />
            )}
          </div>
          <div>
            <div className="text-xl font-bold text-gray-900">
              {restaurant.restaurantName ?? "(no name)"}
            </div>
            <div className="flex items-center gap-2 mt-1">
              <span className="text-sm text-gray-500">
                {restaurant.establishmentType || ""}
              </span>
              <span
                className={`ml-2 px-2 py-[2px] rounded-full capitalize text-xs font-semibold ${
                  statusColor[restaurant.status?.toLowerCase()] || ""
                }`}
              >
                {restaurant.status}
              </span>
            </div>
          </div>
        </div>

        {/* CONTACT & LOCATION */}
        <SectionTitle>Contact & Location</SectionTitle>
        <SectionCard>
          <InfoRow icon={<FaEnvelope />} label="Email">
            <span>
              {restaurant.email ?? (
                <span className="text-gray-400">Not provided</span>
              )}
            </span>
            {restaurant.email && (
              <>
                <button
                  onClick={() => handleCopy(restaurant.email!, "email")}
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
            {restaurant.phone ? (
              <>
                <span>{restaurant.phone}</span>
                <button
                  onClick={() => handleCopy(restaurant.phone!, "phone")}
                  title="Copy Phone"
                  className="ml-2 text-gray-400 hover:text-green-600"
                >
                  <FaCopy />
                </button>
                {copied["phone"] && (
                  <span className="ml-1 text-green-600 text-xs">Copied!</span>
                )}
              </>
            ) : (
              <span className="text-gray-400">Not provided</span>
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
                {fullAddress}
              </a>
            ) : (
              <span className="text-gray-400">Not provided</span>
            )}
          </InfoRow>
        </SectionCard>

        {/* LEGAL INFORMATION */}
        <SectionTitle>Legal Information</SectionTitle>
        <SectionCard>
          <InfoRow icon={<FaRegFileAlt />} label="Legal Name">
            {restaurant.legalEntityName || (
              <span className="text-gray-400">N/A</span>
            )}
          </InfoRow>
          <InfoRow icon={<FaRegIdCard />} label="Registration Number">
            <span>
              {restaurant.registrationNumberRNE ?? (
                <span className="text-gray-400">N/A</span>
              )}
            </span>
            {restaurant.registrationNumberRNE && (
              <>
                <button
                  onClick={() =>
                    handleCopy(restaurant.registrationNumberRNE!, "regNum")
                  }
                  title="Copy Registration Number"
                  className="ml-2 text-gray-400 hover:text-green-600"
                >
                  <FaCopy />
                </button>
                {copied["regNum"] && (
                  <span className="ml-1 text-green-600 text-xs">Copied!</span>
                )}
              </>
            )}
          </InfoRow>
          <InfoRow icon={<FaCalendar />} label="Submitted">
            {restaurant.submittedAt ? (
              restaurant.submittedAt.slice(0, 10)
            ) : (
              <span className="text-gray-400">N/A</span>
            )}
          </InfoRow>
          {restaurant.termsAcceptedAt && (
            <InfoRow icon={<FaCheckCircle />} label="Terms Accepted">
              {restaurant.termsAcceptedAt.slice(0, 10)}
              {restaurant.termsAcceptedName && (
                <span className="text-xs text-gray-400 ml-2">
                  (by {restaurant.termsAcceptedName})
                </span>
              )}
            </InfoRow>
          )}
        </SectionCard>
        <SectionTitle>Payout Information</SectionTitle>
        <SectionCard>
          <InfoRow icon={<FaRegFileAlt />} label="Method">
            {restaurant.payoutMethod ? (
              restaurant.payoutMethod.charAt(0).toUpperCase() +
              restaurant.payoutMethod.slice(1)
            ) : (
              <span className="text-gray-400">Not provided</span>
            )}
          </InfoRow>

          {/* BANK TRANSFER */}
          {restaurant.payoutMethod === "bank" && (
            <>
              <InfoRow icon={<FaRegFileAlt />} label="IBAN">
                {restaurant.payoutIban || (
                  <span className="text-gray-400">N/A</span>
                )}
              </InfoRow>
              <InfoRow icon={<FaRegIdCard />} label="Holder Name">
                {restaurant.payoutHolderName || (
                  <span className="text-gray-400">N/A</span>
                )}
              </InfoRow>
              <InfoRow icon={<FaRegFileAlt />} label="Bank Name">
                {restaurant.payoutBankName || (
                  <span className="text-gray-400">N/A</span>
                )}
              </InfoRow>
            </>
          )}

          {/* PAYPAL */}
          {restaurant.payoutMethod === "paypal" && (
            <InfoRow icon={<FaEnvelope />} label="PayPal Email">
              {restaurant.payoutPaypalEmail || (
                <span className="text-gray-400">N/A</span>
              )}
            </InfoRow>
          )}

          {/* WAVE */}
          {restaurant.payoutMethod === "wave" && (
            <InfoRow icon={<FaPhone />} label="Wave Phone">
              {restaurant.payoutWavePhone || (
                <span className="text-gray-400">N/A</span>
              )}
            </InfoRow>
          )}

          {/* ELECTRONIC WALLET (dynamic provider logic) */}
          {restaurant.payoutMethod === "ewallet" && (
            <>
              <InfoRow icon={<FaRegFileAlt />} label="Wallet Provider">
                {restaurant.payoutWalletProvider ? (
                  restaurant.payoutWalletProvider.charAt(0).toUpperCase() +
                  restaurant.payoutWalletProvider.slice(1)
                ) : (
                  <span className="text-gray-400">N/A</span>
                )}
              </InfoRow>
              {/* Example: Orange Money */}
              {restaurant.payoutWalletProvider === "orange" && (
                <InfoRow icon={<FaPhone />} label="Orange Phone">
                  {restaurant.payoutWalletPhone || (
                    <span className="text-gray-400">N/A</span>
                  )}
                </InfoRow>
              )}
              {/* Example: INWI */}
              {restaurant.payoutWalletProvider === "inwi" && (
                <InfoRow icon={<FaPhone />} label="INWI Phone">
                  {restaurant.payoutWalletPhone || (
                    <span className="text-gray-400">N/A</span>
                  )}
                </InfoRow>
              )}
              {/* Example: Wave as wallet (redundant if you also use "wave" as payoutMethod itself) */}
              {restaurant.payoutWalletProvider === "wave" && (
                <InfoRow icon={<FaPhone />} label="Wave Phone">
                  {restaurant.payoutWalletPhone || (
                    <span className="text-gray-400">N/A</span>
                  )}
                </InfoRow>
              )}
              {/* Add more e-wallet providers as needed */}
              {/* Example: if provider has QR or account email/id */}
              {restaurant.payoutWalletProvider === "om" && (
                <InfoRow icon={<FaRegFileAlt />} label="OM Account ID">
                  {restaurant.payoutWalletOmId || (
                    <span className="text-gray-400">N/A</span>
                  )}
                </InfoRow>
              )}
            </>
          )}

          {/* CASH (if you support cash payout) */}
          {restaurant.payoutMethod === "cash" && (
            <InfoRow icon={<FaRegFileAlt />} label="Details">
              <span>Cash — see accounting</span>
            </InfoRow>
          )}

          {/* FALLBACK: nothing else applied */}
          {!restaurant.payoutMethod && (
            <InfoRow icon={<FaRegFileAlt />} label="Details">
              <span className="text-gray-400">No payout info provided.</span>
            </InfoRow>
          )}
        </SectionCard>

        {/* DOCUMENTS */}
        <SectionTitle>Documents</SectionTitle>
        <div className="flex flex-wrap gap-2 px-8 mb-2">
          {restaurant.businessRegistrationDocumentUrl && (
            <DocTag href={restaurant.businessRegistrationDocumentUrl}>
              registration
            </DocTag>
          )}
          {restaurant.hygieneCertificateUrl && (
            <DocTag href={restaurant.hygieneCertificateUrl}>hygiene</DocTag>
          )}
          {restaurant.proofOfOwnershipOrLeaseUrl && (
            <DocTag href={restaurant.proofOfOwnershipOrLeaseUrl}>
              ownership
            </DocTag>
          )}
          {!(
            restaurant.businessRegistrationDocumentUrl ||
            restaurant.hygieneCertificateUrl ||
            restaurant.proofOfOwnershipOrLeaseUrl
          ) && (
            <span className="text-xs text-gray-400">
              No documents uploaded.
            </span>
          )}
        </div>

        {/* PERFORMANCE */}
        <SectionTitle>Performance</SectionTitle>
        <div className="flex justify-between items-stretch px-8 mb-2">
          <PerfBox value={restaurant.trustScore ?? 0} label="Trust Score" />
          <PerfBox value={restaurant.offersCount ?? 0} label="Offers" />
          <PerfBox
            value={restaurant.ordersCompleted ?? 0}
            label="Orders Completed"
          />
          <PerfBox
            value={`€${(restaurant.totalSales ?? 0).toFixed(2)}`}
            label="Total Sales"
          />
        </div>

        {/* ACCOUNT HISTORY */}
        <SectionTitle>Account History</SectionTitle>
        <div className="px-8 pb-4 mb-4">
          <ol className="border-l-2 border-green-100 pl-3">
            {(restaurant.accountHistory ?? []).map((entry, i) => {
              let icon = <FaCheckCircle className="text-green-500" />;
              if (
                entry.actionType === "SUSPEND" ||
                entry.actionType === "REJECT"
              ) {
                icon = <FaRegIdCard className="text-red-500" />;
              } else if (
                entry.actionType === "REQUIRE_CHANGES" ||
                entry.actionType === "PROFILE_EDIT"
              ) {
                icon = <FaRegFileAlt className="text-yellow-500" />;
              } else if (
                entry.actionType === "UNSUSPEND" ||
                entry.actionType === "APPROVE"
              ) {
                icon = <FaCheckCircle className="text-green-500" />;
              }
              return (
                <li key={i} className="mb-4 flex items-start gap-2">
                  <span className="mt-1 flex-shrink-0">{icon}</span>
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
              );
            })}
          </ol>
          {(!restaurant.accountHistory ||
            restaurant.accountHistory.length === 0) && (
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
