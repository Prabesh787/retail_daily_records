/**
 * Thin fetch wrapper around the Express API.
 *
 * The backend answers with exactly two envelopes:
 *   { success: true,  message, data, meta? }
 *   { success: false, message, code, errors: [] }
 *
 * Callers only ever want `data` (and `meta` when paging), so unwrapping happens
 * once here and failures become a typed `ApiError` instead of a raw Response.
 */

import { clearToken, getToken, notifyAuthExpired } from './auth-token.js';

const BASE_URL = import.meta.env.VITE_API_BASE_URL || '/api/v1';

export class ApiError extends Error {
  constructor(message, { status, code, errors = [] } = {}) {
    super(message);
    this.name = 'ApiError';
    this.status = status;
    this.code = code;
    this.errors = errors;
  }

  /** Field-level messages keyed by the path the server reported. */
  get fieldErrors() {
    return Object.fromEntries(
      this.errors
        .filter((e) => e.field)
        .map((e) => [String(e.field).replace(/^body\./, ''), e.message]),
    );
  }
}

function buildUrl(path, params) {
  const url = `${BASE_URL}${path}`;
  if (!params) return url;
  const search = new URLSearchParams();
  for (const [key, value] of Object.entries(params)) {
    if (value === undefined || value === null || value === '') continue;
    search.append(key, String(value));
  }
  const qs = search.toString();
  return qs ? `${url}?${qs}` : url;
}

/** Every request carries the session, when there is one. */
function buildHeaders(body) {
  const headers = {};
  if (body) headers['Content-Type'] = 'application/json';
  const token = getToken();
  if (token) headers.Authorization = `Bearer ${token}`;
  return headers;
}

export async function httpRequest(path, { method = 'GET', params, body, signal } = {}) {
  let response;
  try {
    response = await fetch(buildUrl(path, params), {
      method,
      signal,
      headers: buildHeaders(body),
      body: body ? JSON.stringify(body) : undefined,
    });
  } catch (cause) {
    if (cause?.name === 'AbortError') throw cause;
    throw new ApiError('Cannot reach the server. Check your connection.', { code: 'NETWORK' });
  }

  if (response.status === 204) return { data: null };

  const payload = await response.json().catch(() => null);

  // The session is gone: drop the dead token and let the app move the user to
  // the login screen, instead of every open query failing on its own.
  if (response.status === 401) {
    clearToken();
    notifyAuthExpired();
  }

  if (!response.ok || payload?.success === false) {
    throw new ApiError(payload?.message || `Request failed (${response.status})`, {
      status: response.status,
      code: payload?.code,
      errors: payload?.errors ?? [],
    });
  }

  return { data: payload?.data ?? null, meta: payload?.meta };
}
