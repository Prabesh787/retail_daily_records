import { cn } from '@/lib/cn';

export function Skeleton({ className, style }) {
  return (
    <span
      aria-hidden
      style={style}
      className={cn(
        'animate-shimmer block rounded-xl',
        'bg-[linear-gradient(90deg,var(--sunken)_25%,var(--line)_37%,var(--sunken)_63%)] bg-[length:200%_100%]',
        className,
      )}
    />
  );
}

/** Placeholders shaped like the real rows, not a grey blob. */
export function SkeletonRows({ count = 5 }) {
  return (
    <div aria-busy="true" aria-label="Loading">
      {Array.from({ length: count }, (_, i) => (
        <div key={i} className="flex items-center gap-3 px-4 py-[14px]">
          <Skeleton className="rounded-tile size-[42px]" />
          <div className="grid flex-1 gap-[7px]">
            <Skeleton className="h-[13px]" style={{ width: `${55 + ((i * 13) % 30)}%` }} />
            <Skeleton className="h-[11px] w-2/5" />
          </div>
          <Skeleton className="h-[13px] w-16" />
        </div>
      ))}
    </div>
  );
}
