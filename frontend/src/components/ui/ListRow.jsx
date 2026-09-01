import { ChevronRight } from 'lucide-react';
import { cn } from '@/lib/cn';

/**
 * The row every list in the app is built from: a leading slot, two lines of
 * text, a trailing amount or badge, and an optional chevron.
 */
export function ListRow({
  as: Tag = 'div',
  leading,
  title,
  subtitle,
  trailing,
  chevron = false,
  className,
  ...rest
}) {
  return (
    <Tag
      className={cn(
        'bg-surface active:bg-sunken flex w-full items-center gap-3 px-4 py-3 text-left',
        'ease-out-quart transition-colors duration-150',
        className,
      )}
      {...rest}
    >
      {leading}
      <span className="min-w-0 flex-1">
        <span className="block truncate text-[14.5px] font-semibold tracking-[-0.01em]">
          {title}
        </span>
        {subtitle ? (
          <span className="text-ink-muted mt-px block truncate text-[12.5px]">{subtitle}</span>
        ) : null}
      </span>
      {trailing ? (
        <span className="flex shrink-0 flex-col items-end gap-[3px]">{trailing}</span>
      ) : null}
      {chevron ? (
        <ChevronRight size={17} aria-hidden className="text-ink-subtle -ml-1 shrink-0" />
      ) : null}
    </Tag>
  );
}

const AMOUNT_TONES = { in: 'text-in', out: 'text-out', pending: 'text-pending' };

export function RowAmount({ tone, children }) {
  return (
    <span
      className={cn('text-[14.5px] font-bold tracking-[-0.01em] tabular-nums', AMOUNT_TONES[tone])}
    >
      {children}
    </span>
  );
}

/** A hairline that stops short of the left edge, the way native lists do. */
export function Divider({ full = false }) {
  return <div role="presentation" className={cn('bg-line h-px', full ? 'ml-0' : 'ml-4')} />;
}
