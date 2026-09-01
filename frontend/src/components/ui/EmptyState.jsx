export function EmptyState({ icon: Icon, title, message, action }) {
  return (
    <div className="animate-rise-in flex flex-col items-center gap-2 px-6 py-10 text-center">
      {Icon ? (
        <span className="bg-sunken text-ink-subtle mb-2 grid size-[60px] place-items-center rounded-[28px]">
          <Icon size={26} strokeWidth={1.6} />
        </span>
      ) : null}
      <p className="text-base font-semibold">{title}</p>
      {message ? <p className="text-ink-muted max-w-[30ch] text-[13.5px]">{message}</p> : null}
      {action ? <div className="mt-2">{action}</div> : null}
    </div>
  );
}
