import { useState } from 'react';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useNavigate } from 'react-router-dom';
import { Screen } from '@/components/layout/Screen';
import { Button, Card, Field, Input, MoneyInput, TextArea, useToast } from '@/components/ui';
import { api, ApiError } from '@/lib/api';

const EMPTY = {
  name: '',
  contactPerson: '',
  phone: '',
  email: '',
  address: '',
  pan: '',
  openingBalance: '',
  remarks: '',
};

/**
 * Adding a supplier the shop already deals with. The opening balance is the
 * important field: it is what was owed on the day this system went live, and
 * it seeds the derived outstanding figure. Leaving it at zero says the shop
 * started square with this supplier — it is never a running total, and it is
 * not editable from the balance later.
 */
export function SupplierFormScreen() {
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
    mutationFn: (body) => api.suppliers.create(body),
    onSuccess: (supplier) => {
      queryClient.invalidateQueries({ queryKey: ['suppliers'] });
      queryClient.invalidateQueries({ queryKey: ['dashboard'] });
      toast.success('Supplier added');
      navigate(`/suppliers/${supplier.id}`, { replace: true });
    },
    onError: (error) => {
      if (error instanceof ApiError && error.errors.length) setErrors(error.fieldErrors);
      toast.error(error.message);
    },
  });

  const submit = () => {
    const found = {};
    if (!values.name.trim()) found.name = 'Supplier name is required';
    if (values.openingBalance && Number(values.openingBalance) < 0)
      found.openingBalance = 'An opening balance cannot be negative';
    if (values.email && !/^\S+@\S+\.\S+$/.test(values.email))
      found.email = 'Enter a valid email address';

    setErrors(found);
    if (Object.keys(found).length > 0) return;

    // Empty string is not a value: an unfilled optional field is null.
    const clean = (value) => (value.trim() === '' ? null : value.trim());

    mutation.mutate({
      name: values.name.trim(),
      contactPerson: clean(values.contactPerson),
      phone: clean(values.phone),
      email: clean(values.email),
      address: clean(values.address),
      pan: clean(values.pan),
      openingBalance: Number(values.openingBalance || 0).toFixed(2),
      remarks: clean(values.remarks),
    });
  };

  return (
    <Screen
      title="New supplier"
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
            <Field label="Supplier name" required error={errors.name}>
              {({ id, invalid }) => (
                <Input
                  id={id}
                  invalid={invalid}
                  value={values.name}
                  onChange={set('name')}
                  placeholder="ABC Textile Udhyog"
                  autoFocus
                />
              )}
            </Field>

            <Field label="Contact person">
              {({ id }) => (
                <Input
                  id={id}
                  value={values.contactPerson}
                  onChange={set('contactPerson')}
                  placeholder="Ramesh Agrawal"
                />
              )}
            </Field>

            <Field label="Phone">
              {({ id }) => (
                <Input
                  id={id}
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
            <Field
              label="Opening balance"
              error={errors.openingBalance}
              hint="What the shop already owed this supplier before recording started. Leave empty if nothing."
            >
              {({ id, invalid }) => (
                <MoneyInput
                  id={id}
                  invalid={invalid}
                  value={values.openingBalance}
                  onChange={set('openingBalance')}
                  placeholder="0.00"
                />
              )}
            </Field>

            {/* Spelling out the arithmetic here is the cheapest way to stop
                someone treating this field as a current balance. */}
            <p className="bg-sunken text-ink-muted rounded-tile px-3 py-2.5 text-[12.5px] leading-relaxed">
              Outstanding is always calculated as{' '}
              <strong className="text-ink">opening balance + bills − payments</strong>. This figure
              is only the starting point.
            </p>
          </div>
        </Card>

        <Card>
          <div className="flex flex-col gap-4">
            <Field label="Address">
              {({ id }) => (
                <Input
                  id={id}
                  value={values.address}
                  onChange={set('address')}
                  placeholder="Birgunj, Parsa"
                />
              )}
            </Field>

            <Field label="PAN">
              {({ id }) => (
                <Input
                  id={id}
                  value={values.pan}
                  onChange={set('pan')}
                  inputMode="numeric"
                  placeholder="600000000"
                />
              )}
            </Field>

            <Field label="Email" error={errors.email}>
              {({ id, invalid }) => (
                <Input
                  id={id}
                  invalid={invalid}
                  type="email"
                  inputMode="email"
                  value={values.email}
                  onChange={set('email')}
                  placeholder="sales@abctextile.com"
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
          Save supplier
        </Button>
      </div>
    </Screen>
  );
}
