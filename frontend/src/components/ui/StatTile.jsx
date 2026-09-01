import { cn } from '@/lib/cn';

const TONES = { in: 'text-in', out: 'text-out', pending: 'text-pending' };

export function StatTile({ icon: Icon, label, value, foot, tone, onClick }) {
  const Tag = onClick ? 'button' : 'div';
  return (
    <Tag
      type={onClick ? 'button' : undefined}
      onClick={onClick}
      className="bg-surface border-line rounded-card shadow-card flex flex-col gap-0.5 border px-4 py-3 text-left"
    >
      <span className="text-ink-subtle flex items-center gap-1.5 text-[11.5px] font-semibold">
        {Icon ? <Icon size={13} /> : null}
        {label}
      </span>
      <span className={cn('text-[19px] font-bold tracking-[-0.025em] tabular-nums', TONES[tone])}>
        {value}
      </span>
      {foot ? <span className="text-ink-subtle text-[11.5px]">{foot}</span> : null}
    </Tag>
  );
}
