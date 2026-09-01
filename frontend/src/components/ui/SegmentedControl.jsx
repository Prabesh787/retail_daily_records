import { cn } from '@/lib/cn';

/** iOS-style filter switch. Options are `{ value, label }`. */
export function SegmentedControl({ options, value, onChange, className }) {
  return (
    <div role="tablist" className={cn('bg-sunken flex gap-0.5 rounded-full p-[3px]', className)}>
      {options.map((option) => {
        const active = option.value === value;
        return (
          <button
            key={String(option.value)}
            type="button"
            role="tab"
            aria-selected={active}
            onClick={() => onChange(option.value)}
            className={cn(
              'h-8 flex-1 rounded-full text-[13px] font-semibold',
              'ease-out-quart transition-[background-color,color,box-shadow] duration-200',
              active ? 'bg-surface text-ink shadow-card' : 'text-ink-muted',
            )}
          >
            {option.label}
          </button>
        );
      })}
    </div>
  );
}
