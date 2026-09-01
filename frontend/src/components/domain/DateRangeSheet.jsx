import { useEffect, useState } from 'react';
import { CalendarRange, Check } from 'lucide-react';
import { Button, Field, Input, Sheet } from '@/components/ui';
import { cn } from '@/lib/cn';
import { buildPresets } from './date-range';

/**
 * Date range picker. Presets cover the usual questions ("this month", "today");
 * the two date inputs underneath answer "the 12th" and any custom window a
 * statement needs.
 */
export function DateRangeSheet({ open, onClose, value, onApply, fiscalYear }) {
  const presets = buildPresets(fiscalYear);
  const [draft, setDraft] = useState(value);

  // Reopening should show what is actually applied, not last time's edits.
  useEffect(() => {
    if (open) setDraft(value);
  }, [open, value]);

  return (
    <Sheet open={open} title="Date range" onClose={onClose}>
      <div className="flex flex-col gap-4">
        <div className="grid grid-cols-2 gap-2">
          {presets.map((preset) => {
            const active = draft.from === preset.from && draft.to === preset.to;
            return (
              <button
                key={preset.id}
                type="button"
                onClick={() => setDraft({ from: preset.from, to: preset.to })}
                className={cn(
                  'rounded-tile flex h-11 items-center justify-between gap-2 border px-3 text-[13.5px] font-semibold transition-colors',
                  active
                    ? 'border-brand bg-brand-50 text-brand'
                    : 'border-line-strong text-ink-muted',
                )}
              >
                {preset.label}
                {active ? <Check size={15} /> : null}
              </button>
            );
          })}
        </div>

        <div className="grid grid-cols-2 gap-3">
          <Field label="From">
            {({ id }) => (
              <Input
                id={id}
                type="date"
                value={draft.from}
                onChange={(event) => setDraft((d) => ({ ...d, from: event.target.value }))}
              />
            )}
          </Field>
          <Field label="To">
            {({ id }) => (
              <Input
                id={id}
                type="date"
                value={draft.to}
                onChange={(event) => setDraft((d) => ({ ...d, to: event.target.value }))}
              />
            )}
          </Field>
        </div>

        <div className="flex gap-3">
          <Button
            variant="secondary"
            block
            onClick={() => {
              setDraft({ from: '', to: '' });
              onApply({ from: '', to: '' });
              onClose();
            }}
          >
            Clear
          </Button>
          <Button
            block
            icon={CalendarRange}
            onClick={() => {
              onApply(draft);
              onClose();
            }}
          >
            Apply
          </Button>
        </div>
      </div>
    </Sheet>
  );
}
