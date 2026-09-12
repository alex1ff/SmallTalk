// A search attempt gets one server deadline, including attempts from old clients.
const ACTIVE_SEARCH_MS = 120 * 1000;
function millis(value) {
  if (value == null) return null;
  const result = typeof value.toMillis === "function" ? value.toMillis() :
    value instanceof Date ? value.getTime() : Number(value);
  return Number.isFinite(result) ? result : null;
}
function activeSearchDeadlineMillis(request = {}) {
  const created = millis(request.createdAt);
  const expires = millis(request.expiresAt);
  if (expires === null) return null;
  return created === null ? expires : Math.min(expires, created + ACTIVE_SEARCH_MS);
}
module.exports = {ACTIVE_SEARCH_MS, activeSearchDeadlineMillis};
