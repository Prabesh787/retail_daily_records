import { cn } from '@/lib/cn';

/**
 * `as` lets the same surface be a div, a link or a button without duplicating
 * the styling — a card that navigates should be a real anchor.
 */
export function Card({
  as: Tag = 'div',
  padded = true,
  interactive = false,
  className,
  children,
  ...rest
}) {
  return (
    <Tag
      className={cn(
        'bg-surface border-line rounded-card shadow-card overflow-hidden border',
        padded && 'p-4',
        interactive &&
          'ease-out-quart active:shadow-lift cursor-pointer transition-[transform,box-shadow] duration-150 active:scale-[0.985]',
        className,
      )}
      {...rest}
    >
      {children}
    </Tag>
  );
}
