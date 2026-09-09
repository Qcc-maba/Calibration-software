import { useEffect, useRef, useState } from "react";
import { PriceListItem, suggestItems } from "@/api/pricing";

interface Props {
  value: string;
  onChange: (text: string) => void;
  onPick: (partNumber: string) => void;
  disabled?: boolean;
}

/**
 * השלמה אוטומטית מתוך המחירון להזנה ידנית של מק"ט.
 * החיפוש הוא על מק"ט *ועל תיאור* גם יחד, כי בפועל המשתמש כמעט תמיד יודע
 * לתאר את הפריט ולא לזכור את המספר.
 */
export default function PartNumberInput({ value, onChange, onPick, disabled }: Props) {
  const [items, setItems] = useState<PriceListItem[]>([]);
  const [open, setOpen] = useState(false);
  const timerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const boxRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const onDocClick = (e: MouseEvent) => {
      if (boxRef.current && !boxRef.current.contains(e.target as Node)) setOpen(false);
    };
    document.addEventListener("mousedown", onDocClick);
    return () => document.removeEventListener("mousedown", onDocClick);
  }, []);

  // חיפוש מושהה (200ms) - הקלדה מהירה לא מייצרת בקשה לכל תו
  const search = (text: string) => {
    onChange(text);
    setOpen(true);
    if (timerRef.current) clearTimeout(timerRef.current);
    if (!text.trim()) {
      setItems([]);
      return;
    }
    timerRef.current = setTimeout(async () => {
      try {
        setItems(await suggestItems(text, 10));
      } catch {
        setItems([]);
      }
    }, 200);
  };

  return (
    <div ref={boxRef} className="relative w-[420px] max-w-full">
      <input
        value={value}
        onChange={e => search(e.target.value)}
        onFocus={() => setOpen(true)}
        onKeyDown={e => { if (e.key === "Escape") setOpen(false); }}
        disabled={disabled}
        placeholder="התחל להקליד מק״ט או תיאור מהמחירון…"
        className="w-full px-2.5 py-1 border border-gray-200 rounded-lg text-sm outline-none focus:border-indigo-500 bg-white disabled:bg-gray-50"
      />
      {open && items.length > 0 && (
        <div className="absolute z-40 mt-1 w-[560px] max-w-[90vw] max-h-72 overflow-y-auto bg-white border border-gray-200 rounded-lg shadow-lg">
          {items.map(it => (
            <button
              key={it.partNumber}
              type="button"
              onMouseDown={e => e.preventDefault()}
              onClick={() => { setOpen(false); onPick(it.partNumber); }}
              title={`${it.partNumber} — ${it.description}`}
              className="w-full flex items-start justify-between gap-3 px-3 py-1.5 text-sm text-right hover:bg-indigo-50 transition"
            >
              <span className="font-bold text-indigo-700 shrink-0">{it.partNumber}</span>
              <span className="text-gray-500 text-xs leading-5">{it.description}</span>
            </button>
          ))}
        </div>
      )}
    </div>
  );
}
