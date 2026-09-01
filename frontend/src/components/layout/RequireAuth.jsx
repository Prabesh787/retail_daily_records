import { useEffect } from 'react';
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { Navigate, Outlet, useLocation } from 'react-router-dom';
import { AUTH_EXPIRED_EVENT, api, getToken } from '@/lib/api';
import { queryKeys } from '@/lib/api/query-keys';
import { Skeleton } from '@/components/ui';

/**
 * Gate in front of every screen that reads shop data.
 *
 * The check is a real request rather than "is there a token in storage": a
 * token can be expired, revoked, or signed with a secret the server no longer
 * uses, and only the server can say. `/auth/me` is that question, and its
 * answer is cached under the same key the header and More screen already read,
 * so asking costs one request per session rather than one per screen.
 */
export function RequireAuth() {
  const location = useLocation();
  const queryClient = useQueryClient();

  const { data, isPending, isError } = useQuery({
    queryKey: queryKeys.me,
    queryFn: api.me,
    // A 401 is a settled answer, not a blip worth retrying.
    retry: false,
    staleTime: 5 * 60_000,
    // Without a token there is nothing to verify - go straight to the login
    // screen instead of spending a round trip to be told so.
    enabled: Boolean(getToken()),
  });

  // A session can die mid-use. When any request comes back 401, drop the
  // cached identity so this gate re-evaluates and redirects.
  useEffect(() => {
    const onExpired = () => queryClient.setQueryData(queryKeys.me, undefined);
    window.addEventListener(AUTH_EXPIRED_EVENT, onExpired);
    return () => window.removeEventListener(AUTH_EXPIRED_EVENT, onExpired);
  }, [queryClient]);

  if (!getToken() || isError) {
    // `from` is carried so signing in resumes wherever the user was going.
    return <Navigate to="/login" replace state={{ from: location.pathname + location.search }} />;
  }

  if (isPending || !data) return <SessionSkeleton />;

  return <Outlet />;
}

/** Shown for the one request it takes to confirm the session. */
function SessionSkeleton() {
  return (
    <main className="scroll-area min-h-0 flex-1 p-4">
      <div className="flex flex-col gap-4">
        <Skeleton className="h-11 w-1/2 rounded-xl" />
        <Skeleton className="rounded-card h-[186px]" />
        <div className="grid grid-cols-2 gap-3">
          <Skeleton className="rounded-card h-[78px]" />
          <Skeleton className="rounded-card h-[78px]" />
        </div>
      </div>
    </main>
  );
}
