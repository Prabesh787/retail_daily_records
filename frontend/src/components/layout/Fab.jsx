import { Link } from 'react-router-dom';
import { Plus } from 'lucide-react';

export function Fab({ to, label, icon: Icon = Plus }) {
  return (
    <Link
      to={to}
      aria-label={label}
      className="bg-brand shadow-fab animate-rise-in bottom-above-nav ease-out-quart absolute right-4 z-25 inline-flex h-[50px] items-center gap-2 rounded-full px-5 text-[14.5px] font-semibold text-white transition-transform duration-150 active:scale-95"
    >
      <Icon size={19} strokeWidth={2.4} />
      {label}
    </Link>
  );
}
