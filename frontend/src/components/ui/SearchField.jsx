import { Search, X } from 'lucide-react';
import { cn } from '@/lib/cn';

export function SearchField({ value, onChange, placeholder = 'Search', className }) {
  return (
    <div
      className={cn(
        'bg-sunken text-ink-subtle rounded-tile flex h-[42px] items-center gap-2 px-3',
        'focus-within:ring-brand-500 transition-shadow focus-within:ring-2',
        className,
      )}
    >
      <Search size={17} aria-hidden />
      <input
        type="search"
        inputMode="search"
        value={value}
        placeholder={placeholder}
        aria-label={placeholder}
        onChange={(event) => onChange(event.target.value)}
        className="text-ink placeholder:text-ink-subtle min-w-0 flex-1 bg-transparent text-[15px] outline-none"
      />
      {value ? (
        <button type="button" aria-label="Clear search" onClick={() => onChange('')}>
          <X size={16} />
        </button>
      ) : null}
    </div>
  );
}
