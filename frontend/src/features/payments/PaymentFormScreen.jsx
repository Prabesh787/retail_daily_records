import { useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useNavigate, useSearchParams } from 'react-router-dom';
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
import { SUPPLIER_PAYMENT_MODE } from '@/lib/constants';
import { formatMoney, todayIso } from '@/lib/format';

/**
 * Recording a payment to a supplier. The cheque fields appear only for a cheque
 * — the same cross-field rule the API enforces, applied here so the form cannot
 * produce a request the server will reject.
 */
export function PaymentFormScreen() {
  const navigate = useNavigate();
  const toast = useToast();
  const queryClient = useQueryClient();
  const [searchParams] = useSearchParams();

  const [values, setValues] = useState({
    supplierId: searchParams.get('supplierId') ?? '',
    purchaseId: searchParams.get('purchaseId') ?? '',
    amount: '',
    paymentDate: todayIso(),
    paymentDateBs: '',
    paymentMode: 'CASH',
    chequeNo: '',
    chequeDate: '',
    referenceNo: '',
    description: '',
  });
  const [errors, setErrors] = useState({});

  const { data: suppliers } = useQuery({
    queryKey: queryKeys.suppliers({ limit: 100 }),
    queryFn: () => api.suppliers.list({ limit: 100 }),
  });

  const { data: supplier } = useQuery({
    queryKey: queryKeys.supplier(values.supplierId),
    queryFn: () => api.suppliers.get(values.supplierId),
    enabled: Boolean(values.supplierId),
  });

  const set = (key) => (event) => {
    const value = event.target.value;
    setValues((current) => ({ ...current, [key]: value }));
    setErrors((current) => ({ ...current, [key]: undefined }));
  };

  const isCheque = values.paymentMode === 'CHEQUE';
  const isTransfer = values.paymentMode === 'BANK_TRANSFER';

  const mutation = useMutation({
    mutationFn: (body) => api.supplierPayments.create(body),
    onSuccess: (payment) => {
      queryClient.invalidateQueries({ queryKey: ['supplier-payments'] });
      queryClient.invalidateQueries({ queryKey: ['cheque-register'] });
      queryClient.invalidateQueries({ queryKey: ['suppliers'] });
      queryClient.invalidateQueries({ queryKey: ['supplier'] });
      queryClient.invalidateQueries({ queryKey: ['purchase'] });
      queryClient.invalidateQueries({ queryKey: ['dashboard'] });
      toast.success(isCheque ? 'Cheque recorded as issued' : 'Payment recorded');
      navigate(`/payments/${payment.id}`, { replace: true });
    },
    onError: (error) => {
      if (error instanceof ApiError && error.errors.length) setErrors(error.fieldErrors);
      toast.error(error.message);
    },
  });

  const submit = () => {
    const found = {};
    if (!values.supplierId) found.supplierId = 'Choose the supplier';
    if (!Number(values.amount) || Number(values.amount) <= 0)
      found.amount = 'Amount must be greater than 0';
    if (!values.paymentDate) found.paymentDate = 'Payment date is required';
    if (isCheque && !values.chequeNo.trim()) found.chequeNo = 'Cheque number is required';
    if (isCheque && !values.chequeDate) found.chequeDate = 'Cheque date is required';

    setErrors(found);
    if (Object.keys(found).length > 0) return;

    mutation.mutate({
      supplierId: values.supplierId,
      purchaseId: values.purchaseId || null,
      amount: Number(values.amount).toFixed(2),
      paymentDate: values.paymentDate,
      paymentDateBs: values.paymentDateBs || null,
      paymentMode: values.paymentMode,
      chequeNo: isCheque ? values.chequeNo : null,
      chequeDate: isCheque ? values.chequeDate : null,
      referenceNo: isTransfer ? values.referenceNo || null : null,
      description: values.description || null,
    });
  };

  return (
    <Screen
      title="Record payment"
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
            <Field
              label="Supplier"
              required
              error={errors.supplierId}
              hint={
                supplier
                  ? `Currently owed ${formatMoney(supplier.balance.outstanding, { decimals: false })}`
                  : undefined
              }
            >
              {({ id, invalid }) => (
                <Select
                  id={id}
                  invalid={invalid}
                  value={values.supplierId}
                  onChange={set('supplierId')}
                >
                  <option value="">Select a supplier</option>
                  {(suppliers?.data ?? []).map((row) => (
                    <option key={row.id} value={row.id}>
                      {row.name}
                    </option>
                  ))}
                </Select>
              )}
            </Field>

            <Field label="Amount" required error={errors.amount}>
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

            <Field label="Paid with" required>
              {({ id }) => (
                <Select id={id} value={values.paymentMode} onChange={set('paymentMode')}>
                  {Object.entries(SUPPLIER_PAYMENT_MODE).map(([value, meta]) => (
                    <option key={value} value={value}>
                      {meta.label}
                    </option>
                  ))}
                </Select>
              )}
            </Field>
          </div>
        </Card>

        {isCheque ? (
          <Card>
            <div className="flex flex-col gap-4">
              <p className="text-ink-muted text-[12.5px]">
                A cheque is recorded as <strong className="text-ink">issued</strong>. It only
                becomes a cleared payment once the money actually leaves the bank.
              </p>

              <Field label="Cheque number" required error={errors.chequeNo}>
                {({ id, invalid }) => (
                  <Input
                    id={id}
                    invalid={invalid}
                    value={values.chequeNo}
                    onChange={set('chequeNo')}
                    inputMode="numeric"
                    placeholder="452118"
                  />
                )}
              </Field>

              <Field
                label="Date written on the cheque"
                required
                error={errors.chequeDate}
                hint="A future date is normal — that is the point of the register"
              >
                {({ id, invalid }) => (
                  <Input
                    id={id}
                    invalid={invalid}
                    type="date"
                    value={values.chequeDate}
                    onChange={set('chequeDate')}
                  />
                )}
              </Field>
            </div>
          </Card>
        ) : null}

        {isTransfer ? (
          <Card>
            <Field label="Bank reference">
              {({ id }) => (
                <Input
                  id={id}
                  value={values.referenceNo}
                  onChange={set('referenceNo')}
                  placeholder="TXN12345678"
                />
              )}
            </Field>
          </Card>
        ) : null}

        <Card>
          <div className="flex flex-col gap-4">
            <Field label="Payment date (AD)" required error={errors.paymentDate}>
              {({ id, invalid }) => (
                <Input
                  id={id}
                  invalid={invalid}
                  type="date"
                  value={values.paymentDate}
                  onChange={set('paymentDate')}
                />
              )}
            </Field>

            <Field label="Payment date (BS)">
              {({ id }) => (
                <Input
                  id={id}
                  value={values.paymentDateBs}
                  onChange={set('paymentDateBs')}
                  placeholder="2083-05-16"
                  inputMode="numeric"
                />
              )}
            </Field>

            <Field label="Note" hint="Which bills this settles, if it matters">
              {({ id }) => (
                <TextArea
                  id={id}
                  value={values.description}
                  onChange={set('description')}
                  rows={2}
                />
              )}
            </Field>
          </div>
        </Card>

        <Button size="lg" block loading={mutation.isPending} onClick={submit}>
          Save payment
        </Button>
      </div>
    </Screen>
  );
}
