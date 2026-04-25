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
export async function rejectRestaurant(id: string, reason: string) {
  await fetch(`/admin/users/${id}/reject`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: "Bearer " + localStorage.getItem("access_token"),
    },
    body: JSON.stringify({ reason }),
  });
}
export async function requireChangesRestaurant(id: string, reason: string) {
  await fetch(`/admin/users/${id}/require-changes`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: "Bearer " + localStorage.getItem("access_token"),
    },
    body: JSON.stringify({ reason }),
  });
}

export async function fetchAllOrders() {
  const controller = new AbortController();
  const timeoutId = window.setTimeout(() => controller.abort(), 10000);

  try {
    const res = await fetch("/orders", {
      headers: {
        Authorization: "Bearer " + localStorage.getItem("access_token"),
      },
      signal: controller.signal,
    });

    if (!res.ok) {
      throw new Error(`Failed to fetch orders (${res.status})`);
    }

    return await res.json();
  } catch (error) {
    if (error instanceof DOMException && error.name === "AbortError") {
      throw new Error("Request timed out while fetching orders.");
    }
    throw error;
  } finally {
    window.clearTimeout(timeoutId);
  }
}
