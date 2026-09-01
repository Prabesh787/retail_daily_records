import { useEffect, useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useNavigate } from 'react-router-dom';
import { Screen } from '@/components/layout/Screen';
import { Button, Card, Field, Input, SkeletonRows, useToast } from '@/components/ui';
import { api, ApiError } from '@/lib/api';
import { queryKeys } from '@/lib/api/query-keys';

const EMPTY = { name: '', address: '', phone: '', pan: '' };

/**
 * Shop details — the name, address, phone and PAN printed on every report and
 * shown in the app header.
 *
 * These used to be SHOP_* variables in the backend's .env, which meant a
 * misspelt shop name or a newly issued PAN needed a file edit and a restart.
 * They are columns on the signed-in user now, so this screen is the whole fix.
 */
export function ShopFormScreen() {
  const navigate = useNavigate();
  const toast = useToast();
  const queryClient = useQueryClient();

  const { data: profile, isLoading } = useQuery({ queryKey: queryKeys.me, queryFn: api.me });

  const [values, setValues] = useState(EMPTY);
  const [errors, setErrors] = useState({});

  // The form is seeded from the profile once it arrives. `profile.shop` is the
  // dependency rather than `profile` so a background refetch that returns an
  // identical shop does not overwrite what is being typed.
  useEffect(() => {
    if (!profile?.shop) return;
    setValues({
      name: profile.shop.name ?? '',
      address: profile.shop.address ?? '',
      phone: profile.shop.phone ?? '',
      pan: profile.shop.pan ?? '',
    });
  }, [profile?.shop]);

  const set = (key) => (event) => {
    const value = event.target.value;
    setValues((current) => ({ ...current, [key]: value }));
    setErrors((current) => ({ ...current, [key]: undefined }));
  };

  const mutation = useMutation({
    mutationFn: (body) => api.updateMe(body),
    onSuccess: (updated) => {
      // Seed the cache with what came back rather than refetching: every screen
      // reading the header should show the new name on the way out of here.
      queryClient.setQueryData(queryKeys.me, updated);
      toast.success('Shop details saved');
      navigate('/more', { replace: true });
    },
    onError: (error) => {
      if (error instanceof ApiError && error.errors.length) {
        // The API names its fields shopName / shopAddress / ...; the form calls
        // them name / address / ..., so the messages are mapped back.
        const fieldErrors = error.fieldErrors;
        setErrors({
          name: fieldErrors.shopName,
          address: fieldErrors.shopAddress,
          phone: fieldErrors.shopPhone,
          pan: fieldErrors.shopPan,
        });
      }
      toast.error(error.message);
    },
  });

  const submit = () => {
    const found = {};
    if (!values.name.trim()) found.name = 'Shop name is required';

    setErrors(found);
    if (Object.keys(found).length > 0) return;

    // An emptied field is sent as null, not as "": the API stores "not filled
    // in" as NULL, and a blank string would print as a stray line on a report.
    const clean = (value) => (value.trim() === '' ? null : value.trim());

    mutation.mutate({
      shopName: values.name.trim(),
      shopAddress: clean(values.address),
      shopPhone: clean(values.phone),
      shopPan: clean(values.pan),
    });
  };

  return (
    <Screen
      title="Shop details"
      back
      actions={
        <Button size="sm" variant="ghost" onClick={() => navigate(-1)}>
          Cancel
        </Button>
      }
    >
      {isLoading ? (
        <SkeletonRows />
      ) : (
        <div className="flex flex-col gap-4">
          <Card>
            <div className="flex flex-col gap-4">
              <Field
                label="Shop name"
                required
                error={errors.name}
                hint="Printed at the top of every report"
              >
                {({ id, invalid }) => (
                  <Input
                    id={id}
                    invalid={invalid}
                    value={values.name}
                    onChange={set('name')}
                    placeholder="Namuna Cloth House"
                    autoFocus
                  />
                )}
              </Field>

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
            </div>
          </Card>

          <Card>
            <div className="flex flex-col gap-4">
              <Field label="Phone" error={errors.phone}>
                {({ id, invalid }) => (
                  <Input
                    id={id}
                    invalid={invalid}
                    type="tel"
                    inputMode="tel"
                    value={values.phone}
                    onChange={set('phone')}
                    placeholder="071-540123"
                  />
                )}
              </Field>

              <Field
                label="PAN"
                error={errors.pan}
                hint="Shown on bills the shop issues under its PAN"
              >
                {({ id, invalid }) => (
                  <Input
                    id={id}
                    invalid={invalid}
                    inputMode="numeric"
                    value={values.pan}
                    onChange={set('pan')}
                    placeholder="301234567"
                  />
                )}
              </Field>
            </div>
          </Card>

          <Button size="lg" block loading={mutation.isPending} onClick={submit}>
            Save shop details
          </Button>
        </div>
      )}
    </Screen>
  );
}
