export async function fetchPendingRestaurants() {
  const res = await fetch("/admin/users/pending?role=RESTAURANT", {
    headers: {
      Authorization: "Bearer " + localStorage.getItem("access_token"),
    },
  });
  return res.json();
}
export async function approveRestaurant(id: string) {
  await fetch(`/admin/users/${id}/approve`, {
    method: "POST",
    headers: {
      Authorization: "Bearer " + localStorage.getItem("access_token"),
    },
  });
  // Show toast / refetch as needed
}
export async function rejectRestaurant(id: string) {
  const reason = prompt("Reason for rejection?");
  await fetch(`/admin/users/${id}/reject`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: "Bearer " + localStorage.getItem("access_token"),
    },
    body: JSON.stringify({ reason }),
  });
}
export async function requireChangesRestaurant(id: string) {
  const reason = prompt("Improvements required?");
  await fetch(`/admin/users/${id}/require-changes`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: "Bearer " + localStorage.getItem("access_token"),
    },
    body: JSON.stringify({ reason }),
  });
}
