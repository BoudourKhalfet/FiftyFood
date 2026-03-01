type AccountHistoryEntry = {
  action: string;
  reason?: string | null;
  createdAt: string;
  actorId?: string | null;
  actorRole?: string | null;
  field?: string | null;
  oldValue?: string | null;
  newValue?: string | null;
};

export function flattenDelivererForModal(user: any) {
  const base: any = { ...user };
  if (user.livreurProfile) Object.assign(base, user.livreurProfile);

  if (user.accountHistory) {
    base.accountHistory = user.accountHistory
      .slice()
      .reverse()
      .map((entry: AccountHistoryEntry) => {
        let label = "";
        switch (entry.action) {
          case "SUSPEND":
            label = "Account suspended";
            break;
          case "UNSUSPEND":
            label = "Account reactivated";
            break;
          case "PROFILE_EDIT":
          case "PROFILE_UPDATED":
            label = "Profile updated";
            break;
          case "DELIVERER_APPROVED":
          case "APPROVED":
            label = "Deliverer verified";
            break;
          case "REJECTED":
          case "REJECT":
            label = "Deliverer rejected";
            break;
          case "ACCOUNT_CREATED":
            label = "Account created";
            break;
          case "EMAIL_VERIFIED":
          case "ACCOUNT_VERIFIED":
            label = "Account verified";
            break;
          case "WARNING":
            label = "Warning issued";
            break;
          default:
            label = entry.action;
        }
        let description = entry.reason || "";
        if (
          !description &&
          (entry.action === "DELIVERER_APPROVED" || entry.action === "APPROVED")
        )
          description = "Verification successful";
        if (!description && entry.action === "PROFILE_EDIT" && entry.field)
          description = `Changed ${entry.field}: ${entry.oldValue ?? ""} → ${entry.newValue ?? ""}`;
        if (!description && entry.action === "ACCOUNT_CREATED")
          description = "Signed up via email";
        if (
          !description &&
          (entry.action === "EMAIL_VERIFIED" ||
            entry.action === "ACCOUNT_VERIFIED")
        )
          description = "Email verified";

        return {
          action: label,
          description,
          date: new Date(entry.createdAt).toLocaleDateString(),
          actor: entry.actorId
            ? `${entry.actorRole === "ADMIN" ? "Admin" : "User"} (${entry.actorId})`
            : "",
          actionType: entry.action, // For icon mapping
        };
      });
  }

  return base;
}
