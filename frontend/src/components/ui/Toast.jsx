import { useCallback, useMemo, useState } from 'react';
import { AlertCircle, CheckCircle2, Info } from 'lucide-react';
import { cn } from '@/lib/cn';
import { ToastContext } from './toast-context';

const ICONS = { success: CheckCircle2, error: AlertCircle, info: Info };
const TONES = { success: 'bg-emerald-800', error: 'bg-out', info: 'bg-[#12182a]' };

export function ToastProvider({ children }) {
  const [toasts, setToasts] = useState([]);

  const dismiss = useCallback((id) => {
    setToasts((current) => current.filter((toast) => toast.id !== id));
  }, []);

  const show = useCallback(
    (message, tone = 'info') => {
      const id = Date.now() + Math.random();
      setToasts((current) => [...current, { id, message, tone }]);
      setTimeout(() => dismiss(id), 2800);
    },
    [dismiss],
  );

  const value = useMemo(
    () => ({
      show,
      success: (message) => show(message, 'success'),
      error: (message) => show(message, 'error'),
    }),
    [show],
  );

  return (
    <ToastContext.Provider value={value}>
      {children}
      <div
        role="status"
        aria-live="polite"
        className="bottom-above-nav pointer-events-none absolute inset-x-4 z-80 flex flex-col gap-2"
      >
        {toasts.map((toast) => {
          const Icon = ICONS[toast.tone];
          return (
            <div
              key={toast.id}
              className={cn(
                'animate-rise-in shadow-sheet rounded-tile flex items-center gap-2 px-4 py-3',
                'text-[13.5px] font-medium text-white',
                TONES[toast.tone],
              )}
            >
              <Icon size={16} />
              {toast.message}
            </div>
          );
        })}
      </div>
    </ToastContext.Provider>
  );
}
