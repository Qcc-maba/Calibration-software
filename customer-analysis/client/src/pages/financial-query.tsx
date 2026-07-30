import { useState, useMemo } from "react";
import { useQuery } from "@tanstack/react-query";
import DashboardLayout from "@/components/layout/DashboardLayout";
import { RefreshCw, Download, Search, ChevronUp, ChevronDown, ChevronsUpDown } from "lucide-react";
import { cn } from "@/lib/utils";

const COLUMNS = [
  "חשבונית","תאריך החשבונית","מספר לקוח","שם לקוח",
  "שורה בחשבונית","כמות בפירוט החשבונית","כמות מיוחדת בפירוט חשבונית",
  "מק\"ט","תאור מוצר","מטבע",
  "מחיר ליחידה","הנחה לשורה","הנחה כללית",
  "מחיר ליחידה אחרי כל ההנחות (בשקלים)",
  "סהכ לשורה בחשבונית כולל חריגים (בשקלים)",
  "סהכ כותרת (בשקלים)",
  "תעודת משלוח","קריאת שרות","מספר סידורי","תאריך הכיול","שם כייל בעברית",
  "שם סוכן","שם משפחת מוצר","שם מחלקה",
  "תאור אזור","תאור סוג לקוח","תיאור סיווג נוסף ללקוח",
];

const EXTRA_COLUMNS = [
  "לתמחור בלבד","לתמחור בלבד קליטה","מקט סט?","מק\"ט סט קליטה",
  "שער חליפין","מחיר ליחידיה (בשקלים)",
  "מחיר ליחידה אחרי הנחה","מחיר ליחידה אחרי הנחה (בשקלים)",
  "סה\"כ מחיר","סהכ מחיר (בשקלים)",
  "סהכ מחיר לשורה כולל הנחה כללית","סהכ לשורה כולל הנחה כללית (בשקלים)",
  "מחיר ליחידה אחרי כל ההנחות","סהכ לשורה בחשבונית כולל חריגים",
  "ק.ש","סהכ כותרת",
  "כיול חוץ","כיול פנים","מחיר מחירון בסיס",
  "מספר סוכן","מספר לקוח מרכז","קוד אזור",
  "קוד סוג לקוח","קוד סיווג נוסף ללקוח",
  "קוד משפחת מוצר","מספר מחלקה",
];

const MONEY_COLS = new Set([
  "מחיר ליחידה","מחיר ליחידיה (בשקלים)",
  "מחיר ליחידה אחרי הנחה","מחיר ליחידה אחרי הנחה (בשקלים)",
  "סה\"כ מחיר","סהכ מחיר (בשקלים)",
  "סהכ מחיר לשורה כולל הנחה כללית","סהכ לשורה כולל הנחה כללית (בשקלים)",
  "מחיר ליחידה אחרי כל ההנחות","מחיר ליחידה אחרי כל ההנחות (בשקלים)",
  "סהכ לשורה בחשבונית כולל חריגים","סהכ לשורה בחשבונית כולל חריגים (בשקלים)",
  "סהכ כותרת","סהכ כותרת (בשקלים)","מחיר מחירון בסיס",
]);

const PCT_COLS = new Set(["הנחה כללית","הנחה לשורה","שער חליפין"]);

type Row = Record<string, any>;

function fmt(n: number, money = false) {
  if (money) return n.toLocaleString("he-IL", { minimumFractionDigits: 2, maximumFractionDigits: 2 });
  return n.toLocaleString("he-IL", { maximumFractionDigits: 4 });
}

export default function FinancialQueryPage() {
  const now = new Date();
  const firstOfMonth = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2,"0")}-01`;
  const lastOfMonth  = new Date(now.getFullYear(), now.getMonth() + 1, 0).toISOString().slice(0, 10);

  const [dateFrom, setDateFrom] = useState(firstOfMonth);
  const [dateTo,   setDateTo]   = useState(lastOfMonth);
  const [search,   setSearch]   = useState("");
  const [sortCol,  setSortCol]  = useState<string | null>(null);
  const [sortDir,  setSortDir]  = useState<1 | -1>(1);
  const [page,     setPage]     = useState(1);
  const [showExtra, setShowExtra] = useState(false);
  const PAGE_SIZE = 50;

  const [queryParams, setQueryParams] = useState({ dateFrom: "", dateTo: "" });

  const { data, isFetching, error, refetch } = useQuery<{ rows: Row[]; total: number; syncedAt: string | null }>({
    queryKey: ["financial-query", queryParams.dateFrom, queryParams.dateTo],
    queryFn: async () => {
      const res = await fetch(`/api/financial-query?dateFrom=${encodeURIComponent(queryParams.dateFrom)}&dateTo=${encodeURIComponent(queryParams.dateTo)}`);
      if (!res.ok) {
        const err = await res.json().catch(() => ({ error: res.statusText }));
        throw new Error(err.error || res.statusText);
      }
      return res.json();
    },
    staleTime: 5 * 60 * 1000,
    retry: 1,
  });

  function runQuery() {
    setPage(1);
    setQueryParams({ dateFrom, dateTo });
  }

  const visibleCols = showExtra ? [...COLUMNS, ...EXTRA_COLUMNS] : COLUMNS;

  const filtered = useMemo(() => {
    if (!data?.rows) return [];
    const q = search.toLowerCase();
    return data.rows.filter(r =>
      !q || Object.values(r).some(v => String(v ?? "").toLowerCase().includes(q))
    );
  }, [data?.rows, search]);

  const sorted = useMemo(() => {
    if (!sortCol) return filtered;
    return [...filtered].sort((a, b) => {
      const va = String(a[sortCol] ?? ""), vb = String(b[sortCol] ?? "");
      const na = parseFloat(va), nb = parseFloat(vb);
      if (!isNaN(na) && !isNaN(nb)) return (na - nb) * sortDir;
      return va.localeCompare(vb, "he") * sortDir;
    });
  }, [filtered, sortCol, sortDir]);

  const totalPages = Math.max(1, Math.ceil(sorted.length / PAGE_SIZE));
  const pageRows   = sorted.slice((page - 1) * PAGE_SIZE, page * PAGE_SIZE);

  function handleSort(col: string) {
    if (sortCol === col) setSortDir(d => d === 1 ? -1 : 1);
    else { setSortCol(col); setSortDir(1); }
  }

  const uniqueInvoices  = useMemo(() => new Set(filtered.map(r => r["חשבונית"])).size, [filtered]);
  const uniqueCustomers = useMemo(() => new Set(filtered.map(r => r["מספר לקוח"])).size, [filtered]);
  const totalRevenue    = useMemo(() =>
    filtered.reduce((s, r) => s + (parseFloat(r["סהכ לשורה בחשבונית כולל חריגים (בשקלים)"]) || 0), 0),
  [filtered]);

  function exportCSV() {
    if (!sorted.length) return;
    const allCols = [...COLUMNS, ...EXTRA_COLUMNS];
    const esc = (v: any) => `"${String(v ?? "").replace(/"/g, '""')}"`;
    const csv = [
      allCols.map(esc).join(","),
      ...sorted.map(r => allCols.map(c => esc(r[c])).join(",")),
    ].join("\r\n");
    const a = document.createElement("a");
    a.href = URL.createObjectURL(new Blob(["\uFEFF" + csv], { type: "text/csv;charset=utf-8" }));
    a.download = `שאילתא_כספית_${dateFrom}_${dateTo}.csv`;
    a.click();
  }

  return (
    <DashboardLayout>
      <div className="min-h-screen bg-gray-50" dir="rtl" style={{ fontFamily: "Heebo, sans-serif" }}>

        {/* Header */}
        <div className="bg-white border-b border-gray-200 px-6 py-3 flex items-center justify-between sticky top-0 z-30 shadow-sm">
          <div className="flex items-center gap-3">
            <div className="w-9 h-9 rounded-xl bg-emerald-600 flex items-center justify-center">
              <svg viewBox="0 0 24 24" fill="none" stroke="white" strokeWidth="2" strokeLinecap="round" className="w-5 h-5">
                <line x1="12" y1="1" x2="12" y2="23"/><path d="M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6"/>
              </svg>
            </div>
            <div>
              <h1 className="text-lg font-black tracking-tight">שאילתא כספית</h1>
              <p className="text-xs text-gray-500">חשבוניות ופירוט שורות — Priority ERP</p>
            </div>
          </div>
          <div className="flex items-center gap-2">
            {data && data.total > 0 && (
              <div className="text-right">
                <span className="text-xs text-gray-400">{data.total.toLocaleString("he-IL")} שורות</span>
                {data.syncedAt && (
                  <div className="text-xs text-gray-400 opacity-70">
                    עודכן: {new Date(data.syncedAt).toLocaleDateString("he-IL")}
                  </div>
                )}
              </div>
            )}
            <button onClick={exportCSV} disabled={!sorted.length}
              className="flex items-center gap-1.5 px-3 py-1.5 border border-gray-200 bg-white text-gray-600 rounded-lg text-sm font-semibold hover:bg-gray-50 disabled:opacity-40 transition">
              <Download className="w-3.5 h-3.5" /> ייצוא CSV
            </button>
          </div>
        </div>

        {/* Filters */}
        <div className="bg-white border-b border-gray-200 px-6 py-3 flex items-center gap-3 flex-wrap">
          <div className="flex items-center gap-1.5">
            <span className="text-xs text-gray-500 font-semibold whitespace-nowrap">מתאריך:</span>
            <input type="date" value={dateFrom} onChange={e => setDateFrom(e.target.value)}
              className="border border-gray-200 rounded-lg px-2.5 py-1.5 text-sm outline-none focus:border-emerald-500 bg-white" />
          </div>
          <div className="flex items-center gap-1.5">
            <span className="text-xs text-gray-500 font-semibold whitespace-nowrap">עד תאריך:</span>
            <input type="date" value={dateTo} onChange={e => setDateTo(e.target.value)}
              className="border border-gray-200 rounded-lg px-2.5 py-1.5 text-sm outline-none focus:border-emerald-500 bg-white" />
          </div>
          <button onClick={runQuery} disabled={isFetching} data-testid="btn-run-financial-query"
            className="flex items-center gap-1.5 px-4 py-1.5 bg-emerald-600 text-white rounded-lg text-sm font-semibold hover:bg-emerald-700 disabled:opacity-60 transition">
            <RefreshCw className={cn("w-3.5 h-3.5", isFetching && "animate-spin")} />
            {isFetching ? "טוען..." : "הפעל שאילתא"}
          </button>
          <div className="flex-1 min-w-[200px] relative">
            <Search className="absolute right-2.5 top-1/2 -translate-y-1/2 w-3.5 h-3.5 text-gray-400" />
            <input value={search} onChange={e => { setSearch(e.target.value); setPage(1); }}
              placeholder="חיפוש חופשי בתוצאות..."
              className="w-full pr-8 pl-3 py-1.5 border border-gray-200 rounded-lg text-sm outline-none focus:border-emerald-500 bg-white" />
          </div>
          <button onClick={() => setShowExtra(x => !x)}
            className={cn("px-3 py-1.5 border rounded-lg text-xs font-semibold transition",
              showExtra ? "bg-emerald-50 border-emerald-200 text-emerald-700" : "border-gray-200 text-gray-500 hover:bg-gray-50")}>
            {showExtra ? "הסתר עמודות נוספות" : "+ עמודות נוספות"}
          </button>
        </div>

        {/* Summary cards */}
        {data && !isFetching && data.rows.length > 0 && (
          <div className="px-6 pt-4 pb-2 flex gap-3 flex-wrap">
            {[
              { label: "שורות",     value: filtered.length.toLocaleString("he-IL"),          color: "emerald" },
              { label: "חשבוניות", value: uniqueInvoices.toLocaleString("he-IL"),            color: "blue" },
              { label: "לקוחות",   value: uniqueCustomers.toLocaleString("he-IL"),           color: "violet" },
              { label: "סה\"כ (₪)", value: "₪ " + fmt(totalRevenue, true),                   color: "amber" },
            ].map(c => (
              <div key={c.label} className="bg-white border border-gray-200 rounded-xl px-4 py-3 flex items-center gap-3">
                <div className={cn("w-2 h-8 rounded-full", {
                  "bg-emerald-500": c.color === "emerald",
                  "bg-blue-500":    c.color === "blue",
                  "bg-violet-500":  c.color === "violet",
                  "bg-amber-500":   c.color === "amber",
                })} />
                <div>
                  <p className="text-xs text-gray-500 font-medium">{c.label}</p>
                  <p className={cn("font-black", c.label === "סה\"כ (₪)" ? "text-base" : "text-xl")}>{c.value}</p>
                </div>
              </div>
            ))}
            {search && (
              <div className="flex items-center text-xs text-emerald-600 font-semibold bg-emerald-50 border border-emerald-200 rounded-xl px-3">
                🔍 מסונן: {filtered.length.toLocaleString("he-IL")} / {(data.rows.length).toLocaleString("he-IL")}
              </div>
            )}
          </div>
        )}

        {/* Content */}
        <div className="px-6 pb-6 pt-2">
          {!data && !isFetching && !error && (
            <div className="flex items-center justify-center min-h-64">
              <div className="w-10 h-10 rounded-full border-2 border-gray-200 border-t-emerald-600 animate-spin" />
            </div>
          )}

          {isFetching && (
            <div className="flex flex-col items-center justify-center min-h-64 gap-4">
              <div className="w-10 h-10 rounded-full border-2 border-gray-200 border-t-emerald-600 animate-spin" />
              <p className="text-sm text-gray-500">טוען נתונים...</p>
            </div>
          )}

          {error && !isFetching && (
            <div className="max-w-lg mx-auto mt-8 bg-red-50 border border-red-200 rounded-2xl p-6 text-center">
              <div className="text-2xl mb-2">⚠️</div>
              <h3 className="text-red-600 font-bold mb-2">שגיאה</h3>
              <p className="text-gray-600 text-sm mb-4 font-mono bg-red-50 border border-red-100 rounded p-2" dir="ltr">
                {(error as Error).message}
              </p>
              <button onClick={() => refetch()}
                className="px-4 py-2 bg-emerald-600 text-white rounded-lg text-sm font-semibold hover:bg-emerald-700">
                נסה שוב
              </button>
            </div>
          )}

          {!isFetching && !error && data && (
            <>
              {data.rows.length === 0 ? (
                <div className="max-w-lg mx-auto mt-10 bg-amber-50 border border-amber-200 rounded-2xl p-6 text-center">
                  <div className="text-3xl mb-3">💰</div>
                  <h3 className="font-bold text-amber-800 mb-2">אין נתונים מסונכרנים</h3>
                  <p className="text-sm text-amber-700 mb-4">הרץ את סקריפט הסנכרון המקומי:</p>
                  <div className="bg-white border border-amber-200 rounded-lg p-3 text-left font-mono text-xs text-gray-700 mb-4 select-all" dir="ltr">
                    python sync-financial-query.py --date-from 2024-01-01 --date-to 2024-12-31
                  </div>
                  <p className="text-xs text-amber-600">לאחר הסנכרון, הנתונים יישמרו בבסיס הנתונים וניתן לסנן לפי תאריכים.</p>
                </div>
              ) : sorted.length === 0 ? (
                <div className="text-center py-16 text-gray-400">
                  <p>אין תוצאות לטווח התאריכים הנבחר</p>
                </div>
              ) : (
                <>
                  <div className="bg-white border border-gray-200 rounded-xl overflow-hidden shadow-sm">
                    <div className="overflow-auto max-h-[60vh]">
                      <table className="w-max min-w-full border-collapse text-sm" dir="rtl">
                        <thead>
                          <tr>
                            {visibleCols.map(col => {
                              const isActive = sortCol === col;
                              return (
                                <th key={col} onClick={() => handleSort(col)}
                                  className={cn(
                                    "text-right px-3 py-2.5 text-xs font-bold text-gray-500 border-b border-gray-100 sticky top-0 bg-white cursor-pointer whitespace-nowrap select-none hover:text-emerald-600 hover:bg-emerald-50 transition",
                                    isActive && "text-emerald-600 bg-emerald-50"
                                  )}>
                                  <span className="flex items-center gap-1">
                                    {col}
                                    {isActive
                                      ? (sortDir === 1 ? <ChevronUp className="w-3 h-3"/> : <ChevronDown className="w-3 h-3"/>)
                                      : <ChevronsUpDown className="w-3 h-3 opacity-30"/>
                                    }
                                  </span>
                                </th>
                              );
                            })}
                          </tr>
                        </thead>
                        <tbody>
                          {pageRows.map((row, i) => (
                            <tr key={i} className="hover:bg-gray-50 border-b border-gray-50 last:border-0">
                              {visibleCols.map(col => {
                                const v = row[col];
                                if (col === "חשבונית" || col === "קריאת שרות" || col === "תעודת משלוח") {
                                  return (
                                    <td key={col} className="px-3 py-2 whitespace-nowrap">
                                      <span className="inline-block bg-emerald-50 border border-emerald-200 text-emerald-700 rounded px-2 py-0.5 font-bold text-xs font-mono">
                                        {v ?? "—"}
                                      </span>
                                    </td>
                                  );
                                }
                                if (col === "שם כייל בעברית") {
                                  return (
                                    <td key={col} className="px-3 py-2 whitespace-nowrap">
                                      {v ? <span className="inline-block bg-green-50 border border-green-200 text-green-700 rounded px-2 py-0.5 text-xs font-semibold">{v}</span>
                                         : <span className="text-gray-300 text-xs">—</span>}
                                    </td>
                                  );
                                }
                                if (MONEY_COLS.has(col)) {
                                  const n = parseFloat(v);
                                  const isNeg = !isNaN(n) && n < 0;
                                  return (
                                    <td key={col} className={cn("px-3 py-2 text-left whitespace-nowrap font-mono text-xs", isNeg ? "text-red-600" : "text-gray-700")}>
                                      {isNaN(n) ? (v ?? "—") : (isNeg ? "-" : "") + "₪" + fmt(Math.abs(n), true)}
                                    </td>
                                  );
                                }
                                if (PCT_COLS.has(col)) {
                                  const n = parseFloat(v);
                                  return (
                                    <td key={col} className="px-3 py-2 text-left whitespace-nowrap font-mono text-xs text-gray-600">
                                      {isNaN(n) ? (v ?? "—") : n.toFixed(2) + "%"}
                                    </td>
                                  );
                                }
                                if (col === "כמות בפירוט החשבונית" || col === "כמות מיוחדת בפירוט חשבונית") {
                                  const n = parseFloat(v);
                                  return (
                                    <td key={col} className="px-3 py-2 text-left whitespace-nowrap font-mono text-gray-700 text-xs">
                                      {isNaN(n) ? (v ?? "—") : fmt(n)}
                                    </td>
                                  );
                                }
                                if (col === "לתמחור בלבד" || col === "לתמחור בלבד קליטה" || col === "מקט סט?" || col === "מק\"ט סט קליטה" || col === "כיול חוץ" || col === "כיול פנים") {
                                  return (
                                    <td key={col} className="px-3 py-2 text-center">
                                      {v === "Y" ? <span className="text-emerald-600 font-bold text-xs">✓</span> : <span className="text-gray-300 text-xs">—</span>}
                                    </td>
                                  );
                                }
                                return (
                                  <td key={col} className="px-3 py-2 whitespace-nowrap text-gray-700 max-w-[200px] truncate text-xs" title={String(v ?? "")}>
                                    {v ?? "—"}
                                  </td>
                                );
                              })}
                            </tr>
                          ))}
                        </tbody>
                      </table>
                    </div>
                  </div>

                  {totalPages > 1 && (
                    <div className="flex items-center justify-between mt-3 text-sm text-gray-500">
                      <span>מציג {((page - 1) * PAGE_SIZE + 1).toLocaleString("he-IL")}–{Math.min(page * PAGE_SIZE, sorted.length).toLocaleString("he-IL")} מתוך {sorted.length.toLocaleString("he-IL")}</span>
                      <div className="flex items-center gap-1">
                        <button onClick={() => setPage(1)} disabled={page === 1}
                          className="px-2 py-1 border border-gray-200 rounded text-xs hover:bg-gray-50 disabled:opacity-40">«</button>
                        <button onClick={() => setPage(p => Math.max(1, p - 1))} disabled={page === 1}
                          className="px-2 py-1 border border-gray-200 rounded text-xs hover:bg-gray-50 disabled:opacity-40">‹</button>
                        {Array.from({ length: Math.min(7, totalPages) }, (_, i) => {
                          let p: number;
                          if (totalPages <= 7) p = i + 1;
                          else if (page <= 4) p = i + 1;
                          else if (page >= totalPages - 3) p = totalPages - 6 + i;
                          else p = page - 3 + i;
                          return (
                            <button key={p} onClick={() => setPage(p)}
                              className={cn("w-7 h-7 border rounded text-xs transition",
                                page === p ? "bg-emerald-600 border-emerald-600 text-white" : "border-gray-200 hover:bg-gray-50")}>
                              {p}
                            </button>
                          );
                        })}
                        <button onClick={() => setPage(p => Math.min(totalPages, p + 1))} disabled={page === totalPages}
                          className="px-2 py-1 border border-gray-200 rounded text-xs hover:bg-gray-50 disabled:opacity-40">›</button>
                        <button onClick={() => setPage(totalPages)} disabled={page === totalPages}
                          className="px-2 py-1 border border-gray-200 rounded text-xs hover:bg-gray-50 disabled:opacity-40">»</button>
                      </div>
                    </div>
                  )}
                </>
              )}
            </>
          )}
        </div>
      </div>
    </DashboardLayout>
  );
}
