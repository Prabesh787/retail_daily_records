import { cn } from '@/lib/cn';

const BASE =
  'inline-flex items-center justify-center gap-2 whitespace-nowrap font-semibold ' +
  'tracking-[-0.01em] transition-[transform,background-color,opacity] duration-150 ' +
  'ease-out-quart active:scale-[0.97] disabled:pointer-events-none disabled:opacity-50';

const VARIANTS = {
  primary: 'bg-brand text-white shadow-card',
  secondary: 'bg-surface border-line-strong border',
  ghost: 'text-brand px-3',
  danger: 'bg-out text-white',
  soft: 'bg-brand-50 text-brand',
};

const SIZES = {
  sm: 'h-9 rounded-xl px-3 text-[13.5px]',
  md: 'h-[46px] rounded-tile px-5 text-[15px]',
  lg: 'rounded-card h-[52px] px-5 text-base',
};

export function Button({
  variant = 'primary',
  size = 'md',
  block = false,
  loading = false,
  icon: Icon,
  children,
  className,
  disabled,
  ...rest
}) {
  return (
    <button
      type="button"
      disabled={disabled || loading}
      className={cn(BASE, VARIANTS[variant], SIZES[size], block && 'w-full', className)}
      {...rest}
    >
      {loading ? <Spinner /> : Icon ? <Icon size={18} /> : null}
      {children}
    </button>
  );
}

export function IconButton({ icon: Icon, label, size = 20, className, ...rest }) {
  return (
    <button
      type="button"
      aria-label={label}
      title={label}
      className={cn(
        'inline-flex size-[38px] shrink-0 items-center justify-center rounded-full',
        'ease-out-quart transition-[transform,background-color] duration-150',
        'active:bg-sunken active:scale-90',
        className,
      )}
      {...rest}
    >
      <Icon size={size} />
    </button>
  );
}

export function Spinner({ className }) {
  return (
    <span
      aria-hidden
      className={cn(
        'size-[18px] animate-spin rounded-full border-2 border-current border-r-transparent',
        className,
      )}
    />
  );
}
