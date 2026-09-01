import { useEffect } from 'react';
import { X } from 'lucide-react';
import { IconButton } from './Button';

/**
 * Bottom sheet, used for pickers and confirmations instead of a full screen so
 * the context behind it stays visible. Positioned absolutely because the phone
 * frame — not the window — is the containing block.
 */
export function Sheet({ open, title, onClose, children, footer }) {
  useEffect(() => {
    if (!open) return undefined;
    const onKey = (event) => event.key === 'Escape' && onClose();
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [open, onClose]);

  if (!open) return null;

  return (
    <>
      <div
        role="presentation"
        onClick={onClose}
        className="animate-fade-in absolute inset-0 z-60 bg-black/45 backdrop-blur-[2px]"
      />
      <div
        role="dialog"
        aria-modal="true"
        aria-label={title}
        className="bg-surface shadow-sheet animate-sheet-up pb-safe absolute inset-x-0 bottom-0 z-61 flex max-h-[86%] flex-col rounded-t-[28px]"
      >
        <span
          aria-hidden
          className="bg-line-strong mx-auto mt-2 mb-1 h-1 w-9 shrink-0 rounded-full"
        />
        <div className="flex shrink-0 items-center justify-between gap-3 px-4 pt-2 pb-3">
          <h2 className="text-[17px] font-semibold tracking-[-0.01em]">{title}</h2>
          <IconButton icon={X} label="Close" onClick={onClose} />
        </div>
        <div className="scroll-area px-4 pb-5">{children}</div>
        {footer}
      </div>
    </>
  );
}
