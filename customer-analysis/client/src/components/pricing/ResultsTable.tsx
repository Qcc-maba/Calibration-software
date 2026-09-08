import { Fragment, useMemo, useState } from "react";
import { Check, ChevronDown, ChevronLeft, Copy, Download, Pencil } from "lucide-react";
import * as XLSX from "xlsx";
import { cn } from "@/lib/utils";
import { useToast } from "@/hooks/use-toast";
import {
  PriceListItem,
  PricingResult,
  lookupPartNumber,
  removeOverride,
  setOverride,
} from "@/api/pricing";
import PartNumberInput from "./PartNumberInput";

interface Props {
  results: PricingResult[];
  /** הלקוח הנבחר - תיקונים ידניים נשמרים ונמחקים תחתיו בלבד */
  customerName?: string;
}

const SOURCE_LABEL: Record<string, string> = {
  serial: "מכשיר רשום",
  override: "למידה",
  partNumber: "מק״ט",
  description: "תיאור",
  history: "היסטוריה",
  fuzzy: "דמיון טקסט",
};

interface RowData {
  key: number;
  customerDescription: string;
  customerContext?: string;   // יצרן/דגם/מאפיינים מהקובץ - שימש להתאמה
  customerSerial?: string;    // מספר סידורי - תצוגה בלבד
  customerPartNumber?: string;
  customerName?: string;
  quantity?: number;
  matchType: PricingResult["matchType"];
  matchScore: number;
  matchSource?: PricingResult["matchSource"];
  matchNote?: string;
  mbaNumber?: string;
  mabaPart?: string;
  mabaDescription?: string;
  currency?: string;
  unitPrice?: number;
  totalPrice?: number;
  alternatives: Array<{ item: PriceListItem; score: number }>;
}

function MatchBadge({ type, score }: { type: PricingResult["matchType"]; score: number }) {
  const pct = Math.round(score * 100);
  const map = {
    exact: ["bg-emerald-50 border-emerald-200 text-emerald-700", "התאמה מדויקת"],
    close: ["bg-amber-50 border-amber-200 text-amber-700", `התאמה קרובה (${pct}%)`],
    weak: ["bg-orange-50 border-orange-200 text-orange-700", `ניחוש (${pct}%)`],
    none: ["bg-red-50 border-red-200 text-red-700", "לא נמצא"],
  } as const;
  const [cls, label] = map[type];
  return <span className={cn("inline-block px-2 py-0.5 rounded-md border text-xs font-semibold whitespace-nowrap", cls)}>{label}</span>;
}

function CopyText({ value, className }: { value: string; className?: string }) {
  const [copied, setCopied] = useState(false);
  return (
    <button
      type="button"
      onClick={() => {
        navigator.clipboard?.writeText(value);
        setCopied(true);
        setTimeout(() => setCopied(false), 1200);
      }}
      title="העתק"
      className={cn("group inline-flex items-center gap-1", className)}
    >
      <span>{value}</span>
      {copied
        ? <Check className="w-3 h-3 text-emerald-600" />
        : <Copy className="w-3 h-3 opacity-0 group-hover:opacity-60 transition" />}
    </button>
  );
}

export default function ResultsTable({ results, customerName }: Props) {
  const { toast } = useToast();
  // overrides שנבחרו בסשן הנוכחי (כדי לעדכן את התצוגה בלי לרענן). הם נשמרים
  // גם בשרת ברגע הבחירה.
  const [localOverrides, setLocalOverrides] = useState<Map<number, PriceListItem>>(new Map());
  // שורות שהמשתמש ביטל בהן את האישור בסשן הנוכחי (כדי להציג אותן שוב כניחוש)
  const [revertedRows, setRevertedRows] = useState<Set<number>>(new Set());
  const [expanded, setExpanded] = useState<Set<number>>(new Set());
  const [manualPnEdit, setManualPnEdit] = useState<Record<number, string>>({});
  const [savingIdx, setSavingIdx] = useState<number | null>(null);
  const [customerFilter, setCustomerFilter] = useState<string>("");

  const toggleExpand = (key: number) =>
    setExpanded(prev => {
      const next = new Set(prev);
      next.has(key) ? next.delete(key) : next.add(key);
      return next;
    });

  const applyOverride = async (rowIdx: number, item: PriceListItem, customerDesc: string, context?: string) => {
    setSavingIdx(rowIdx);
    try {
      await setOverride(customerDesc, item.partNumber, undefined, customerName, context);
      setLocalOverrides(prev => new Map(prev).set(rowIdx, item));
      setRevertedRows(prev => {
        if (!prev.has(rowIdx)) return prev;
        const next = new Set(prev);
        next.delete(rowIdx);
        return next;
      });
      toast({
        title: `נשמר${customerName ? ` עבור "${customerName}"` : ""}`,
        description: `"${customerDesc.substring(0, 30)}" → ${item.partNumber}`,
      });
    } catch (e: any) {
      toast({ title: "שגיאה בשמירת ההתאמה", description: e?.message, variant: "destructive" });
    } finally {
      setSavingIdx(null);
    }
  };

  // ביטול אישור: מוחק את ה-override מהשרת ומחזיר את ההתאמה המקורית
  const revertConfirm = async (rowIdx: number, customerDesc: string, context?: string) => {
    setSavingIdx(rowIdx);
    try {
      await removeOverride(customerDesc, customerName, context);
      setLocalOverrides(prev => {
        const next = new Map(prev);
        next.delete(rowIdx);
        return next;
      });
      setRevertedRows(prev => new Set(prev).add(rowIdx));
      toast({ title: "האישור בוטל", description: `"${customerDesc.substring(0, 30)}"` });
    } catch (e: any) {
      toast({ title: "שגיאה בביטול האישור", description: e?.message, variant: "destructive" });
    } finally {
      setSavingIdx(null);
    }
  };

  const applyManualPn = async (rowIdx: number, customerDesc: string, pn: string, context?: string) => {
    if (!pn.trim()) return;
    setSavingIdx(rowIdx);
    try {
      const item = await lookupPartNumber(pn.trim());
      if (!item) {
        toast({ title: `מק"ט "${pn}" לא נמצא במחירון`, variant: "destructive" });
        return;
      }
      await applyOverride(rowIdx, item, customerDesc, context);
      setManualPnEdit(prev => {
        const next = { ...prev };
        delete next[rowIdx];
        return next;
      });
    } finally {
      setSavingIdx(null);
    }
  };

  const data: RowData[] = useMemo(() => results.map((r, idx) => {
    const qty = r.input.quantity ?? 1;
    // בחירה של המשתמש בסשן הנוכחי גוברת על ההתאמה המקורית; ביטול אישור מוריד
    // התאמה מדויקת ל"ניחוש" כדי שאפשר יהיה לבחור מחדש.
    const override = localOverrides.get(idx);
    const isReverted = revertedRows.has(idx);
    const matched = override ?? r.matched;
    let matchType: PricingResult["matchType"] = override ? "exact" : r.matchType;
    const matchScore = override ? 1 : r.matchScore;
    if (!override && isReverted && matchType === "exact") matchType = "weak";
    const unit = matched?.price;
    return {
      key: idx,
      customerDescription: r.input.customerDescription,
      customerContext: r.input.customerContext,
      customerSerial: r.input.customerSerial,
      customerPartNumber: r.input.customerPartNumber,
      customerName: r.input.customerName,
      quantity: qty,
      matchType,
      matchScore,
      matchSource: override ? "override" : r.matchSource,
      matchNote: override ? "תיקון ידני בסשן זה" : r.matchNote,
      mbaNumber: r.mbaNumber,
      mabaPart: matched?.partNumber,
      mabaDescription: matched?.description,
      currency: matched?.currency,
      unitPrice: unit,
      totalPrice: unit !== undefined ? unit * qty : undefined,
      alternatives: r.alternatives,
    };
  }), [results, localOverrides, revertedRows]);

  const customerOptions = useMemo(
    () => Array.from(new Set(data.map(r => r.customerName).filter(Boolean))) as string[],
    [data],
  );
  const visible = customerFilter ? data.filter(r => r.customerName === customerFilter) : data;

  const totalsByCurrency = visible.reduce<Record<string, number>>((acc, row) => {
    if (row.totalPrice !== undefined) {
      const c = row.currency || "";
      acc[c] = (acc[c] || 0) + row.totalPrice;
    }
    return acc;
  }, {});

  // סטטיסטיקת התאמה - ממוצע כל הציונים + פירוט לפי סוג ("לא נמצא" נספר כ-0)
  const stats = visible.reduce(
    (acc, r) => {
      acc.total++;
      if (r.matchType === "exact") { acc.exact++; acc.scoreSum += 1; }
      else if (r.matchType === "close") { acc.close++; acc.scoreSum += r.matchScore; }
      else if (r.matchType === "weak") { acc.weak++; acc.scoreSum += r.matchScore; }
      else acc.none++;
      return acc;
    },
    { total: 0, exact: 0, close: 0, weak: 0, none: 0, scoreSum: 0 },
  );
  const avgScore = stats.total > 0 ? (stats.scoreSum / stats.total) * 100 : 0;
  const successRate = stats.total > 0 ? ((stats.exact + stats.close + stats.weak) / stats.total) * 100 : 0;

  const handleExport = () => {
    const rows = visible.map(r => ({
      "לקוח": r.customerName ?? "",
      "תיאור הלקוח": r.customerDescription,
      "יצרן / דגם": r.customerContext ?? "",
      'מק"ט לקוח': r.customerPartNumber ?? "",
      "מספר סידורי": r.customerSerial ?? "",
      "כמות": r.quantity ?? 1,
      "סטטוס":
        r.matchType === "exact" ? "התאמה מדויקת"
        : r.matchType === "close" ? `התאמה קרובה (${Math.round(r.matchScore * 100)}%)`
        : r.matchType === "weak" ? `ניחוש (${Math.round(r.matchScore * 100)}%)`
        : "לא נמצא",
      "מספר מ.ב.א. אחרון": r.mbaNumber ?? "",
      "מקור ההתאמה": r.matchSource ? (SOURCE_LABEL[r.matchSource] ?? r.matchSource) : "",
      "הסבר": r.matchNote ?? "",
      'מק"ט מ.ב.א. הזורע': r.mabaPart ?? "",
      "תיאור במחירון": r.mabaDescription ?? "",
      "מחיר ליחידה": r.unitPrice ?? "",
      "מטבע": r.currency ?? "",
      'סה"כ': r.totalPrice ?? "",
    }));
    const totalsRows = Object.entries(totalsByCurrency).map(([cur, total]) => ({
      "תיאור הלקוח": 'סה"כ',
      "מטבע": cur,
      'סה"כ': total,
    }));
    const wb = XLSX.utils.book_new();
    const ws = XLSX.utils.json_to_sheet([...rows, ...totalsRows]);
    // RTL לקובץ - נפתח נכון בעברית
    if (!ws["!views"]) ws["!views"] = [{ RTL: true }];
    XLSX.utils.book_append_sheet(wb, ws, "תמחור");
    XLSX.writeFile(wb, `תמחור-${new Date().toISOString().slice(0, 10)}.xlsx`);
  };

  if (results.length === 0) {
    return (
      <div className="bg-white border border-gray-200 rounded-2xl p-10 text-center text-gray-400">
        <p className="text-sm">עדיין לא תומחרו מוצרים</p>
      </div>
    );
  }

  const STAT_CARDS = [
    { label: "סה״כ פריטים", value: stats.total.toLocaleString("he-IL"), color: "text-gray-900" },
    { label: "ממוצע ביטחון", value: `${Math.round(avgScore)}%`, color: avgScore >= 70 ? "text-emerald-600" : avgScore >= 40 ? "text-amber-600" : "text-red-600" },
    { label: "אחוז זוהו", value: `${Math.round(successRate)}%`, color: "text-indigo-600" },
    { label: "התאמה מדויקת", value: stats.exact, color: "text-emerald-600" },
    { label: "התאמה קרובה", value: stats.close, color: "text-amber-500" },
    { label: "ניחוש", value: stats.weak, color: "text-orange-600" },
    { label: "לא נמצא", value: stats.none, color: "text-red-600" },
  ];

  const TH = "px-3 py-2 text-xs font-bold text-gray-500 whitespace-nowrap";

  return (
    <div className="bg-white border border-gray-200 rounded-2xl p-5">
      <div className="flex items-center justify-between gap-3 flex-wrap mb-3">
        <h2 className="text-base font-black tracking-tight">תוצאות תמחור</h2>
        <div className="flex items-center gap-2">
          {customerOptions.length > 1 && (
            <select
              value={customerFilter}
              onChange={e => setCustomerFilter(e.target.value)}
              className="px-2.5 py-1.5 border border-gray-200 rounded-lg text-sm bg-white outline-none focus:border-indigo-500"
            >
              <option value="">כל הלקוחות</option>
              {customerOptions.map(c => <option key={c} value={c}>{c}</option>)}
            </select>
          )}
          <button
            onClick={handleExport}
            data-testid="pricing-export"
            className="flex items-center gap-1.5 px-3 py-1.5 border border-indigo-200 bg-indigo-50 text-indigo-700 rounded-lg text-sm font-semibold hover:bg-indigo-100 transition"
          >
            <Download className="w-3.5 h-3.5" /> הורדה לאקסל
          </button>
        </div>
      </div>

      <div className="flex flex-wrap gap-2 mb-4">
        {STAT_CARDS.map(c => (
          <div key={c.label} className="bg-gray-50 border border-gray-200 rounded-xl px-3 py-2 min-w-[104px]">
            <p className="text-[11px] text-gray-500 font-medium whitespace-nowrap">{c.label}</p>
            <p className={cn("text-lg font-black", c.color)}>{c.value}</p>
          </div>
        ))}
      </div>

      <div className="overflow-x-auto border border-gray-200 rounded-xl">
        <table className="w-full text-sm" data-testid="pricing-results-table">
          <thead className="bg-gray-50 border-b border-gray-200">
            <tr>
              <th className={cn(TH, "w-10")}></th>
              <th className={cn(TH, "w-10 text-center")}>#</th>
              <th className={cn(TH, "text-right")}>לקוח</th>
              <th className={cn(TH, "text-right")}>תיאור הלקוח</th>
              <th className={cn(TH, "text-center")}>כמות</th>
              <th className={cn(TH, "text-right")}>סטטוס</th>
              <th className={cn(TH, "text-center")}>אישור</th>
              <th className={cn(TH, "text-right")}>מק״ט מ.ב.א. הזורע</th>
              <th className={cn(TH, "text-right")}>תיאור במחירון</th>
              <th className={cn(TH, "text-right")}>מס׳ מ.ב.א. אחרון</th>
              <th className={cn(TH, "text-left")}>מחיר ליחידה</th>
              <th className={cn(TH, "text-left")}>סה״כ</th>
            </tr>
          </thead>
          <tbody>
            {visible.map((row, i) => {
              // מאושר = יש override בסשן, או התאמה מדויקת מקורית שלא בוטלה
              const isConfirmed = localOverrides.has(row.key) || row.matchType === "exact";
              const matchedItem = localOverrides.get(row.key) ?? results[row.key].matched ?? undefined;
              const isOpen = expanded.has(row.key);
              return (
                <Fragment key={row.key}>
                  <tr className={cn("border-b border-gray-100", i % 2 === 1 && "bg-gray-50/40")}>
                    <td className="px-2 py-2 align-top">
                      <button
                        onClick={() => toggleExpand(row.key)}
                        title={isOpen ? "סגור" : "הצג חלופות / הזנה ידנית"}
                        className="p-1 rounded hover:bg-gray-100 text-gray-400"
                      >
                        {isOpen ? <ChevronDown className="w-4 h-4" /> : <ChevronLeft className="w-4 h-4" />}
                      </button>
                    </td>
                    <td className="px-2 py-2 text-center text-gray-400 align-top">{i + 1}</td>
                    <td className="px-3 py-2 align-top text-gray-700">{row.customerName || <span className="text-gray-300">—</span>}</td>
                    <td className="px-3 py-2 align-top min-w-[220px]">
                      <div>{row.customerDescription}</div>
                      {row.customerContext && <div className="text-[11px] text-gray-400">{row.customerContext}</div>}
                      {row.customerPartNumber && <div className="text-[11px] text-gray-400">מק״ט לקוח: {row.customerPartNumber}</div>}
                      {row.customerSerial && <div className="text-[11px] text-gray-400">מס״ד: {row.customerSerial}</div>}
                    </td>
                    <td className="px-3 py-2 text-center align-top">{row.quantity}</td>
                    <td className="px-3 py-2 align-top">
                      <MatchBadge type={row.matchType} score={row.matchScore} />
                      {row.matchSource && row.mabaPart && (
                        <div className="text-[11px] text-gray-400 mt-0.5" title={row.matchNote}>
                          מקור: {SOURCE_LABEL[row.matchSource] ?? row.matchSource}
                        </div>
                      )}
                    </td>
                    <td className="px-3 py-2 text-center align-top">
                      {row.mabaPart ? (
                        <input
                          type="checkbox"
                          checked={isConfirmed}
                          disabled={savingIdx === row.key}
                          title={isConfirmed ? "מאושר (100%) - לחץ לביטול" : "סמן אם ההתאמה נכונה"}
                          onChange={e => {
                            if (e.target.checked) {
                              if (matchedItem) applyOverride(row.key, matchedItem, row.customerDescription, row.customerContext);
                            } else {
                              revertConfirm(row.key, row.customerDescription, row.customerContext);
                            }
                          }}
                          className="w-4 h-4 accent-indigo-600 cursor-pointer disabled:opacity-40"
                        />
                      ) : <span className="text-gray-300">—</span>}
                    </td>
                    <td className="px-3 py-2 align-top">
                      {row.mabaPart
                        ? <CopyText value={row.mabaPart} className={cn("font-bold", row.matchType === "weak" ? "text-orange-600" : "text-indigo-700")} />
                        : <span className="text-gray-300">—</span>}
                    </td>
                    <td className="px-3 py-2 align-top text-gray-700 min-w-[220px]">
                      {row.mabaDescription || <span className="text-gray-300">—</span>}
                    </td>
                    <td className="px-3 py-2 align-top">
                      {row.mbaNumber ? <CopyText value={row.mbaNumber} /> : <span className="text-gray-300">—</span>}
                    </td>
                    <td className="px-3 py-2 text-left align-top whitespace-nowrap" dir="ltr">
                      {row.unitPrice !== undefined ? `${row.unitPrice.toFixed(2)} ${row.currency || ""}`.trim() : "—"}
                    </td>
                    <td className="px-3 py-2 text-left align-top whitespace-nowrap font-bold" dir="ltr">
                      {row.totalPrice !== undefined ? `${row.totalPrice.toFixed(2)} ${row.currency || ""}`.trim() : "—"}
                    </td>
                  </tr>

                  {isOpen && (
                    <tr className="border-b border-gray-100 bg-indigo-50/30">
                      <td colSpan={12} className="px-6 py-3">
                        {row.alternatives.length > 0 && (
                          <div className="mb-3">
                            <p className="text-xs font-bold text-gray-600 mb-1">
                              הצעות חלופיות (לחץ "בחר" לשמירה לפעם הבאה):
                            </p>
                            {row.alternatives.map((alt, ai) => (
                              <div key={ai} className="flex items-center gap-2 py-0.5 text-sm">
                                <span
                                  className="px-1.5 py-0.5 rounded bg-white border border-gray-200 text-[11px] font-semibold text-gray-500"
                                  title={`רמת התאמה: ${Math.round(alt.score * 100)}%`}
                                >
                                  {Math.round(alt.score * 100)}%
                                </span>
                                <span className="font-mono text-xs bg-white border border-gray-200 rounded px-1.5 py-0.5">{alt.item.partNumber}</span>
                                <span className="text-gray-700">{alt.item.description}</span>
                                {alt.item.price !== undefined && (
                                  <span className="text-gray-400 text-xs" dir="ltr">({alt.item.price.toFixed(2)} {alt.item.currency || ""})</span>
                                )}
                                <button
                                  disabled={savingIdx === row.key}
                                  onClick={() => applyOverride(row.key, alt.item, row.customerDescription, row.customerContext)}
                                  className="flex items-center gap-1 text-indigo-600 text-xs font-semibold hover:underline disabled:opacity-40"
                                >
                                  <Check className="w-3 h-3" /> בחר
                                </button>
                              </div>
                            ))}
                          </div>
                        )}

                        <div className="pt-2 border-t border-dashed border-gray-300">
                          <div className="flex items-center gap-2 flex-wrap">
                            <Pencil className="w-3.5 h-3.5 text-gray-400" />
                            <span className="text-xs font-bold text-gray-600">או הזן מק"ט / תיאור ידנית:</span>
                            <PartNumberInput
                              value={manualPnEdit[row.key] ?? ""}
                              onChange={text => setManualPnEdit(prev => ({ ...prev, [row.key]: text }))}
                              onPick={pn => applyManualPn(row.key, row.customerDescription, pn, row.customerContext)}
                              disabled={savingIdx === row.key}
                            />
                            <button
                              disabled={savingIdx === row.key}
                              onClick={() => applyManualPn(row.key, row.customerDescription, manualPnEdit[row.key] ?? "", row.customerContext)}
                              className="flex items-center gap-1 px-2.5 py-1 border border-indigo-200 bg-indigo-50 text-indigo-700 rounded-lg text-xs font-semibold hover:bg-indigo-100 disabled:opacity-40 transition"
                            >
                              <Check className="w-3 h-3" /> שמור
                            </button>
                          </div>
                          <p className="text-[11px] text-gray-400 mt-1">
                            הבחירה תישמר על השרת ותחול אוטומטית על אותו תיאור גם בקבצים הבאים.
                          </p>
                        </div>
                      </td>
                    </tr>
                  )}
                </Fragment>
              );
            })}
          </tbody>
          {Object.keys(totalsByCurrency).length > 0 && (
            <tfoot className="bg-gray-50 border-t border-gray-200">
              <tr>
                <td colSpan={10} className="px-3 py-2 text-left font-bold">סה״כ:</td>
                <td colSpan={2} className="px-3 py-2 text-left font-black" dir="ltr">
                  {Object.entries(totalsByCurrency).map(([cur, total]) => (
                    <div key={cur}>{total.toFixed(2)} {cur}</div>
                  ))}
                </td>
              </tr>
            </tfoot>
          )}
        </table>
      </div>
    </div>
  );
}
