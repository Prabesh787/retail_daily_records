import { useState } from 'react';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useNavigate } from 'react-router-dom';
import { Screen } from '@/components/layout/Screen';
import { Button, Card, Field, Input, TextArea, useToast } from '@/components/ui';
import { api, ApiError } from '@/lib/api';

const EMPTY = { name: '', phone: '', address: '', pan: '', remarks: '' };

/**
 * Adding a customer. Only the name is required, because the reason a customer
 * exists in this system at all is that someone asked for an invoice with a name
 * on it — everything else is whatever the shop happened to be told.
 *
 * Most sales never reach this screen: a walk-in sale carries no customer, and
 * that is the normal case rather than missing data.
 */
export function CustomerFormScreen() {
  const navigate = useNavigate();
  const toast = useToast();
  const queryClient = useQueryClient();

  const [values, setValues] = useState(EMPTY);
  const [errors, setErrors] = useState({});

  const set = (key) => (event) => {
    const value = event.target.value;
    setValues((current) => ({ ...current, [key]: value }));
    setErrors((current) => ({ ...current, [key]: undefined }));
  };

  const mutation = useMutation({
    mutationFn: (body) => api.customers.create(body),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['customers'] });
      toast.success('Customer added');
      navigate('/customers', { replace: true });
    },
    onError: (error) => {
      if (error instanceof ApiError && error.errors.length) setErrors(error.fieldErrors);
      toast.error(error.message);
    },
  });

  const submit = () => {
    const found = {};
    if (!values.name.trim()) found.name = 'Customer name is required';

    setErrors(found);
    if (Object.keys(found).length > 0) return;

    // Empty string is not a value: an unfilled optional field is null.
    const clean = (value) => (value.trim() === '' ? null : value.trim());

    mutation.mutate({
      name: values.name.trim(),
      phone: clean(values.phone),
      address: clean(values.address),
      pan: clean(values.pan),
      remarks: clean(values.remarks),
    });
  };

  return (
    <Screen
      title="New customer"
      back
      actions={
        <Button size="sm" variant="ghost" onClick={() => navigate(-1)}>
          Cancel
        </Button>
      }
    >
      <div className="flex flex-col gap-4">
        <Card>
          <div className="flex flex-col gap-4">
            <Field label="Customer name" required error={errors.name}>
              {({ id, invalid }) => (
                <Input
                  id={id}
                  invalid={invalid}
                  value={values.name}
                  onChange={set('name')}
                  placeholder="Sita Sharma"
                  autoFocus
                />
              )}
            </Field>

            <Field label="Phone" error={errors.phone}>
              {({ id, invalid }) => (
                <Input
                  id={id}
                  invalid={invalid}
                  type="tel"
                  inputMode="tel"
                  value={values.phone}
                  onChange={set('phone')}
                  placeholder="9801234567"
                />
              )}
            </Field>
          </div>
        </Card>

        <Card>
          <div className="flex flex-col gap-4">
            <Field label="Address" error={errors.address}>
              {({ id, invalid }) => (
                <Input
                  id={id}
                  invalid={invalid}
                  value={values.address}
                  onChange={set('address')}
                  placeholder="Butwal-11, Rupandehi"
                />
              )}
            </Field>

            <Field label="PAN" hint="Only needed if this customer asks for a PAN bill">
              {({ id }) => (
                <Input
                  id={id}
                  value={values.pan}
                  onChange={set('pan')}
                  inputMode="numeric"
                  placeholder="300000000"
                />
              )}
            </Field>

            <Field label="Remarks">
              {({ id }) => (
                <TextArea id={id} value={values.remarks} onChange={set('remarks')} rows={3} />
              )}
            </Field>
          </div>
        </Card>

        <Button size="lg" block loading={mutation.isPending} onClick={submit}>
          Save customer
        </Button>
      </div>
    </Screen>
  );
}
