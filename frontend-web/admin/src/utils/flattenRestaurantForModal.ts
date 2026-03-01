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

export function flattenRestaurantForModal(user: any) {
  const base: any = { ...user };
  if (user.restaurantProfile) Object.assign(base, user.restaurantProfile);
  if (user.livreurProfile) Object.assign(base, user.livreurProfile);
  if (user.clientProfile) Object.assign(base, user.clientProfile);

  if (user.accountHistory) {
    base.accountHistory = user.accountHistory
      .slice()
      .reverse()
      .map((entry: AccountHistoryEntry) => {
        // Map action to label and descriptive fields only, NO JSX!
        let label = "";
        switch (entry.action) {
          case "SUSPEND":
            label = "Account suspended";
            break;
          case "UNSUSPEND":
            label = "Account reactivated";
            break;
          case "APPROVE":
            label = "Application approved";
            break;
          case "REJECT":
            label = "Application rejected";
            break;
          case "REQUIRE_CHANGES":
            label = "Revision requested";
            break;
          case "PROFILE_EDIT":
            label = "Profile updated";
            break;
          default:
            label = entry.action;
        }
        let description = entry.reason || "";
        if (!description && entry.action === "APPROVE")
          description = "Documents verified";
        if (!description && entry.action === "PROFILE_EDIT" && entry.field)
          description = `Changed ${entry.field}: ${entry.oldValue ?? ""} → ${entry.newValue ?? ""}`;
        return {
          action: label,
          description,
          date: new Date(entry.createdAt).toLocaleDateString(),
          actor: entry.actorId
            ? `${entry.actorRole === "ADMIN" ? "Admin" : "User"} (${entry.actorId})`
            : "",
          actionType: entry.action, // <-- Keep for JSX icon mapping
        };
      });
  }

  return base;
}
