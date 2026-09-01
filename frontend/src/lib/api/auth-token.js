/**
 * Where the session lives on the client.
 *
 * localStorage rather than memory, so a reload or a reopened tab does not throw
 * the shopkeeper back to the login screen mid-day. That does mean the token is
 * readable by any script on this origin - acceptable here because the app ships
 * no third-party scripts and the token is short-lived (JWT_EXPIRES_IN, one day
 * by default). If that ever changes, an httpOnly cookie is the move, and this
 * module is the only file that would need to know.
 */

const STORAGE_KEY = 'shop-records.token';

/** Private-mode Safari and "block site data" both make localStorage throw. */
function safely(action, fallback = null) {
  try {
    return action();
  } catch {
    return fallback;
  }
}

export function getToken() {
  return safely(() => window.localStorage.getItem(STORAGE_KEY));
}

export function setToken(token) {
  safely(() => window.localStorage.setItem(STORAGE_KEY, token));
}

export function clearToken() {
  safely(() => window.localStorage.removeItem(STORAGE_KEY));
}

/**
 * Raised when the server rejects the session — an expired or revoked token —
 * so the app can send the user to the login screen from wherever they were,
 * rather than showing an error on a screen that can no longer load anything.
 */
export const AUTH_EXPIRED_EVENT = 'shop-records:auth-expired';

export function notifyAuthExpired() {
  window.dispatchEvent(new Event(AUTH_EXPIRED_EVENT));
}
