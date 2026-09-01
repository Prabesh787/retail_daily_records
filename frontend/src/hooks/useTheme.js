import { useCallback, useEffect, useState } from 'react';

const STORAGE_KEY = 'shop-records:theme';

function resolve(preference) {
  if (preference !== 'system') return preference;
  return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
}

/**
 * Three states, not two: light, dark, and "follow the phone". The resolved
 * value is stamped on <html> so the token file can override itself.
 */
export function useTheme() {
  const [preference, setPreference] = useState(() => localStorage.getItem(STORAGE_KEY) || 'system');

  useEffect(() => {
    const apply = () => {
      document.documentElement.dataset.theme = resolve(preference);
    };
    apply();
    localStorage.setItem(STORAGE_KEY, preference);

    if (preference !== 'system') return undefined;
    const list = window.matchMedia('(prefers-color-scheme: dark)');
    list.addEventListener('change', apply);
    return () => list.removeEventListener('change', apply);
  }, [preference]);

  const toggle = useCallback(() => {
    setPreference((current) => (resolve(current) === 'dark' ? 'light' : 'dark'));
  }, []);

  return { preference, setPreference, toggle, resolved: resolve(preference) };
}
