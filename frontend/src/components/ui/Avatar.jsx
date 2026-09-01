import { colorFromString, initials } from '@/lib/format';
import { cn } from '@/lib/cn';

/**
 * Initials on a hue derived from the name, so a supplier keeps one colour
 * everywhere it appears. The hue is a CSS variable because Tailwind cannot
 * generate a class per name.
 */
export function Avatar({ name = '', size = 'md', className }) {
  return (
    <span
      aria-hidden
      style={{ '--hue': colorFromString(name) }}
      className={cn(
        'grid shrink-0 place-items-center font-bold',
        'bg-[hsl(var(--hue)_70%_94%)] text-[hsl(var(--hue)_62%_34%)]',
        'dark:bg-[hsl(var(--hue)_40%_20%)] dark:text-[hsl(var(--hue)_70%_76%)]',
        size === 'sm' ? 'size-8 rounded-xl text-xs' : 'rounded-tile size-[42px] text-sm',
        className,
      )}
    >
      {initials(name)}
    </span>
  );
}
