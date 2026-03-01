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

export function flattenClientForModal(user: any) {
  const base: any = { ...user };
  if (user.clientProfile) Object.assign(base, user.clientProfile);

  // Format accountHistory properly for nice timeline
  if (user.accountHistory && Array.isArray(user.accountHistory)) {
    base.accountHistory = user.accountHistory
      .slice()
      .reverse()
      .map((entry: AccountHistoryEntry) => {
        let label = "";
        let description = entry.reason || "";
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
            if (!description && entry.field)
              description = `Changed ${entry.field}: ${entry.oldValue ?? ""} → ${entry.newValue ?? ""}`;
            break;
          case "ACCOUNT_CREATED":
            label = "Account created";
            if (!description) description = "Signed up via email";
            break;
          case "EMAIL_VERIFIED":
          case "ACCOUNT_VERIFIED":
            label = "Account verified";
            if (!description) description = "Email verified";
            break;
          case "WARNING":
            label = "Warning issued";
            break;
          default:
            label = entry.action;
        }
        let actor = "";
        if (entry.actorId) {
          if (entry.actorRole === "SYSTEM") actor = "System";
          else if (entry.actorRole === "ADMIN")
            actor = `Admin (${entry.actorId})`;
        }

        return {
          action: label,
          description,
          date: entry.createdAt
            ? new Date(entry.createdAt).toLocaleString()
            : "",
          actor,
          actionType: entry.action, // for icon mapping use only!
        };
      });
  }

  return base;
}
