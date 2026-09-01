import { useNavigate } from 'react-router-dom';
import { Compass } from 'lucide-react';
import { Screen } from '@/components/layout/Screen';
import { Button, EmptyState } from '@/components/ui';

export function NotFoundScreen() {
  const navigate = useNavigate();
  return (
    <Screen title="Not found">
      <EmptyState
        icon={Compass}
        title="This screen does not exist"
        message="The link may be out of date, or the record was removed."
        action={<Button onClick={() => navigate('/')}>Back to home</Button>}
      />
    </Screen>
  );
}
