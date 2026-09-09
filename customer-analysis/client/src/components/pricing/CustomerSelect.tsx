import { useEffect, useMemo, useRef, useState } from "react";
import { User } from "lucide-react";
import { cn } from "@/lib/utils";
import { CustomerRef, listCustomers } from "@/api/pricing";

interface Props {
  value: string;
  onChange: (name: string) => void;
  disabled?: boolean;
}

/**
 * בחירת לקוח בטקסט חופשי עם השלמה אוטומטית: לקוחות שכבר נלמדו מהם התאמות
 * (מקומיים) ואחריהם רשימת הלקוחות מפריוריטי. ריק = ללא לקוח, כלומר התאמה
 * מול המאגר הכללי.
 *
 * השדה נשאר חופשי בכוונה: אפשר להקליד גם קוד פריוריטי ("10251") והוא מומר
 * לשם המלא ביציאה מהשדה, כי ההתאמה לפי מספר סידורי עובדת מול השם.
 */
export default function CustomerSelect({ value, onChange, disabled }: Props) {
  const [customers, setCustomers] = useState<CustomerRef[]>([]);
  const [query, setQuery] = useState(value);
  const [open, setOpen] = useState(false);
  const debounceRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const boxRef = useRef<HTMLDivElement>(null);

  const load = async (q?: string) => {
    try {
      setCustomers(await listCustomers(q));
    } catch {
      // רשימת ההשלמה היא נוחות בלבד - כשל בטעינה לא חוסם הקלדה חופשית
    }
  };

  useEffect(() => { load(); }, []);
  useEffect(() => { setQuery(value); }, [value]);

  // סגירה בלחיצה מחוץ לרכיב
  useEffect(() => {
    const onDocClick = (e: MouseEvent) => {
      if (boxRef.current && !boxRef.current.contains(e.target as Node)) setOpen(false);
    };
    document.addEventListener("mousedown", onDocClick);
    return () => document.removeEventListener("mousedown", onDocClick);
  }, []);

  const handleSearch = (text: string) => {
    setQuery(text);
    onChange(text);
    setOpen(true);
    if (debounceRef.current) clearTimeout(debounceRef.current);
    debounceRef.current = setTimeout(() => load(text), 200);
  };

  const typed = value.trim().toLowerCase();
  const known = useMemo(
    () => customers.find(c => c.name.trim().toLowerCase() === typed),
    [customers, typed],
  );
  // הוקלד קוד לקוח ולא שם - מזהים אותו ומציגים מיהו הלקוח
  const byCode = useMemo(
    () => (!known && typed ? customers.find(c => (c.code ?? "").trim().toLowerCase() === typed) : undefined),
    [customers, known, typed],
  );
  const learnedFrom = known && known.source !== "priority" ? known : undefined;

  // המרה אוטומטית של קוד לשם ברגע שברור שהמשתמש סיים להקליד
  const applyCode = () => {
    if (byCode) { setQuery(byCode.name); onChange(byCode.name); }
  };

  const select = (name: string) => {
    setQuery(name);
    onChange(name);
    setOpen(false);
  };

  return (
    <div ref={boxRef} className="relative max-w-md">
      <div className="flex items-center gap-2 flex-wrap mb-1.5">
        <span className="flex items-center gap-1 text-xs font-bold text-gray-600">
          <User className="w-3.5 h-3.5" /> לקוח
        </span>
        {byCode ? (
          <span className="px-2 py-0.5 rounded-md bg-indigo-50 border border-indigo-200 text-indigo-700 text-xs font-semibold">
            קוד {byCode.code} = {byCode.name}
          </span>
        ) : value.trim() ? (
          learnedFrom ? (
            <span className="px-2 py-0.5 rounded-md bg-indigo-50 border border-indigo-200 text-indigo-700 text-xs font-semibold">
              מסנן לפי "{learnedFrom.name}" — {learnedFrom.overrides} התאמות שנלמדו
            </span>
          ) : (
            <span className="px-2 py-0.5 rounded-md bg-amber-50 border border-amber-200 text-amber-700 text-xs font-semibold">
              {known ? `לקוח מפריוריטי (${known.code}) — ` : "לקוח חדש — "}
              עדיין לא נלמדו ממנו התאמות
            </span>
          )
        ) : (
          <span className="px-2 py-0.5 rounded-md bg-gray-100 border border-gray-200 text-gray-500 text-xs font-semibold">
            ללא לקוח — התאמה מול המאגר הכללי
          </span>
        )}
      </div>

      <input
        value={query}
        onChange={e => handleSearch(e.target.value)}
        onFocus={() => setOpen(true)}
        onBlur={applyCode}
        onKeyDown={e => {
          if (e.key === "Enter") { applyCode(); setOpen(false); }
          if (e.key === "Escape") setOpen(false);
        }}
        disabled={disabled}
        placeholder="שם לקוח או קוד פריוריטי (אפשר להשאיר ריק)"
        data-testid="pricing-customer-input"
        className="w-full px-3 py-1.5 border border-gray-200 rounded-lg text-sm outline-none focus:border-indigo-500 bg-white disabled:bg-gray-50 disabled:text-gray-400"
      />

      {open && customers.length > 0 && (
        <div className="absolute z-40 mt-1 w-full max-h-72 overflow-y-auto bg-white border border-gray-200 rounded-lg shadow-lg">
          {customers.map(c => (
            <button
              key={`${c.source}-${c.code ?? ""}-${c.name}`}
              type="button"
              onMouseDown={e => e.preventDefault()}
              onClick={() => select(c.name)}
              className="w-full flex items-center justify-between gap-3 px-3 py-1.5 text-sm text-right hover:bg-indigo-50 transition"
            >
              <span className="truncate">
                {c.display ?? c.name}
                {/* פריוריטי שומר שמות לטיניים הפוך. מציגים את הצורה הקריאה,
                    ולצדה את השם כפי שהוא שם - כדי שאפשר יהיה לזהות אותו מול המערכת. */}
                {c.display && (
                  <span className="text-gray-400 text-[11px] mr-1.5" dir="ltr">({c.name})</span>
                )}
              </span>
              <span
                className={cn(
                  "shrink-0 px-1.5 py-0.5 rounded text-[11px] font-semibold border",
                  c.source === "priority"
                    ? "bg-gray-50 border-gray-200 text-gray-500"
                    : c.overrides > 0
                      ? "bg-indigo-50 border-indigo-200 text-indigo-700"
                      : "bg-gray-50 border-gray-200 text-gray-500",
                )}
              >
                {c.source === "priority" ? (c.code || "פריוריטי") : `${c.overrides} התאמות`}
              </span>
            </button>
          ))}
        </div>
      )}
    </div>
  );
}
