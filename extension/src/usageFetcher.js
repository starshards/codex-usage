export async function fetchUsageSource(sourceUrl) {
  const response = await fetch(sourceUrl, {
    method: "GET",
    credentials: "include",
    cache: "no-store"
  });

  if (response.status === 401 || response.status === 403) {
    return { status: "not_logged_in", text: "" };
  }

  if (!response.ok) {
    return { status: "network_failed", text: "" };
  }

  return { status: "ok", text: await response.text() };
}
