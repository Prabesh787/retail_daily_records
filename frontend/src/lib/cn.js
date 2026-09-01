import { clsx } from 'clsx';
import { twMerge } from 'tailwind-merge';

/**
 * Joins class names and lets a caller's utility win over a component's default
 * — `twMerge` drops the earlier conflicting class instead of leaving both in
 * the attribute for the cascade to settle arbitrarily.
 */
export function cn(...inputs) {
  return twMerge(clsx(inputs));
}
