import { useState } from 'react';
import { Outlet, useLocation } from 'react-router-dom';
import { Moon, Sun } from 'lucide-react';
import { useMediaQuery } from '@/hooks/useMediaQuery';
import { useTheme } from '@/hooks/useTheme';
import { API_MODE } from '@/lib/api';
import { cn } from '@/lib/cn';
import { BottomNav } from './BottomNav';

/** Sizes matched to the handsets this shop is most likely to be holding. */
const DEVICES = [
  { id: 'compact', label: 'iPhone SE', width: 375, height: 667 },
  { id: 'standard', label: 'iPhone 15', width: 390, height: 844 },
  { id: 'large', label: 'Pixel 8 Pro', width: 412, height: 892 },
];

const PANEL_NOTES = [
  ['Purchases are whole bills.', 'One supplier, one amount, no line items.'],
  ['Balances are derived.', 'Opening + bills − payments, recalculated every time.'],
  ['Cheques have a lifecycle.', 'Issued today, cleared when the money actually moves.'],
  ['Dates come in pairs.', 'BS for the shopkeeper, AD for sorting and filtering.'],
];

/**
 * On a phone this is simply the app. On a desktop the same tree is dropped
 * into a device frame, so the mobile layout can be judged at real proportions
 * instead of stretched across a browser window.
 */
export function AppShell() {
  const framed = useMediaQuery('(min-width: 900px)');
  const [device, setDevice] = useState(DEVICES[1]);
  const { resolved, toggle } = useTheme();
  const location = useLocation();

  // Full-screen forms hide the tab bar: while a record is half-entered the only
  // ways out should be Save and Cancel. The login screen hides it because there
  // is nothing behind it to navigate to yet.
  const bare = /\/new(\/|$)/.test(location.pathname) || location.pathname === '/login';

  const app = (
    <div className={cn('flex h-full flex-col', framed && 'pt-11')}>
      <Outlet />
      {bare ? null : <BottomNav />}
    </div>
  );

  if (!framed) {
    return (
      <div className="bg-bg min-h-dvh">
        <div className="bg-bg relative h-dvh w-full overflow-hidden">{app}</div>
      </div>
    );
  }

  // Three columns with matching 1fr sides, so the phone sits dead centre in the
  // window whether or not the notes panel is showing beside it.
  return (
    <div className="grid min-h-dvh items-center justify-center gap-8 bg-[radial-gradient(1200px_600px_at_50%_-10%,var(--brand-50),transparent_60%)] p-8 xl:grid-cols-[1fr_auto_1fr]">
      <aside className="hidden max-w-[420px] justify-self-end xl:block">
        <p className="bg-pending-soft text-pending inline-flex items-center gap-1.5 rounded-full px-2.5 py-1 text-xs font-semibold">
          <span aria-hidden className="size-1.5 rounded-full bg-current" />
          {API_MODE === 'mock' ? 'Sample data' : 'Live API'}
        </p>
        <h1 className="mt-3 mb-3 text-3xl font-bold tracking-[-0.035em]">Shop Records</h1>
        <p className="text-ink-muted mb-5 text-[14.5px] leading-relaxed">
          The phone interface for the retail transaction system — purchases, supplier payments,
          sales, and the cheques that have not cleared yet. Narrow the window or open it on a phone
          and the frame drops away.
        </p>
        <div className="grid gap-2">
          {PANEL_NOTES.map(([strong, rest]) => (
            <p key={strong} className="text-ink-muted flex items-start gap-3 text-[13.5px]">
              <span
                aria-hidden
                className="bg-brand-500 mt-[7px] size-[7px] shrink-0 rounded-full"
              />
              <span>
                <strong className="text-ink font-semibold">{strong}</strong> {rest}
              </span>
            </p>
          ))}
        </div>
      </aside>

      <div className="flex flex-col items-center gap-4 justify-self-center">
        <div
          style={{ width: device.width, height: device.height }}
          className="relative max-h-[calc(100dvh-130px)] rounded-[54px] bg-linear-160 from-[#2b3244] to-[#12161f] p-3 shadow-[0_0_0_2px_rgb(255_255_255/0.06)_inset,0_40px_80px_-30px_rgb(0_0_0/0.55)]"
        >
          <div className="bg-bg relative isolate h-full w-full overflow-hidden rounded-[42px]">
            {/* Dynamic-island cutout, purely cosmetic. */}
            <span
              aria-hidden
              className="pointer-events-none absolute top-3 left-1/2 z-40 h-7 w-[108px] -translate-x-1/2 rounded-full bg-[#05070c]"
            />
            <StatusBar />
            {app}
          </div>
        </div>

        <div className="bg-surface border-line shadow-card flex items-center gap-2 rounded-full border p-2">
          {DEVICES.map((option) => (
            <button
              key={option.id}
              type="button"
              onClick={() => setDevice(option)}
              className={cn(
                'h-[30px] rounded-full px-3 text-[12.5px] font-semibold transition-colors',
                device.id === option.id ? 'bg-brand text-white' : 'text-ink-muted',
              )}
            >
              {option.label}
            </button>
          ))}
          <button
            type="button"
            onClick={toggle}
            aria-label="Toggle dark mode"
            className="text-ink-muted h-[30px] rounded-full px-3"
          >
            {resolved === 'dark' ? <Sun size={15} /> : <Moon size={15} />}
          </button>
        </div>
      </div>

      {/* Balances the notes panel so the phone column stays centred. */}
      <div aria-hidden className="hidden xl:block" />
    </div>
  );
}

/** Cosmetic only — it makes the frame read as a phone at a glance. */
function StatusBar() {
  const time = new Date().toLocaleTimeString('en-GB', { hour: '2-digit', minute: '2-digit' });
  return (
    <div
      aria-hidden
      className="text-ink pointer-events-none absolute inset-x-0 top-0 z-30 flex h-11 items-center justify-between px-7 text-[13px] font-semibold"
    >
      <span>{time}</span>
      <span className="flex items-center gap-1.5">
        <svg width="16" height="11" viewBox="0 0 16 11" fill="currentColor">
          <rect x="0" y="7" width="3" height="4" rx="1" />
          <rect x="4.3" y="5" width="3" height="6" rx="1" />
          <rect x="8.6" y="2.5" width="3" height="8.5" rx="1" />
          <rect x="12.9" y="0" width="3" height="11" rx="1" opacity="0.35" />
        </svg>
        <span className="relative h-[11px] w-[22px] rounded-[3px] border-[1.4px] border-current opacity-85 after:absolute after:top-[2.5px] after:left-[1.5px] after:h-1 after:w-3 after:rounded-[1px] after:bg-current after:content-['']" />
      </span>
    </div>
  );
}
