import { useQuery } from '@tanstack/react-query';
import { Link, useNavigate } from 'react-router-dom';
import {
  ArrowDownLeft,
  ArrowUpRight,
  Banknote,
  CalendarClock,
  ChevronRight,
  ReceiptText,
  Wallet,
} from 'lucide-react';
import { Screen } from '@/components/layout/Screen';
import {
  Avatar,
  Card,
  Divider,
  SectionHeader,
  Skeleton,
  StatTile,
  TrendChart,
} from '@/components/ui';
import { PurchaseRow, SaleRow } from '@/components/domain';
import { api } from '@/lib/api';
import { queryKeys } from '@/lib/api/query-keys';
import {
  daysUntil,
  formatDateAd,
  formatDateBs,
  formatMoney,
  formatMoneyShort,
  toNumber,
} from '@/lib/format';

const QUICK_ACTIONS = [
  { to: '/purchases/new', label: 'Purchase', icon: ArrowDownLeft, tone: 'bg-out-soft text-out' },
  { to: '/sales/new', label: 'Sale', icon: ArrowUpRight, tone: 'bg-in-soft text-in' },
  { to: '/payments/new', label: 'Pay', icon: Banknote, tone: 'bg-info-soft text-info' },
  { to: '/cheques', label: 'Cheques', icon: CalendarClock, tone: 'bg-pending-soft text-pending' },
];

export function DashboardScreen() {
  const navigate = useNavigate();

  const { data: profile } = useQuery({ queryKey: queryKeys.me, queryFn: api.me });
  const { data: fiscalYear } = useQuery({
    queryKey: queryKeys.fiscalYears,
    queryFn: api.fiscalYears.active,
  });
  const { data, isLoading } = useQuery({
    queryKey: queryKeys.dashboard(),
    queryFn: () => api.reports.dashboard(),
  });

  const now = new Date();
  const greeting =
    now.getHours() < 12 ? 'Good morning' : now.getHours() < 17 ? 'Good afternoon' : 'Good evening';

  return (
    <Screen
      title={
        <div className="flex items-center gap-3 pb-1">
          <Avatar name={profile?.user?.name ?? 'Shop'} />
          <div className="min-w-0 flex-1">
            <div className="text-[21px] leading-tight font-bold tracking-[-0.03em]">{greeting}</div>
            <div className="text-ink-muted text-[12.5px] font-normal">
              {formatDateBs(data?.today?.dateBs, { long: true }) ?? formatDateAd(now)}
              {fiscalYear ? ` · FY ${fiscalYear.name}` : ''}
            </div>
          </div>
        </div>
      }
    >
      {isLoading || !data ? <DashboardSkeleton /> : null}

      {data ? (
        <div className="flex flex-col gap-4">
          <Card>
            <div className="flex flex-col gap-3">
              <div className="flex items-start justify-between gap-3">
                <div>
                  <p className="label-section">Sales today</p>
                  <p className="text-in text-[30px] font-bold tracking-[-0.035em] tabular-nums">
                    {formatMoney(data.today.salesTotal, { decimals: false })}
                  </p>
                  <p className="text-ink-subtle text-[11.5px]">
                    {data.today.salesCount} record{data.today.salesCount === 1 ? '' : 's'} ·{' '}
                    {formatMoneyShort(data.window.salesTotal)} in 30 days
                  </p>
                </div>
                <Link to="/sales" aria-label="All sales" className="text-ink-subtle">
                  <ChevronRight size={20} />
                </Link>
              </div>
              <TrendChart points={data.trend} />
            </div>
          </Card>

          <div className="grid grid-cols-2 gap-3">
            <StatTile
              icon={Wallet}
              label="Payable to suppliers"
              value={formatMoneyShort(data.payable.total)}
              foot={`${data.payable.supplierCount} supplier${data.payable.supplierCount === 1 ? '' : 's'}`}
              tone="out"
              onClick={() => navigate('/suppliers')}
            />
            <StatTile
              icon={CalendarClock}
              label="Cheques not cleared"
              value={formatMoneyShort(data.cheques.total)}
              foot={`${data.cheques.count} awaiting`}
              tone="pending"
              onClick={() => navigate('/cheques')}
            />
          </div>

          <NextChequeAlert cheque={data.cheques.next?.[0]} onOpen={() => navigate('/cheques')} />

          <nav aria-label="Quick actions" className="grid grid-cols-4 gap-2">
            {QUICK_ACTIONS.map(({ to, label, icon: Icon, tone }) => (
              <Link
                key={to}
                to={to}
                className="bg-surface border-line text-ink-muted rounded-tile ease-out-quart flex flex-col items-center gap-1.5 border px-1 py-3 text-center text-[11px] font-semibold transition-transform duration-150 active:scale-95"
              >
                <span className={`grid size-9 place-items-center rounded-xl ${tone}`}>
                  <Icon size={18} strokeWidth={2.1} />
                </span>
                {label}
              </Link>
            ))}
          </nav>

          <section className="mt-2">
            <SectionHeader
              title="Owed the most"
              action="All suppliers"
              onAction={() => navigate('/suppliers')}
            />
            <Card padded={false}>
              {data.payable.top.map((entry, index) => (
                <div key={entry.supplier.id}>
                  {index > 0 ? <Divider /> : null}
                  <Link
                    to={`/suppliers/${entry.supplier.id}`}
                    className="active:bg-sunken flex flex-col gap-1.5 px-4 py-3 transition-colors"
                  >
                    <span className="flex items-baseline justify-between gap-3">
                      <span className="truncate text-sm font-semibold">{entry.supplier.name}</span>
                      <span className="text-out shrink-0 text-sm font-bold tabular-nums">
                        {formatMoney(entry.balance.outstanding, { decimals: false })}
                      </span>
                    </span>
                    {/* Share of the largest exposure, so the ranking is legible
                        without reading four numbers. */}
                    <span className="bg-sunken block h-[5px] overflow-hidden rounded-full">
                      <span
                        className="bg-out ease-out-quart block h-full rounded-full transition-[width] duration-300"
                        style={{
                          width: `${Math.max(
                            4,
                            (toNumber(entry.balance.outstanding) /
                              Math.max(toNumber(data.payable.top[0].balance.outstanding), 1)) *
                              100,
                          )}%`,
                        }}
                      />
                    </span>
                  </Link>
                </div>
              ))}
            </Card>
          </section>

          <RecentSection
            title="Latest sales"
            onSeeAll={() => navigate('/sales')}
            items={data.recentSales}
            render={(sale) => <SaleRow sale={sale} />}
          />

          <RecentSection
            title="Latest bills"
            onSeeAll={() => navigate('/purchases')}
            items={data.recentPurchases}
            render={(purchase) => <PurchaseRow purchase={purchase} />}
          />
        </div>
      ) : null}
    </Screen>
  );
}

function RecentSection({ title, items, render, onSeeAll }) {
  return (
    <section className="mt-2">
      <SectionHeader title={title} action="See all" onAction={onSeeAll} />
      <Card padded={false}>
        {items.map((item, index) => (
          <div key={item.id}>
            {index > 0 ? <Divider /> : null}
            {render(item)}
          </div>
        ))}
      </Card>
    </section>
  );
}

/** The one cheque that needs attention next — or nothing at all. */
function NextChequeAlert({ cheque, onOpen }) {
  if (!cheque) return null;

  const days = daysUntil(cheque.chequeDate);
  const when =
    days < 0 ? `${Math.abs(days)} days overdue` : days === 0 ? 'due today' : `due in ${days} days`;

  return (
    <button
      type="button"
      onClick={onOpen}
      className="bg-pending-soft text-pending rounded-card ease-out-quart flex w-full items-center gap-3 px-4 py-3 text-left transition-transform duration-150 active:scale-[0.985]"
    >
      <span className="grid size-[34px] shrink-0 place-items-center rounded-xl bg-current/15">
        <ReceiptText size={17} />
      </span>
      <span className="min-w-0 flex-1">
        <span className="block text-[13.5px] font-semibold">
          Cheque {cheque.chequeNo} {when}
        </span>
        <span className="block truncate text-xs opacity-85">
          {formatMoney(cheque.amount, { decimals: false })} to {cheque.supplier?.name}
        </span>
      </span>
      <ChevronRight size={18} />
    </button>
  );
}

function DashboardSkeleton() {
  return (
    <div className="flex flex-col gap-4">
      <Skeleton className="rounded-card h-[186px]" />
      <div className="grid grid-cols-2 gap-3">
        <Skeleton className="rounded-card h-[78px]" />
        <Skeleton className="rounded-card h-[78px]" />
      </div>
      <Skeleton className="rounded-card h-[60px]" />
      <Skeleton className="rounded-card h-[150px]" />
    </div>
  );
}
