import { cn } from '@/lib/cn';

const TONES = {
  success: 'bg-in-soft text-in',
  warning: 'bg-pending-soft text-pending',
  danger: 'bg-out-soft text-out',
  info: 'bg-info-soft text-info',
  neutral: 'bg-muted-soft text-ink-muted',
};

export function Badge({ tone = 'neutral', dot = true, children, className }) {
  return (
    <span
      className={cn(
        'inline-flex items-center gap-1.5 rounded-full px-2.5 py-[3px]',
        'text-[11.5px] font-semibold whitespace-nowrap',
        TONES[tone],
        className,
      )}
    >
      {dot ? <span aria-hidden className="size-[5px] rounded-full bg-current" /> : null}
      {children}
    </span>
  );
}
