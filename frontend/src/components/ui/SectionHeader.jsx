export function SectionHeader({ title, action, onAction }) {
  return (
    <div className="flex items-baseline justify-between gap-3 px-1 pb-2">
      <h2 className="label-section">{title}</h2>
      {action ? (
        <button type="button" onClick={onAction} className="text-brand text-[13px] font-semibold">
          {action}
        </button>
      ) : null}
    </div>
  );
}
