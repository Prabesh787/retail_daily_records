import { useState } from 'react';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useLocation, useNavigate } from 'react-router-dom';
import { KeyRound, Store } from 'lucide-react';
import { Button, Card, Field, Input, useToast } from '@/components/ui';
import { api, ApiError } from '@/lib/api';

/**
 * The front door. Every route except this one needs a session, so this screen
 * is deliberately self-contained: no shop data is read here, because none of it
 * would load yet.
 *
 * On success the whole query cache is cleared before navigating. The next
 * account to sign in must not see anything cached under the last one.
 */
export function LoginScreen() {
  const navigate = useNavigate();
  const location = useLocation();
  const toast = useToast();
  const queryClient = useQueryClient();

  const [values, setValues] = useState({ email: '', password: '' });
  const [errors, setErrors] = useState({});

  // Where the user was headed before being sent here, so signing in resumes it.
  const destination = location.state?.from ?? '/';

  const set = (key) => (event) => {
    const value = event.target.value;
    setValues((current) => ({ ...current, [key]: value }));
    setErrors((current) => ({ ...current, [key]: undefined }));
  };

  const mutation = useMutation({
    mutationFn: (body) => api.auth.login(body),
    onSuccess: (session) => {
      queryClient.clear();
      toast.success(`Signed in as ${session.user.name}`);
      navigate(destination, { replace: true });
    },
    onError: (error) => {
      if (error instanceof ApiError && error.errors.length) setErrors(error.fieldErrors);
      toast.error(error.message);
    },
  });

  const submit = (event) => {
    event.preventDefault();

    const found = {};
    if (!values.email.trim()) found.email = 'Email is required';
    else if (!/^\S+@\S+\.\S+$/.test(values.email.trim()))
      found.email = 'Enter a valid email address';
    if (!values.password) found.password = 'Password is required';

    setErrors(found);
    if (Object.keys(found).length > 0) return;

    mutation.mutate({ email: values.email.trim().toLowerCase(), password: values.password });
  };

  return (
    <main className="scroll-area flex min-h-0 flex-1 flex-col justify-center p-6">
      <div className="animate-rise-in flex flex-col gap-6">
        <header className="flex flex-col items-center gap-3 text-center">
          <span className="bg-brand shadow-fab grid size-14 place-items-center rounded-2xl text-white">
            <Store size={26} strokeWidth={2.2} />
          </span>
          <div>
            <h1 className="text-[23px] font-bold tracking-[-0.03em]">Shop Records</h1>
            <p className="text-ink-muted text-[13.5px]">Sign in to open the shop’s books</p>
          </div>
        </header>

        {/* A real form element, so the phone keyboard shows "Go" and Enter submits. */}
        <form onSubmit={submit} noValidate>
          <Card>
            <div className="flex flex-col gap-4">
              <Field label="Email" required error={errors.email}>
                {({ id, invalid }) => (
                  <Input
                    id={id}
                    invalid={invalid}
                    type="email"
                    inputMode="email"
                    autoComplete="username"
                    autoCapitalize="none"
                    autoCorrect="off"
                    value={values.email}
                    onChange={set('email')}
                    placeholder="you@shop.com"
                    autoFocus
                  />
                )}
              </Field>

              <Field label="Password" required error={errors.password}>
                {({ id, invalid }) => (
                  <Input
                    id={id}
                    invalid={invalid}
                    type="password"
                    autoComplete="current-password"
                    value={values.password}
                    onChange={set('password')}
                    placeholder="••••••••"
                  />
                )}
              </Field>

              <Button type="submit" size="lg" block loading={mutation.isPending}>
                Sign in
              </Button>
            </div>
          </Card>
        </form>

        {/* No "go back" link: without a session there is nowhere to go back to,
            and every route would bounce straight back here. */}
        <p className="text-ink-subtle flex items-start gap-2 px-1 text-[12.5px] leading-relaxed">
          <KeyRound size={14} className="mt-0.5 shrink-0" />
          <span>
            Forgotten the password? There is no self-service reset — an administrator has to set a
            new one.
          </span>
        </p>
      </div>
    </main>
  );
}
