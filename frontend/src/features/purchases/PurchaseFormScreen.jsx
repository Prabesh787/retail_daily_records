import { useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useNavigate } from 'react-router-dom';
import { Screen } from '@/components/layout/Screen';
import {
  Button,
  Card,
  Field,
  Input,
  MoneyInput,
  Select,
  TextArea,
  useToast,
} from '@/components/ui';
import { api, ApiError } from '@/lib/api';
import { queryKeys } from '@/lib/api/query-keys';
import { todayIso } from '@/lib/format';

const EMPTY = {
  supplierId: '',
  billNo: '',
  billDate: todayIso(),
  billDateBs: '',
  amount: '',
  description: '',
  remarks: '',
};

/**
 * A purchase is one whole bill: supplier, number, date, amount. No line items,
 * because the shop does not track stock — that is a deliberate limit of the
 * system, not a missing feature.
 */
export function PurchaseFormScreen() {
  const navigate = useNavigate();
  const toast = useToast();
  const queryClient = useQueryClient();

  const [values, setValues] = useState(EMPTY);
  const [errors, setErrors] = useState({});

  const { data: suppliers } = useQuery({
    queryKey: queryKeys.suppliers({ limit: 100 }),
    queryFn: () => api.suppliers.list({ limit: 100 }),
  });

  const set = (key) => (event) => {
    const value = event.target.value;
    setValues((current) => ({ ...current, [key]: value }));
    setErrors((current) => ({ ...current, [key]: undefined }));
  };

  const mutation = useMutation({
    mutationFn: (body) => api.purchases.create(body),
    onSuccess: (purchase) => {
      // Bills move the supplier balance, so the supplier lists and the
      // dashboard are stale the moment this succeeds.
      queryClient.invalidateQueries({ queryKey: ['purchases'] });
      queryClient.invalidateQueries({ queryKey: ['suppliers'] });
      queryClient.invalidateQueries({ queryKey: ['dashboard'] });
      toast.success('Bill recorded');
      navigate(`/purchases/${purchase.id}`, { replace: true });
    },
    onError: (error) => {
      if (error instanceof ApiError && error.errors.length) setErrors(error.fieldErrors);
      toast.error(error.message);
    },
  });

  /** Client-side checks mirror the Zod schema; the server still has the final say. */
  const submit = () => {
    const found = {};
    if (!values.supplierId) found.supplierId = 'Choose the supplier';
    if (!values.billNo.trim()) found.billNo = 'Bill number is required';
    if (!values.billDate) found.billDate = 'Bill date is required';
    if (!Number(values.amount) || Number(values.amount) <= 0)
      found.amount = 'Amount must be greater than 0';

    setErrors(found);
    if (Object.keys(found).length > 0) return;

    mutation.mutate({
      ...values,
      amount: Number(values.amount).toFixed(2),
      billDateBs: values.billDateBs || null,
      description: values.description || null,
      remarks: values.remarks || null,
    });
  };

  return (
    <Screen
      title="New purchase"
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
            <Field label="Supplier" required error={errors.supplierId}>
              {({ id, invalid }) => (
                <Select
                  id={id}
                  invalid={invalid}
                  value={values.supplierId}
                  onChange={set('supplierId')}
                >
                  <option value="">Select a supplier</option>
                  {(suppliers?.data ?? []).map((supplier) => (
                    <option key={supplier.id} value={supplier.id}>
                      {supplier.name}
                    </option>
                  ))}
                </Select>
              )}
            </Field>

            <Field label="Bill amount" required error={errors.amount}>
              {({ id, invalid }) => (
                <MoneyInput
                  id={id}
                  invalid={invalid}
                  value={values.amount}
                  onChange={set('amount')}
                  placeholder="0.00"
                />
              )}
            </Field>

            <Field label="Bill number" required error={errors.billNo}>
              {({ id, invalid }) => (
                <Input
                  id={id}
                  invalid={invalid}
                  value={values.billNo}
                  onChange={set('billNo')}
                  placeholder="4521"
                  inputMode="numeric"
                />
              )}
            </Field>
          </div>
        </Card>

        <Card>
          <div className="flex flex-col gap-4">
            {/* Both calendars are captured: AD is what the database sorts on,
                BS is what the paperwork says. */}
            <Field label="Bill date (AD)" required error={errors.billDate}>
              {({ id, invalid }) => (
                <Input
                  id={id}
                  invalid={invalid}
                  type="date"
                  value={values.billDate}
                  onChange={set('billDate')}
                />
              )}
            </Field>

            <Field
              label="Bill date (BS)"
              hint="As written on the bill, e.g. 2083-05-10"
              error={errors.billDateBs}
            >
              {({ id, invalid }) => (
                <Input
                  id={id}
                  invalid={invalid}
                  value={values.billDateBs}
                  onChange={set('billDateBs')}
                  placeholder="2083-05-10"
                  inputMode="numeric"
                />
              )}
            </Field>
          </div>
        </Card>

        <Card>
          <div className="flex flex-col gap-4">
            <Field label="What was bought" hint="Free text — there are no stock records">
              {({ id }) => (
                <Input
                  id={id}
                  value={values.description}
                  onChange={set('description')}
                  placeholder="Cotton shirting, assorted colours"
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
          Save bill
        </Button>
      </div>
    </Screen>
  );
}
