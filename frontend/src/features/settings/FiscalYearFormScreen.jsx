import { useState } from 'react';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useNavigate } from 'react-router-dom';
import { CalendarRange } from 'lucide-react';
import { Screen } from '@/components/layout/Screen';
import { Button, Card, Field, Input, SegmentedControl, useToast } from '@/components/ui';
import { api, ApiError } from '@/lib/api';

const EMPTY = {
  name: '',
  startDate: '',
  startDateBs: '',
  endDate: '',
  endDateBs: '',
};

const ACTIVE_OPTIONS = [
  { value: 'yes', label: 'Make it active' },
  { value: 'no', label: 'Keep it inactive' },
];

/** BS dates are typed, not converted, so they are only checked for shape. */
const BS_PATTERN = /^\d{4}-\d{2}-\d{2}$/;

/**
 * Creating a fiscal year.
 *
 * Every purchase, payment and sale points at one of these, which is what makes
 * per-year reporting and per-year document numbering possible — bill numbers
 * are unique per supplier *per year*, invoice numbers per year. So a year that
 * has run out is not a cosmetic problem: new records keep filing themselves
 * under it.
 *
 * Exactly one year is active at a time. Marking this one active stands the
 * previous one down, in a single transaction on the server.
 */
export function FiscalYearFormScreen() {
  const navigate = useNavigate();
  const toast = useToast();
  const queryClient = useQueryClient();

  const [values, setValues] = useState(EMPTY);
  const [active, setActive] = useState('yes');
  const [errors, setErrors] = useState({});

  const set = (key) => (event) => {
    const value = event.target.value;
    setValues((current) => ({ ...current, [key]: value }));
    setErrors((current) => ({ ...current, [key]: undefined }));
  };

  const mutation = useMutation({
    mutationFn: (body) => api.fiscalYears.create(body),
    onSuccess: (year) => {
      // Activating one changes which year new records file under, so anything
      // that reads the active year is stale the moment this succeeds.
      queryClient.invalidateQueries({ queryKey: ['fiscal-years'] });
      queryClient.invalidateQueries({ queryKey: ['dashboard'] });
      toast.success(year.isActive ? `${year.name} is now the active year` : `${year.name} added`);
      navigate('/more', { replace: true });
    },
    onError: (error) => {
      if (error instanceof ApiError && error.errors.length) setErrors(error.fieldErrors);
      toast.error(error.message);
    },
  });

  const submit = () => {
    const found = {};
    if (!values.name.trim()) found.name = 'Give the year a name, e.g. 2083/84';
    if (!values.startDate) found.startDate = 'Start date is required';
    if (!values.endDate) found.endDate = 'End date is required';
    if (values.startDate && values.endDate && values.endDate <= values.startDate)
      found.endDate = 'End date must be after the start date';
    if (values.startDateBs && !BS_PATTERN.test(values.startDateBs))
      found.startDateBs = 'Use YYYY-MM-DD, e.g. 2083-04-01';
    if (values.endDateBs && !BS_PATTERN.test(values.endDateBs))
      found.endDateBs = 'Use YYYY-MM-DD, e.g. 2084-03-31';

    setErrors(found);
    if (Object.keys(found).length > 0) return;

    mutation.mutate({
      name: values.name.trim(),
      startDate: values.startDate,
      endDate: values.endDate,
      startDateBs: values.startDateBs || null,
      endDateBs: values.endDateBs || null,
      isActive: active === 'yes',
    });
  };

  return (
    <Screen
      title="New fiscal year"
      back
      actions={
        <Button size="sm" variant="ghost" onClick={() => navigate(-1)}>
          Cancel
        </Button>
      }
    >
      <div className="flex flex-col gap-4">
        <Card>
          <Field
            label="Year"
            required
            error={errors.name}
            hint="How the shop refers to it, e.g. 2083/84"
          >
            {({ id, invalid }) => (
              <Input
                id={id}
                invalid={invalid}
                value={values.name}
                onChange={set('name')}
                placeholder="2083/84"
                inputMode="numeric"
                autoFocus
              />
            )}
          </Field>
        </Card>

        <Card>
          <div className="flex flex-col gap-4">
            {/* Both calendars again: AD is what the database ranges on, BS is
                what the year is actually called. */}
            <Field label="Starts (AD)" required error={errors.startDate}>
              {({ id, invalid }) => (
                <Input
                  id={id}
                  invalid={invalid}
                  type="date"
                  value={values.startDate}
                  onChange={set('startDate')}
                />
              )}
            </Field>

            <Field label="Starts (BS)" error={errors.startDateBs} hint="Usually 1 Shrawan">
              {({ id, invalid }) => (
                <Input
                  id={id}
                  invalid={invalid}
                  value={values.startDateBs}
                  onChange={set('startDateBs')}
                  placeholder="2083-04-01"
                  inputMode="numeric"
                />
              )}
            </Field>
          </div>
        </Card>

        <Card>
          <div className="flex flex-col gap-4">
            <Field label="Ends (AD)" required error={errors.endDate}>
              {({ id, invalid }) => (
                <Input
                  id={id}
                  invalid={invalid}
                  type="date"
                  value={values.endDate}
                  onChange={set('endDate')}
                />
              )}
            </Field>

            <Field label="Ends (BS)" error={errors.endDateBs} hint="Usually the last day of Ashadh">
              {({ id, invalid }) => (
                <Input
                  id={id}
                  invalid={invalid}
                  value={values.endDateBs}
                  onChange={set('endDateBs')}
                  placeholder="2084-03-31"
                  inputMode="numeric"
                />
              )}
            </Field>
          </div>
        </Card>

        <Card>
          <div className="flex flex-col gap-3">
            <span className="text-ink-muted flex items-center gap-2 text-[13px] font-semibold">
              <CalendarRange size={14} /> Active year
            </span>
            <SegmentedControl options={ACTIVE_OPTIONS} value={active} onChange={setActive} />
            <p className="bg-sunken text-ink-muted rounded-tile px-3 py-2.5 text-[12.5px] leading-relaxed">
              {active === 'yes' ? (
                <>
                  New bills, payments and sales will file under{' '}
                  <strong className="text-ink">{values.name.trim() || 'this year'}</strong>.
                  Whichever year is active now will be stood down.
                </>
              ) : (
                <>
                  This year will exist but nothing will file under it. The year that is active now
                  stays active.
                </>
              )}
            </p>
          </div>
        </Card>

        <Button size="lg" block loading={mutation.isPending} onClick={submit}>
          Save fiscal year
        </Button>
      </div>
    </Screen>
  );
}
