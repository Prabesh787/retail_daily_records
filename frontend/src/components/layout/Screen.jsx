import { useRef, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { ChevronLeft } from 'lucide-react';
import { IconButton } from '@/components/ui';
import { cn } from '@/lib/cn';

/**
 * Every route renders one <Screen>. It owns the scroll container so the header
 * can stay pinned and pick up its hairline only once content passes under it —
 * the small detail that makes a web app feel native.
 */
export function Screen({
  title,
  eyebrow,
  back = false,
  actions,
  children,
  flush = false,
  centerTitle = false,
  reserveBottom = 0,
  headerExtra,
}) {
  const navigate = useNavigate();
  const [scrolled, setScrolled] = useState(false);
  const ticking = useRef(false);

  // rAF-throttled: otherwise this runs on every scroll frame.
  const onScroll = (event) => {
    if (ticking.current) return;
    ticking.current = true;
    const { scrollTop } = event.currentTarget;
    requestAnimationFrame(() => {
      setScrolled(scrollTop > 4);
      ticking.current = false;
    });
  };

  return (
    <>
      <header
        className={cn(
          'relative z-20 flex shrink-0 items-center gap-2 px-3 py-2',
          'pt-safe min-h-[var(--header-h)] border-b border-transparent',
          'bg-surface/80 backdrop-blur-xl backdrop-saturate-150',
          'ease-out-quart transition-colors duration-200',
          scrolled && 'border-line',
        )}
      >
        {back ? <IconButton icon={ChevronLeft} label="Back" onClick={() => navigate(-1)} /> : null}
        <div className={cn('min-w-0 flex-1 truncate', centerTitle && 'text-center')}>
          {eyebrow ? (
            <span className="text-ink-subtle block text-[11px] font-semibold">{eyebrow}</span>
          ) : null}
          <div className="truncate text-[16.5px] font-bold tracking-[-0.02em]">{title}</div>
        </div>
        {actions}
      </header>

      {headerExtra}

      <main onScroll={onScroll} className="scroll-area min-h-0 flex-1">
        <div
          style={{ paddingBottom: `calc(2rem + ${reserveBottom}px)` }}
          className={cn('animate-rise-in p-4', flush && 'px-0')}
        >
          {children}
        </div>
      </main>
    </>
  );
}
