import { useEffect, useRef, useState } from "react";
import { CalendarDays } from "lucide-react";
import { cn } from "@/lib/utils";

/**
 * שדה תאריך בפורמט dd/mm/yyyy.
 *
 * <input type="date"> מציג את התאריך לפי ה-locale של הדפדפן/מערכת ההפעלה, ולכן
 * במכונה באנגלית הוא מוצג כ-MM/DD/YYYY ואי אפשר לשנות זאת מה-HTML. הרכיב הזה
 * מציג שדה טקסט בפורמט dd/mm/yyyy קבוע, ומשאיר את חוזה הערך כ-ISO (yyyy-mm-dd)
 * כדי שכל הקריאות ל-API יישארו כמו שהן. כפתור לוח השנה פותח את הבורר המקורי.
 */

/** "2024-03-27" → "27/03/2024" */
export function isoToDisplay(iso: string): string {
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(iso || "");
  return m ? `${m[3]}/${m[2]}/${m[1]}` : "";
}

/** "27/03/2024" → "2024-03-27"; מחזיר "" אם זה לא תאריך אמיתי */
export function displayToIso(text: string): string {
  const m = /^(\d{2})\/(\d{2})\/(\d{4})$/.exec((text || "").trim());
  if (!m) return "";
  const [, dd, mm, yyyy] = m;
  const d = new Date(Number(yyyy), Number(mm) - 1, Number(dd));
  if (d.getFullYear() !== Number(yyyy) || d.getMonth() !== Number(mm) - 1 || d.getDate() !== Number(dd)) {
    return "";
  }
  return `${yyyy}-${mm}-${dd}`;
}

/**
 * מזיז תאריך ISO במספר חודשים אחורה ומחזיר ISO.
 * לא עובר דרך toISOString — הוא ממיר ל-UTC ובאזור זמן חיובי מזיז יום אחורה.
 */
export function isoMinusMonths(iso: string, months: number): string {
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(iso || "");
  if (!m) return iso;
  const d = new Date(Number(m[1]), Number(m[2]) - 1, Number(m[3]));
  d.setMonth(d.getMonth() - months);
  const p = (n: number) => String(n).padStart(2, "0");
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}`;
}

/** משאיר ספרות בלבד ומוסיף לוכסנים תוך כדי הקלדה */
function mask(raw: string): string {
  const digits = raw.replace(/\D/g, "").slice(0, 8);
  if (digits.length <= 2) return digits;
  if (digits.length <= 4) return `${digits.slice(0, 2)}/${digits.slice(2)}`;
  return `${digits.slice(0, 2)}/${digits.slice(2, 4)}/${digits.slice(4)}`;
}

type DateInputProps = {
  /** ISO — yyyy-mm-dd, או "" כשאין תאריך */
  value: string;
  /** מקבל ISO — yyyy-mm-dd, או "" כשהשדה רוקן */
  onChange: (iso: string) => void;
  className?: string;
  disabled?: boolean;
  min?: string;
  max?: string;
  "data-testid"?: string;
};

export function DateInput({ value, onChange, className, disabled, min, max, ...rest }: DateInputProps) {
  const [text, setText] = useState(() => isoToDisplay(value));
  const nativeRef = useRef<HTMLInputElement>(null);

  // מסנכרן כשההורה משנה את הערך מבחוץ (למשל "נקה טווח" או טעינת טווח ברירת מחדל)
  useEffect(() => {
    if (displayToIso(text) !== value) setText(isoToDisplay(value));
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [value]);

  function handleText(raw: string) {
    const masked = mask(raw);
    setText(masked);
    if (masked === "") return onChange("");
    const iso = displayToIso(masked);
    if (iso) onChange(iso);
  }

  function handleBlur() {
    // תאריך חלקי או בלתי אפשרי (31/02/2024) — חוזרים לערך התקין האחרון
    if (text !== "" && !displayToIso(text)) setText(isoToDisplay(value));
  }

  function openPicker() {
    const el = nativeRef.current;
    if (!el || disabled) return;
    try {
      el.showPicker();
    } catch {
      el.focus();
      el.click();
    }
  }

  return (
    <div
      className={cn(
        "relative inline-flex items-center rounded-lg border border-gray-200 bg-white",
        "focus-within:border-indigo-500",
        disabled && "opacity-60",
        className,
      )}
    >
      <input
        type="text"
        inputMode="numeric"
        dir="ltr"
        value={text}
        disabled={disabled}
        onChange={e => handleText(e.target.value)}
        onBlur={handleBlur}
        placeholder="dd/mm/yyyy"
        aria-label="תאריך (dd/mm/yyyy)"
        className="w-[6.75rem] bg-transparent px-2.5 py-1.5 text-center text-sm tabular-nums outline-none"
        {...rest}
      />
      <button
        type="button"
        onClick={openPicker}
        disabled={disabled}
        tabIndex={-1}
        aria-label="בחר תאריך מלוח השנה"
        className="px-1.5 text-gray-400 transition-colors hover:text-indigo-600 disabled:opacity-40"
      >
        <CalendarDays className="h-4 w-4" />
      </button>
      {/* בורר התאריכים המקורי — מוסתר, נפתח מכפתור לוח השנה */}
      <input
        ref={nativeRef}
        type="date"
        value={value}
        min={min}
        max={max}
        tabIndex={-1}
        aria-hidden="true"
        onChange={e => onChange(e.target.value)}
        className="pointer-events-none absolute bottom-0 left-2 h-px w-px opacity-0"
      />
    </div>
  );
}

export default DateInput;

/** הגדול מבין שני תאריכי ISO (השוואת מחרוזות תקפה לפורמט yyyy-mm-dd) */
export function maxIso(a: string, b: string): string {
  if (!a) return b;
  if (!b) return a;
  return a >= b ? a : b;
}
