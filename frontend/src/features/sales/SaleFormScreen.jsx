import { useMemo, useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useNavigate } from 'react-router-dom';
import { Plus, Trash2 } from 'lucide-react';
import { Screen } from '@/components/layout/Screen';
import {
  Button,
  Card,
  Field,
  IconButton,
  Input,
  MoneyInput,
  SegmentedControl,
  Select,
  useToast,
} from '@/components/ui';
import { api, ApiError } from '@/lib/api';
import { queryKeys } from '@/lib/api/query-keys';
import { SALE_PAYMENT_MODE, SALE_UNITS } from '@/lib/constants';
import { formatMoney, todayIso, toNumber } from '@/lib/format';

const TYPES = [
  { value: 'SUMMARY', label: 'Total only' },
  { value: 'DETAILED', label: 'Itemised' },
];

const emptyItem = () => ({
  description: '',
  quantity: '1',
  unit: 'PCS',
  unitPrice: '',
  discount: '',
});

/**
 * Records ONE sale to one customer. Several of these are entered over a day;
 * the day's takings is their sum and is never keyed in directly.
 *
 * Two shapes: "Total only" is the normal case and takes a single figure.
 * "Itemised" takes lines and derives the total from them — the same arithmetic
 * the server runs, so what is shown here and what is stored cannot disagree.
 */
export function SaleFormScreen() {
  const navigate = useNavigate();
  const toast = useToast();
  const queryClient = useQueryClient();

  const [saleType, setSaleType] = useState('SUMMARY');
  const [values, setValues] = useState({
    saleDate: todayIso(),
    saleDateBs: '',
    invoiceNo: '',
    customerId: '',
    description: 'Daily counter sales',
    totalAmount: '',
    discount: '',
    paymentMode: 'CASH',
  });
  const [items, setItems] = useState([emptyItem()]);
  const [errors, setErrors] = useState({});

  const { data: customers } = useQuery({
    queryKey: queryKeys.customers({ limit: 100 }),
    queryFn: () => api.customers.list({ limit: 100 }),
  });

  const set = (key) => (event) => {
    const value = event.target.value;
    setValues((current) => ({ ...current, [key]: value }));
    setErrors((current) => ({ ...current, [key]: undefined }));
  };

  const setItem = (index, key, value) =>
    setItems((current) =>
      current.map((item, i) => (i === index ? { ...item, [key]: value } : item)),
    );

  // Same arithmetic the server runs: quantity × price − line discount.
  const subtotal = useMemo(
    () =>
      saleType === 'DETAILED'
        ? items.reduce(
            (acc, item) =>
              acc + toNumber(item.quantity) * toNumber(item.unitPrice) - toNumber(item.discount),
            0,
          )
        : toNumber(values.totalAmount),
    [saleType, items, values.totalAmount],
  );
  const total = Math.max(0, subtotal - toNumber(values.discount));

  const mutation = useMutation({
    mutationFn: (body) => api.sales.create(body),
    onSuccess: (sale) => {
      queryClient.invalidateQueries({ queryKey: ['sales'] });
      queryClient.invalidateQueries({ queryKey: ['dashboard'] });
      toast.success('Sale recorded');
      navigate(`/sales/${sale.id}`, { replace: true });
    },
    onError: (error) => {
      if (error instanceof ApiError && error.errors.length) setErrors(error.fieldErrors);
      toast.error(error.message);
    },
  });

  const submit = () => {
    const found = {};
    if (!values.saleDate) found.saleDate = 'Sale date is required';

    if (saleType === 'SUMMARY') {
      if (total <= 0) found.totalAmount = 'Enter what the customer paid';
    } else if (items.every((item) => !item.description.trim())) {
      found.items = 'An invoice needs at least one line';
    }

    setErrors(found);
    if (Object.keys(found).length > 0) return;

    const payload = {
      saleType,
      saleDate: values.saleDate,
      saleDateBs: values.saleDateBs || null,
      invoiceNo: saleType === 'DETAILED' ? values.invoiceNo || null : null,
      customerId: values.customerId || null,
      description: saleType === 'SUMMARY' ? values.description || null : null,
      discount: Number(values.discount || 0).toFixed(2),
      payments: [{ paymentMode: values.paymentMode, amount: total.toFixed(2) }],
    };

    if (saleType === 'SUMMARY') {
      payload.totalAmount = total.toFixed(2);
      payload.items = [];
    } else {
      payload.items = items
        .filter((item) => item.description.trim())
        .map((item) => ({
          description: item.description,
          quantity: Number(item.quantity || 0).toFixed(3),
          unit: item.unit,
          unitPrice: Number(item.unitPrice || 0).toFixed(2),
          discount: Number(item.discount || 0).toFixed(2),
        }));
    }

    mutation.mutate(payload);
  };

  return (
    <Screen
      title="New sale"
      back
      reserveBottom={8}
      actions={
        <Button size="sm" variant="ghost" onClick={() => navigate(-1)}>
          Cancel
        </Button>
      }
    >
      <div className="flex flex-col gap-4">
        <SegmentedControl options={TYPES} value={saleType} onChange={setSaleType} />

        <Card>
          <div className="flex flex-col gap-4">
            <Field label="Date (AD)" required error={errors.saleDate}>
              {({ id, invalid }) => (
                <Input
                  id={id}
                  invalid={invalid}
                  type="date"
                  value={values.saleDate}
                  onChange={set('saleDate')}
                />
              )}
            </Field>

            <Field label="Date (BS)" hint="Optional, as written on the invoice">
              {({ id }) => (
                <Input
                  id={id}
                  value={values.saleDateBs}
                  onChange={set('saleDateBs')}
                  placeholder="2083-05-16"
                  inputMode="numeric"
                />
              )}
            </Field>
          </div>
        </Card>

        <Card>
          <div className="flex flex-col gap-4">
            <Field label="Customer" hint="Leave empty for a walk-in">
              {({ id }) => (
                <Select id={id} value={values.customerId} onChange={set('customerId')}>
                  <option value="">Walk-in customer</option>
                  {(customers?.data ?? []).map((customer) => (
                    <option key={customer.id} value={customer.id}>
                      {customer.name}
                    </option>
                  ))}
                </Select>
              )}
            </Field>

            {saleType === 'DETAILED' ? (
              <Field label="Invoice number">
                {({ id }) => (
                  <Input
                    id={id}
                    value={values.invoiceNo}
                    onChange={set('invoiceNo')}
                    placeholder="241"
                    inputMode="numeric"
                  />
                )}
              </Field>
            ) : null}
          </div>
        </Card>

        {saleType === 'SUMMARY' ? (
          <Card>
            <div className="flex flex-col gap-4">
              <Field
                label="Sale amount"
                required
                error={errors.totalAmount}
                hint="What this customer paid in total"
              >
                {({ id, invalid }) => (
                  <MoneyInput
                    id={id}
                    invalid={invalid}
                    value={values.totalAmount}
                    onChange={set('totalAmount')}
                    placeholder="0.00"
                  />
                )}
              </Field>

              <Field label="What was sold" hint="Free text — there are no stock records">
                {({ id }) => (
                  <Input
                    id={id}
                    value={values.description}
                    onChange={set('description')}
                    placeholder="Ladies kurtha, 2 pcs"
                  />
                )}
              </Field>
            </div>
          </Card>
        ) : (
          <>
            <div className="flex flex-col gap-3">
              {items.map((item, index) => (
                <Card key={index}>
                  <div className="flex flex-col gap-3">
                    <div className="flex items-center justify-between gap-2">
                      <span className="label-section">Line {index + 1}</span>
                      {items.length > 1 ? (
                        <IconButton
                          icon={Trash2}
                          size={16}
                          label={`Remove line ${index + 1}`}
                          className="text-out"
                          onClick={() => setItems((c) => c.filter((_, i) => i !== index))}
                        />
                      ) : null}
                    </div>

                    <Input
                      value={item.description}
                      onChange={(event) => setItem(index, 'description', event.target.value)}
                      placeholder="Printed cotton - blue"
                    />

                    <div className="grid grid-cols-3 gap-2">
                      <Input
                        value={item.quantity}
                        onChange={(event) => setItem(index, 'quantity', event.target.value)}
                        inputMode="decimal"
                        aria-label="Quantity"
                      />
                      <Select
                        value={item.unit}
                        onChange={(event) => setItem(index, 'unit', event.target.value)}
                        aria-label="Unit"
                      >
                        {SALE_UNITS.map((unit) => (
                          <option key={unit}>{unit}</option>
                        ))}
                      </Select>
                      <MoneyInput
                        value={item.unitPrice}
                        onChange={(event) => setItem(index, 'unitPrice', event.target.value)}
                        placeholder="Rate"
                        aria-label="Unit price"
                      />
                    </div>

                    <div className="text-ink-muted flex items-center justify-between text-[13px]">
                      <span>Line total</span>
                      <span className="text-ink font-semibold tabular-nums">
                        {formatMoney(
                          toNumber(item.quantity) * toNumber(item.unitPrice) -
                            toNumber(item.discount),
                        )}
                      </span>
                    </div>
                  </div>
                </Card>
              ))}

              {errors.items ? <p className="text-out px-1 text-[12.5px]">{errors.items}</p> : null}

              <Button
                variant="secondary"
                icon={Plus}
                block
                onClick={() => setItems((current) => [...current, emptyItem()])}
              >
                Add another line
              </Button>
            </div>
          </>
        )}

        <Card>
          <div className="flex flex-col gap-4">
            <Field label="Discount on the whole sale">
              {({ id }) => (
                <MoneyInput
                  id={id}
                  value={values.discount}
                  onChange={set('discount')}
                  placeholder="0.00"
                />
              )}
            </Field>

            <Field label="Settled with">
              {({ id }) => (
                <Select id={id} value={values.paymentMode} onChange={set('paymentMode')}>
                  {Object.entries(SALE_PAYMENT_MODE).map(([value, meta]) => (
                    <option key={value} value={value}>
                      {meta.label}
                    </option>
                  ))}
                </Select>
              )}
            </Field>
          </div>
        </Card>

        {/* The running total sits with the button, so it is the last thing
            read before saving. */}
        <div className="bg-surface border-line rounded-card shadow-lift sticky bottom-0 flex flex-col gap-3 border p-4">
          <div className="flex items-baseline justify-between">
            <span className="label-section">Total</span>
            <span className="text-in text-[22px] font-bold tracking-[-0.03em] tabular-nums">
              {formatMoney(total)}
            </span>
          </div>
          <Button size="lg" block loading={mutation.isPending} onClick={submit}>
            Save sale
          </Button>
        </div>
      </div>
    </Screen>
  );
}
