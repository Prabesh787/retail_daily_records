import { useId } from 'react';
import { cn } from '@/lib/cn';

/**
 * Wraps a control with its label, hint and error, and hands the child the ids
 * it needs so the association is real rather than visual.
 */
export function Field({ label, required, hint, error, children }) {
  const id = useId();
  const describedBy = error ? `${id}-error` : hint ? `${id}-hint` : undefined;

  return (
    <div className="flex flex-col gap-1.5">
      {label ? (
        <label htmlFor={id} className="text-ink-muted text-[13px] font-semibold">
          {label}
          {required ? (
            <span aria-hidden className="text-out">
              {' '}
              *
            </span>
          ) : null}
        </label>
      ) : null}

      {children({ id, describedBy, invalid: Boolean(error) })}

      {error ? (
        <span id={`${id}-error`} role="alert" className="text-out text-[12.5px] font-medium">
          {error}
        </span>
      ) : hint ? (
        <span id={`${id}-hint`} className="text-ink-subtle text-xs">
          {hint}
        </span>
      ) : null}
    </div>
  );
}

/* `text-base` is not decoration: below 16px, iOS Safari zooms the page on focus. */
const CONTROL =
  'bg-surface border-line-strong rounded-tile w-full border px-3 text-base outline-none ' +
  'transition-[border-color,box-shadow] duration-150 ease-out-quart ' +
  'focus:border-brand-500 focus:ring-4 focus:ring-brand-100';

const INVALID = 'border-out focus:border-out focus:ring-out-soft';

export function Input({ invalid, className, ...rest }) {
  return (
    <input
      aria-invalid={invalid || undefined}
      className={cn(CONTROL, 'h-12', invalid && INVALID, className)}
      {...rest}
    />
  );
}

/**
 * Money stays a string the whole way to the API — decimals are never floats —
 * and `inputMode="decimal"` brings up the numeric keypad instead of a keyboard.
 */
export function MoneyInput({ invalid, className, ...rest }) {
  return (
    <div className="relative">
      <span className="text-ink-subtle pointer-events-none absolute top-1/2 left-3 -translate-y-1/2 text-[15px] font-semibold">
        Rs
      </span>
      <input
        type="text"
        inputMode="decimal"
        autoComplete="off"
        aria-invalid={invalid || undefined}
        className={cn(CONTROL, 'h-12 pl-10', invalid && INVALID, className)}
        {...rest}
      />
    </div>
  );
}

export function Select({ invalid, className, children, ...rest }) {
  return (
    <select
      aria-invalid={invalid || undefined}
      className={cn(CONTROL, 'h-12', invalid && INVALID, className)}
      {...rest}
    >
      {children}
    </select>
  );
}

export function TextArea({ invalid, className, ...rest }) {
  return (
    <textarea
      aria-invalid={invalid || undefined}
      className={cn(
        CONTROL,
        'min-h-21 resize-y py-3 leading-relaxed',
        invalid && INVALID,
        className,
      )}
      {...rest}
    />
  );
}
