import { Card, Divider } from '@/components/ui';
import { cn } from '@/lib/cn';

/**
 * The label/value card every detail screen is built from. Rows with no value
 * are dropped rather than rendered empty, so an optional field costs nothing
 * when it is not filled in.
 */
export function DetailList({ rows }) {
  const visible = rows.filter(
    (row) => row && row.value !== null && row.value !== undefined && row.value !== '',
  );

  return (
    <Card padded={false}>
      {visible.map((row, index) => (
        <div key={row.label}>
          {index > 0 ? <Divider /> : null}
          <div className="flex items-start justify-between gap-4 px-4 py-[11px]">
            <span className="text-ink-muted shrink-0 text-[13px]">{row.label}</span>
            <span
              className={cn(
                'text-right text-sm font-medium break-words',
                row.mono && 'tabular-nums',
              )}
            >
              {row.value}
            </span>
          </div>
        </div>
      ))}
    </Card>
  );
}
