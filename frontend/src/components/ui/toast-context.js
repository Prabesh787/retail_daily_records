import { createContext, useContext } from 'react';

/** Kept out of Toast.jsx so that file exports components only (fast refresh). */
export const ToastContext = createContext(null);

export function useToast() {
  const context = useContext(ToastContext);
  if (!context) throw new Error('useToast must be used inside <ToastProvider>');
  return context;
}
