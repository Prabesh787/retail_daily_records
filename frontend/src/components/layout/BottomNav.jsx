import { NavLink } from 'react-router-dom';
import { ArrowDownLeft, ArrowUpRight, Home, MoreHorizontal, Users } from 'lucide-react';
import { cn } from '@/lib/cn';

/**
 * Five destinations is the practical ceiling for a thumb-reachable tab bar.
 * Everything else — customers, the cheque register, fiscal years — lives under
 * More rather than being squeezed in here.
 */
const TABS = [
  { to: '/', label: 'Home', icon: Home, end: true },
  { to: '/purchases', label: 'Purchases', icon: ArrowDownLeft },
  { to: '/sales', label: 'Sales', icon: ArrowUpRight },
  { to: '/suppliers', label: 'Suppliers', icon: Users },
  { to: '/more', label: 'More', icon: MoreHorizontal },
];

export function BottomNav({ badges = {} }) {
  return (
    <nav
      aria-label="Main"
      className="bg-surface/90 border-line h-nav pb-safe relative z-20 flex shrink-0 items-stretch border-t backdrop-blur-xl backdrop-saturate-150"
    >
      {TABS.map(({ to, label, icon: Icon, end }) => (
        <NavLink
          key={to}
          to={to}
          end={end}
          className={({ isActive }) =>
            cn(
              'flex flex-1 flex-col items-center justify-center gap-[3px] pt-1.5',
              'text-[10.5px] font-semibold transition-colors duration-150',
              isActive ? 'text-brand' : 'text-ink-subtle',
            )
          }
        >
          {({ isActive }) => (
            <>
              <span
                className={cn(
                  'relative grid h-[26px] w-[46px] place-items-center rounded-full',
                  'ease-spring transition-[background-color,transform] duration-200',
                  isActive && 'bg-brand-50 -translate-y-px',
                )}
              >
                <Icon size={21} strokeWidth={isActive ? 2.3 : 1.9} />
                {badges[to] ? (
                  <span className="bg-out absolute -top-px right-[7px] h-[15px] min-w-[15px] rounded-full px-1 text-center text-[9.5px] leading-[15px] font-bold text-white">
                    {badges[to]}
                  </span>
                ) : null}
              </span>
              {label}
            </>
          )}
        </NavLink>
      ))}
    </nav>
  );
}
