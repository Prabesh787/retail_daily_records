import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { Link, useNavigate } from 'react-router-dom';
import {
  CalendarClock,
  CalendarRange,
  ChevronRight,
  Database,
  LogOut,
  Moon,
  Plus,
  Store,
  UserRound,
} from 'lucide-react';
import { Screen } from '@/components/layout/Screen';
import {
  Avatar,
  Badge,
  Button,
  Card,
  Divider,
  SectionHeader,
  SegmentedControl,
  useToast,
} from '@/components/ui';
import { api, API_MODE } from '@/lib/api';
import { queryKeys } from '@/lib/api/query-keys';
import { useTheme } from '@/hooks/useTheme';
import { formatDateAd } from '@/lib/format';

const LINKS = [
  { to: '/cheques', label: 'Cheque register', hint: 'Issued and cleared', icon: CalendarClock },
  { to: '/customers', label: 'Customers', hint: 'Invoice customers only', icon: UserRound },
];

/**
 * The address and PAN under the shop name, skipping whichever of them is not
 * filled in — a shop with no PAN should read "Butwal-11, Rupandehi", not
 * "Butwal-11, Rupandehi · PAN null".
 */
function shopSubtitle(shop) {
  if (!shop?.name) return 'Not set yet — tap to add';
  const parts = [shop.address, shop.pan ? `PAN ${shop.pan}` : null].filter(Boolean);
  return parts.length ? parts.join(' · ') : 'Tap to add an address and PAN';
}

const THEMES = [
  { value: 'light', label: 'Light' },
  { value: 'dark', label: 'Dark' },
  { value: 'system', label: 'System' },
];

export function MoreScreen() {
  const { preference, setPreference } = useTheme();
  const navigate = useNavigate();
  const toast = useToast();
  const queryClient = useQueryClient();

  const { data: profile } = useQuery({ queryKey: queryKeys.me, queryFn: api.me });
  const { data: fiscalYears } = useQuery({
    queryKey: ['fiscal-years', 'all'],
    queryFn: api.fiscalYears.list,
  });

  const activate = useMutation({
    mutationFn: (id) => api.fiscalYears.activate(id),
    onSuccess: (year) => {
      queryClient.invalidateQueries({ queryKey: ['fiscal-years'] });
      queryClient.invalidateQueries({ queryKey: ['dashboard'] });
      toast.success(`${year.name} is now the active year`);
    },
    onError: (error) => toast.error(error.message),
  });

  /**
   * Signing out drops the token and empties the cache. Clearing matters: the
   * next person to sign in on this phone must not see the last one's data
   * flash up before their own loads.
   */
  const signOut = () => {
    api.auth.logout();
    queryClient.clear();
    navigate('/login', { replace: true });
  };

  return (
    <Screen title="More">
      <div className="flex flex-col gap-4">
        <Card padded={false}>
          <div className="flex items-center gap-3 p-4">
            <Avatar name={profile?.user?.name ?? 'Shop'} />
            <div className="min-w-0 flex-1">
              <p className="truncate text-[15px] font-semibold">{profile?.user?.name}</p>
              <p className="text-ink-muted truncate text-[12.5px]">{profile?.user?.email}</p>
            </div>
            <Badge tone="info" dot={false}>
              {profile?.user?.role}
            </Badge>
          </div>
          <Divider />
          <Link to="/shop" className="active:bg-sunken flex items-center gap-3 p-4">
            <span className="bg-sunken text-ink-muted rounded-tile grid size-[42px] shrink-0 place-items-center">
              <Store size={18} />
            </span>
            <div className="min-w-0 flex-1">
              <p className="truncate text-[15px] font-semibold">
                {profile?.shop?.name ?? 'Shop details'}
              </p>
              <p className="text-ink-muted truncate text-[12.5px]">{shopSubtitle(profile?.shop)}</p>
            </div>
            <ChevronRight size={17} className="text-ink-subtle" />
          </Link>
        </Card>

        <section>
          <SectionHeader title="Records" />
          <Card padded={false}>
            {LINKS.map(({ to, label, hint, icon: Icon }, index) => (
              <div key={to}>
                {index > 0 ? <Divider /> : null}
                <Link to={to} className="active:bg-sunken flex items-center gap-3 px-4 py-3">
                  <span className="bg-sunken text-ink-muted grid size-9 shrink-0 place-items-center rounded-xl">
                    <Icon size={17} />
                  </span>
                  <span className="min-w-0 flex-1">
                    <span className="block text-[14.5px] font-semibold">{label}</span>
                    <span className="text-ink-muted block text-[12.5px]">{hint}</span>
                  </span>
                  <ChevronRight size={17} className="text-ink-subtle" />
                </Link>
              </div>
            ))}
          </Card>
        </section>

        <section>
          <SectionHeader title="Fiscal years" />
          <Card padded={false}>
            {(fiscalYears ?? []).map((year, index) => (
              <div key={year.id}>
                {index > 0 ? <Divider /> : null}
                <div className="flex items-center gap-3 px-4 py-3">
                  <span className="bg-sunken text-ink-muted grid size-9 shrink-0 place-items-center rounded-xl">
                    <CalendarRange size={17} />
                  </span>
                  <span className="min-w-0 flex-1">
                    <span className="block text-[14.5px] font-semibold">{year.name}</span>
                    <span className="text-ink-muted block text-[12.5px]">
                      {formatDateAd(year.startDate)} — {formatDateAd(year.endDate)}
                    </span>
                  </span>
                  {year.isActive ? (
                    <Badge tone="success">Active</Badge>
                  ) : (
                    <Button
                      size="sm"
                      variant="soft"
                      loading={activate.isPending && activate.variables === year.id}
                      onClick={() => activate.mutate(year.id)}
                    >
                      Activate
                    </Button>
                  )}
                </div>
              </div>
            ))}
            {fiscalYears?.length === 0 ? (
              <div className="px-4 py-6 text-center">
                <p className="text-ink-muted text-[13.5px]">No fiscal years yet.</p>
              </div>
            ) : null}
            <Divider />
            <Link
              to="/fiscal-years/new"
              className="active:bg-sunken text-brand flex items-center gap-3 px-4 py-3 text-[14.5px] font-semibold"
            >
              <span className="bg-brand-50 grid size-9 shrink-0 place-items-center rounded-xl">
                <Plus size={17} />
              </span>
              Add a fiscal year
            </Link>
          </Card>
        </section>

        <section>
          <SectionHeader title="Appearance" />
          <Card>
            <div className="flex flex-col gap-3">
              <span className="text-ink-muted flex items-center gap-2 text-[13px] font-semibold">
                <Moon size={14} /> Theme
              </span>
              <SegmentedControl options={THEMES} value={preference} onChange={setPreference} />
            </div>
          </Card>
        </section>

        <section>
          <SectionHeader title="Data source" />
          <Card>
            <div className="flex items-start gap-3">
              <span className="bg-sunken text-ink-muted grid size-9 shrink-0 place-items-center rounded-xl">
                <Database size={17} />
              </span>
              <div className="min-w-0 flex-1">
                <p className="text-[14.5px] font-semibold">
                  {API_MODE === 'mock' ? 'Sample data' : 'Live API'}
                </p>
                <p className="text-ink-muted text-[12.5px]">
                  {API_MODE === 'mock'
                    ? 'Running on in-memory fixtures. Set VITE_API_MODE=live in .env to talk to the Express backend.'
                    : 'Reading and writing through /api/v1 on the Express backend.'}
                </p>
              </div>
            </div>
          </Card>
        </section>

        <Button variant="secondary" size="lg" block icon={LogOut} onClick={signOut}>
          Sign out
        </Button>
      </div>
    </Screen>
  );
}
