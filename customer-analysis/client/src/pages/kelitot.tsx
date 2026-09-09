import { useState, useEffect, useCallback, useRef } from "react";
import DashboardLayout from "@/components/layout/DashboardLayout";
import { RefreshCw, X, Download, Search, ChevronDown } from "lucide-react";
import { DateInput } from "@/components/ui/date-input";
import { cn } from "@/lib/utils";

const SHEET_ID  = "1APkVKBDGz6p9TKOlBvzLh-J-pxlAZyZ-qSPXnzjaVgo";
const SHEET3_ID = "1boChiqnLUo4syCX5mvKXrwBOMa73D5WUZYOiBJgMuFc";
const SHEET4_ID = "1p20qnNIgL8ZqvIBOjNu8znvdJu_kj74UCrrLcmfqWT4";
const BATCH_SIZE = 500;
const MAX_ROWS   = 20000;
const COL_CALS    = "__calibrators__";
const COL_PDF     = "__pdf__";
const COL_REPORTS = "__reports__";
const HIDDEN_COLS = ["NAME", "EMAIL", "USERNAME"];
const DEFAULT_COLS = [
  "Order Number", "Open Date", "Customer Code", "Customer Name",
  "Cost After Dicount", "Cost After Discount", "STATDES", COL_CALS,
];
const COL_LABELS: Record<string, string> = {
  "Order Number": "מס׳ קליטה",
  "Open Date": "תאריך",
  "Customer Code": "מס לקוח",
  "Customer Name": "שם הלקוח",
  "Cost After Dicount": "תימחור",
  "Cost After Discount": "תימחור",
  "STATDES": "סטטוס",
  [COL_CALS]: "👷 שם הכייל",
  [COL_PDF]: "📁 PDF",
  [COL_REPORTS]: "📋 דוחות",
};

const COLORS = [
  { color: "#16a34a", bg: "#f0fdf4", border: "#bbf7d0" },
  { color: "#2563eb", bg: "#eff6ff", border: "#bfdbfe" },
  { color: "#d97706", bg: "#fffbeb", border: "#fde68a" },
  { color: "#7c3aed", bg: "#f5f3ff", border: "#ddd6fe" },
  { color: "#dc2626", bg: "#fef2f2", border: "#fecaca" },
  { color: "#0891b2", bg: "#ecfeff", border: "#a5f3fc" },
  { color: "#ea580c", bg: "#fff7ed", border: "#fed7aa" },
  { color: "#0d9488", bg: "#f0fdfa", border: "#99f6e4" },
  { color: "#9333ea", bg: "#faf5ff", border: "#e9d5ff" },
  { color: "#be185d", bg: "#fdf2f8", border: "#fbcfe8" },
];

const STATCODE_MAP: Record<string, string> = {
  AA: "נקלט", AC: "בכיול", DC: "ממתין מבא", DM: "ממתין לקוח",
  GR: "נצר דחה", H1: "חתום 1", H2: "חתום 2", HR: "נדחה",
  UC: "עדכון דוח", UD: "עדכון דוח", UG: "עדכון", UM: "עדכון דוח",
};
const STATCODE_COLOR: Record<string, string> = {
  AA: "#16a34a", AC: "#2563eb", DC: "#d97706", DM: "#f59e0b",
  GR: "#dc2626", H1: "#0891b2", H2: "#0d9488", HR: "#dc2626",
  UC: "#7c3aed", UD: "#7c3aed", UG: "#9333ea", UM: "#7c3aed",
};

type Row = Record<string, string>;

function fetchGviz(sheetId: string, offset: number, tq?: string): Promise<any> {
  return new Promise((resolve, reject) => {
    const cb = `__gviz_${Date.now()}_${offset}_${Math.random().toString(36).slice(2)}`;
    const sc = document.createElement("script");
    let done = false;
    (window as any)[cb] = (raw: any) => {
      done = true;
      delete (window as any)[cb];
      sc.remove();
      if (!raw?.table) return reject(new Error("NETWORK"));
      resolve(raw.table);
    };
    const query = tq ?? encodeURIComponent(`select * limit ${BATCH_SIZE} offset ${offset}`);
    sc.src = `https://docs.google.com/spreadsheets/d/${sheetId}/gviz/tq?tqx=out:json;responseHandler:${cb}&tq=${query}&headers=1&_t=${Date.now()}`;
    sc.onerror = () => { done = true; sc.remove(); reject(new Error("NETWORK")); };
    document.head.appendChild(sc);
    setTimeout(() => { if (!done) { done = true; sc.remove(); delete (window as any)[cb]; reject(new Error("NETWORK")); } }, 20000);
  });
}

function cellVal(table: any, ri: number, ci: number): string {
  const cell = table.rows[ri]?.c?.[ci];
  if (!cell) return "";
  if (cell.v == null) return cell.f ?? "";
  const v = cell.v;
  if (typeof v === "string" && v.startsWith("Date(")) {
    const p = v.slice(5, -1).split(",").map(Number);
    const d = new Date(p[0], p[1], p[2]);
    return `${String(d.getDate()).padStart(2, "0")}/${String(d.getMonth() + 1).padStart(2, "0")}/${d.getFullYear()}`;
  }
  if (cell.f != null && cell.f !== "") return cell.f;
  return String(v);
}

function tableToRows(table: any): Row[] {
  return (table.rows || []).map((_: any, ri: number) => {
    const obj: Row = {};
    table.cols.forEach((col: any, ci: number) => {
      obj[(col.label || col.id || "").trim()] = cellVal(table, ri, ci);
    });
    return obj;
  }).filter((r: Row) => Object.values(r).some(v => v !== ""));
}

function getHeaders(table: any): string[] {
  return table.cols.map((c: any) => (c.label || c.id || "").trim());
}

function parseDate(s: string): Date | null {
  if (!s) return null;
  s = s.trim();
  let m = s.match(/^(\d{1,2})[\/\-\.](\d{1,2})[\/\-\.](\d{4})$/);
  if (m) return new Date(+m[3], +m[2] - 1, +m[1]);
  m = s.match(/^(\d{4})[\/\-\.](\d{1,2})[\/\-\.](\d{1,2})$/);
  if (m) return new Date(+m[1], +m[2] - 1, +m[3]);
  m = s.match(/^(\d{1,2})[\/\-\.](\d{1,2})[\/\-\.](\d{2})$/);
  if (m) return new Date(2000 + +m[3], +m[2] - 1, +m[1]);
  const dm = s.match(/(\d{4})-(\d{2})-(\d{2})/);
  if (dm) return new Date(+dm[1], +dm[2] - 1, +dm[3]);
  return null;
}

function formatDateIL(s: string): string {
  const d = parseDate(s);
  if (!d) return s;
  return `${String(d.getDate()).padStart(2, "0")}/${String(d.getMonth() + 1).padStart(2, "0")}/${d.getFullYear()}`;
}

function normalizeOrderNum(s: string): string {
  const t = s.trim();
  const n = Number(t);
  return (!isNaN(n) && t !== "") ? String(n) : t;
}

function detectColumns(hdrs: string[]): { colOrderNum: string; colStatus: string; colDate: string | null } {
  const n = hdrs.map(h => h.toLowerCase().replace(/[\s_\-.]/g, ""));
  const exact = (name: string) => hdrs.find(h => h.trim().toLowerCase() === name.toLowerCase());
  const find = (...pats: string[]) => hdrs.find((_, i) => pats.some(p => n[i].includes(p)));

  const colOrderNum = exact("Order Number") || exact("OrderNumber")
    || find("ordernum", "ordernumber", "order", "docno", "קליטה") || hdrs[0];
  const colStatus = exact("STATDES") || exact("Status_K")
    || find("statdes", "status", "סטטוס", "מצב", "שלב") || hdrs[hdrs.length - 1];
  const colDate = exact("Open Date") || exact("Open_Date") || exact("OpenDate")
    || find("opendate", "opendat", "docdate", "date", "תאריך") || null;

  return { colOrderNum: colOrderNum!, colStatus: colStatus!, colDate: colDate ?? null };
}

function aggregateRows(rows: Row[], hdrs: string[], colOrderNum: string): Row[] {
  const n = hdrs.map(h => h.toLowerCase().replace(/[\s_\-.]/g, ""));
  const exact = (name: string) => hdrs.find(h => h.trim().toLowerCase() === name.toLowerCase());
  const colCal = exact("USERNAME") || exact("Workers_Names")
    || hdrs.find((_, i) => ["username","workers_names","workersnames","calibratorname","calibrator","כיילן","כיילים"].some(p => n[i].includes(p)))
    || null;

  const map = new Map<string, Row>();
  const order: string[] = [];
  rows.forEach(row => {
    const key = (row[colOrderNum] || "").trim();
    if (!key) return;
    if (!map.has(key)) {
      map.set(key, { ...row, [COL_CALS]: "" });
      order.push(key);
    }
    const merged = map.get(key)!;
    if (colCal) {
      const cal = (row[colCal] || "").trim();
      if (cal) {
        const existing = merged[COL_CALS] ? merged[COL_CALS].split(", ").map(s => s.trim()) : [];
        if (!existing.includes(cal)) {
          merged[COL_CALS] = existing.length ? merged[COL_CALS] + ", " + cal : cal;
        }
      }
    }
    hdrs.forEach(h => { if (!merged[h] && row[h]) merged[h] = row[h]; });
  });
  return order.map(k => map.get(k)!);
}

async function loadAllRows(sheetId: string): Promise<{ rows: Row[]; headers: string[] }> {
  const first = await fetchGviz(sheetId, 0);
  const headers = getHeaders(first);
  const rows = tableToRows(first);
  let offset = BATCH_SIZE;
  while (rows.length >= offset && offset < MAX_ROWS) {
    try {
      const next = await fetchGviz(sheetId, offset);
      const batch = tableToRows(next);
      if (!batch.length) break;
      rows.push(...batch);
      if (batch.length < BATCH_SIZE) break;
      offset += BATCH_SIZE;
    } catch {
      break;
    }
  }
  return { rows, headers };
}

interface ModalState {
  status: string;
  rows: Row[];
  color: typeof COLORS[0];
}

interface ReportsModalState {
  orderNum: string;
  reports: Row[];
}

export default function KelitotPage() {
  const [loading, setLoading] = useState(false);
  const [loadProgress, setLoadProgress] = useState(0);
  const [error, setError] = useState<string | null>(null);
  const [allRows, setAllRows] = useState<Row[]>([]);
  const [headers, setHeaders] = useState<string[]>([]);
  const [colOrderNum, setColOrderNum] = useState<string>("");
  const [colStatus, setColStatus] = useState<string>("");
  const [colDate, setColDate] = useState<string | null>(null);
  const [pdfSet, setPdfSet] = useState<Set<string>>(new Set());
  const [reportsMap, setReportsMap] = useState<Map<string, Row[]>>(new Map());
  const [lastUpdated, setLastUpdated] = useState<string>("");
  const [statsInfo, setStatsInfo] = useState<string>("");

  const [dateFrom, setDateFrom] = useState("");
  const [dateTo, setDateTo]     = useState("");
  const [calFilter, setCalFilter] = useState("");
  const [selectedStatuses, setSelectedStatuses] = useState<Set<string> | null>(null);
  const [allStatuses, setAllStatuses] = useState<string[]>([]);
  const [statusColorMap, setStatusColorMap] = useState<Record<string, typeof COLORS[0]>>({});
  const [msOpen, setMsOpen] = useState(false);
  const [msSearch, setMsSearch] = useState("");

  const [modal, setModal] = useState<ModalState | null>(null);
  const [modalSearch, setModalSearch] = useState("");
  const [sortCol, setSortCol] = useState<string | null>(null);
  const [sortDir, setSortDir] = useState<1 | -1>(1);

  const [reportsModal, setReportsModal] = useState<ReportsModalState | null>(null);

  const msRef = useRef<HTMLDivElement>(null);

  const load = useCallback(async () => {
    if (loading) return;
    setLoading(true);
    setError(null);
    setLoadProgress(0);
    setAllRows([]);
    setHeaders([]);
    setAllStatuses([]);
    setSelectedStatuses(null);
    setModal(null);

    try {
      const [mainResult, reportsResult, pdfResult] = await Promise.all([
        loadAllRows(SHEET_ID).then(r => { setLoadProgress(r.rows.length); return r; }),
        loadAllRows(SHEET3_ID).catch(() => ({ rows: [], headers: [] })),
        loadAllRows(SHEET4_ID).catch(() => ({ rows: [], headers: [] })),
      ]);

      if (!mainResult.rows.length) throw new Error("הגיליון ריק או שאין הרשאה לצפות בו");

      const { colOrderNum: co, colStatus: cs, colDate: cd } = detectColumns(mainResult.headers);
      const aggregated = aggregateRows(mainResult.rows, mainResult.headers, co);

      if (cd) aggregated.forEach(r => { if (r[cd]) r[cd] = formatDateIL(r[cd]); });

      const newPdfSet = new Set<string>();
      pdfResult.rows.forEach(r => {
        const num = (r["OrderNumber"] || r["orderNum"] || r["ordernumber"] || "").trim();
        if (num) newPdfSet.add(normalizeOrderNum(num));
      });

      const newReportsMap = new Map<string, Row[]>();
      reportsResult.rows.forEach(r => {
        const mbanum = (r["MBANUM"] || "").trim();
        if (!mbanum) return;
        const lastSlash = mbanum.lastIndexOf("/");
        const raw = (lastSlash > -1 ? mbanum.slice(0, lastSlash) : mbanum).trim();
        const orderNum = normalizeOrderNum(raw);
        if (!newReportsMap.has(orderNum)) newReportsMap.set(orderNum, []);
        newReportsMap.get(orderNum)!.push(r);
      });

      const statuses = Array.from(new Set(aggregated.map(r => r[cs]).filter(Boolean))).sort();
      const colorMap: Record<string, typeof COLORS[0]> = {};
      statuses.forEach((s, i) => colorMap[s] = COLORS[i % COLORS.length]);

      let df = "", dt = "";
      if (cd) {
        const dates = aggregated.map(r => parseDate(r[cd] || "")).filter(Boolean) as Date[];
        dates.sort((a, b) => a.getTime() - b.getTime());
        if (dates.length) {
          df = dates[0].toISOString().slice(0, 10);
          dt = dates[dates.length - 1].toISOString().slice(0, 10);
        }
      }

      setHeaders(mainResult.headers);
      setColOrderNum(co);
      setColStatus(cs);
      setColDate(cd);
      setAllRows(aggregated);
      setAllStatuses(statuses);
      setStatusColorMap(colorMap);
      setPdfSet(newPdfSet);
      setReportsMap(newReportsMap);
      setSelectedStatuses(null);
      setDateFrom(df);
      setDateTo(dt);
      setCalFilter("");
      setMsSearch("");

      const now = new Date();
      setLastUpdated(now.toLocaleTimeString("he-IL", { hour: "2-digit", minute: "2-digit" }));
      const rawCount = mainResult.rows.length;
      const rptInfo = reportsResult.rows.length ? ` | דוחות: ${reportsResult.rows.length.toLocaleString("he-IL")}` : "";
      const pdfInfo = newPdfSet.size ? ` | 📁 PDF: ${newPdfSet.size.toLocaleString("he-IL")}` : "";
      setStatsInfo(`${aggregated.length.toLocaleString("he-IL")} קליטות (${rawCount.toLocaleString("he-IL")} שורות גולמיות)${rptInfo}${pdfInfo}`);
    } catch (err: any) {
      setError(err.message === "NETWORK" ? "NETWORK" : err.message);
    } finally {
      setLoading(false);
    }
  }, [loading]);

  useEffect(() => { load(); }, []);

  useEffect(() => {
    const handler = (e: MouseEvent) => {
      if (msRef.current && !msRef.current.contains(e.target as Node)) setMsOpen(false);
    };
    document.addEventListener("mousedown", handler);
    return () => document.removeEventListener("mousedown", handler);
  }, []);

  useEffect(() => {
    const handler = (e: KeyboardEvent) => {
      if (e.key === "Escape") {
        if (reportsModal) setReportsModal(null);
        else if (modal) setModal(null);
      }
    };
    window.addEventListener("keydown", handler);
    return () => window.removeEventListener("keydown", handler);
  }, [modal, reportsModal]);

  const filteredRows = allRows.filter(row => {
    if (selectedStatuses !== null && !selectedStatuses.has(row[colStatus])) return false;
    if (colDate && (dateFrom || dateTo)) {
      const d = parseDate(row[colDate] || "");
      if (d) {
        if (dateFrom && d < new Date(dateFrom)) return false;
        if (dateTo) { const e = new Date(dateTo); e.setHours(23, 59, 59); if (d > e) return false; }
      }
    }
    if (calFilter) {
      const rc = (row[COL_CALS] || "").toLowerCase();
      if (!rc.includes(calFilter.toLowerCase())) return false;
    }
    return true;
  });

  const groups = filteredRows.reduce((acc, r) => {
    const s = r[colStatus] || "(ללא סטטוס)";
    if (!acc[s]) acc[s] = [];
    acc[s].push(r);
    return acc;
  }, {} as Record<string, Row[]>);

  const sortedGroups = Object.entries(groups).sort((a, b) => b[1].length - a[1].length);
  const total = filteredRows.length;

  function getModalRows() {
    if (!modal) return [];
    let rows = [...modal.rows];
    const q = modalSearch.toLowerCase();
    if (q) rows = rows.filter(r => Object.values(r).some(v => v.toLowerCase().includes(q)));
    if (sortCol) {
      rows.sort((a, b) => {
        const va = a[sortCol] || "", vb = b[sortCol] || "";
        const da = parseDate(va), db = parseDate(vb);
        if (da && db) return (da.getTime() - db.getTime()) * sortDir;
        if (da && !db) return -sortDir;
        if (!da && db) return sortDir;
        const na = parseFloat(va), nb = parseFloat(vb);
        if (!isNaN(na) && !isNaN(nb)) return (na - nb) * sortDir;
        return va.localeCompare(vb, "he") * sortDir;
      });
    }
    return rows;
  }

  function getModalCols(): string[] {
    const hasCals = allRows.some(r => r[COL_CALS] !== undefined);
    const available = new Set(headers);
    const cols = DEFAULT_COLS.filter(c => {
      if (c === COL_CALS) return hasCals;
      return available.has(c);
    });
    headers.forEach(h => {
      if (!HIDDEN_COLS.includes(h) && !cols.includes(h)) cols.push(h);
    });
    if (pdfSet.size > 0) cols.push(COL_PDF);
    if (reportsMap.size > 0) cols.push(COL_REPORTS);
    return cols;
  }

  function handleSort(col: string) {
    if (sortCol === col) setSortDir(d => (d === 1 ? -1 : 1));
    else { setSortCol(col); setSortDir(1); }
  }

  function exportCSV() {
    if (!modal) return;
    const esc = (v: string) => `"${(v || "").replace(/"/g, '""')}"`;
    const exportHeaders = [...headers];
    if (allRows.some(r => r[COL_CALS]) && !exportHeaders.includes(COL_CALS)) exportHeaders.push(COL_CALS);
    const displayHeaders = exportHeaders.map(h => h === COL_CALS ? "כיילים" : h);
    const modalRows = getModalRows();
    const csv = [
      displayHeaders.map(esc).join(","),
      ...modalRows.map(r => exportHeaders.map(c => esc(r[c] || "")).join(",")),
    ].join("\r\n");
    const a = document.createElement("a");
    a.href = URL.createObjectURL(new Blob(["\uFEFF" + csv], { type: "text/csv;charset=utf-8" }));
    a.download = `${modal.status}_${new Date().toLocaleDateString("he-IL").replace(/\//g, "-")}.csv`;
    a.click();
  }

  const hasCalsFilter = allRows.some(r => r[COL_CALS]);
  const msFiltered = msSearch ? allStatuses.filter(s => s.toLowerCase().includes(msSearch.toLowerCase())) : allStatuses;

  function getMsTriggerLabel(): string {
    if (selectedStatuses === null) return "— כל הסטטוסים —";
    if (selectedStatuses.size === 0) return "לא נבחר סטטוס";
    if (selectedStatuses.size === 1) return Array.from(selectedStatuses)[0];
    return `${selectedStatuses.size} סטטוסים נבחרו`;
  }

  function toggleStatus(s: string) {
    setSelectedStatuses(prev => {
      if (prev === null) return new Set(allStatuses.filter(x => x !== s));
      const next = new Set(prev);
      if (next.has(s)) {
        next.delete(s);
        if (next.size === allStatuses.length) return null;
        return next;
      } else {
        next.add(s);
        if (next.size === allStatuses.length) return null;
        return next;
      }
    });
  }

  const isStatusChecked = (s: string) => selectedStatuses === null || selectedStatuses.has(s);

  const modalRows = modal ? getModalRows() : [];
  const modalCols = modal ? getModalCols() : [];

  return (
    <DashboardLayout>
      <div className="min-h-screen bg-gray-50" dir="rtl" style={{ fontFamily: "Heebo, sans-serif" }}>

        {/* Header */}
        <div className="bg-white border-b border-gray-200 px-6 py-3 flex items-center justify-between sticky top-0 z-30 shadow-sm">
          <div className="flex items-center gap-3">
            <div className="w-9 h-9 rounded-xl bg-blue-600 flex items-center justify-center">
              <svg viewBox="0 0 24 24" fill="none" stroke="white" strokeWidth="2.2" strokeLinecap="round" className="w-5 h-5">
                <rect x="3" y="3" width="7" height="7" rx="1.5"/><rect x="14" y="3" width="7" height="7" rx="1.5"/>
                <rect x="3" y="14" width="7" height="7" rx="1.5"/><rect x="14" y="14" width="7" height="7" rx="1.5"/>
              </svg>
            </div>
            <div>
              <h1 className="text-lg font-black tracking-tight">דשבורד קליטות</h1>
              <p className="text-xs text-gray-500">חלוקה לפי סטטוסים</p>
            </div>
          </div>
          <div className="flex items-center gap-3">
            <div className="flex items-center gap-1.5 bg-green-50 border border-green-200 text-green-700 rounded-full px-3 py-1 text-xs font-bold">
              <span className="w-1.5 h-1.5 rounded-full bg-green-500 animate-pulse" />
              Live
            </div>
            {lastUpdated && (
              <span className="text-xs text-gray-400">עודכן {lastUpdated} | {statsInfo}</span>
            )}
            <button
              data-testid="btn-refresh-kelitot"
              onClick={load}
              disabled={loading}
              className="flex items-center gap-1.5 px-3 py-1.5 bg-blue-600 text-white rounded-lg text-sm font-semibold hover:bg-blue-700 transition disabled:opacity-60"
            >
              <RefreshCw className={cn("w-3.5 h-3.5", loading && "animate-spin")} />
              רענון
            </button>
          </div>
        </div>

        {/* Filters */}
        {allRows.length > 0 && (
          <div className="bg-white border-b border-gray-200 px-6 py-2.5 flex items-center gap-3 flex-wrap">
            {colDate && (
              <>
                <div className="flex items-center gap-1.5">
                  <span className="text-xs text-gray-500 font-semibold">מ-</span>
                  <DateInput value={dateFrom} onChange={setDateFrom}
                    className="focus-within:border-blue-500" data-testid="kelitot-date-from" />
                </div>
                <div className="flex items-center gap-1.5">
                  <span className="text-xs text-gray-500 font-semibold">עד-</span>
                  <DateInput value={dateTo} onChange={setDateTo}
                    className="focus-within:border-blue-500" data-testid="kelitot-date-to" />
                </div>
                <div className="w-px h-6 bg-gray-200" />
              </>
            )}

            {/* Multi-select status */}
            <div className="flex items-center gap-1.5">
              <span className="text-xs text-gray-500 font-semibold">סטטוס:</span>
              <div className="relative" ref={msRef}>
                <button
                  data-testid="ms-trigger"
                  onClick={() => setMsOpen(o => !o)}
                  className={cn("flex items-center gap-1.5 border rounded-lg px-2.5 py-1.5 min-w-[180px] text-sm bg-white transition",
                    msOpen ? "border-blue-500 shadow-sm" : "border-gray-200 hover:border-gray-300")}
                >
                  <span className="flex-1 text-right truncate">{getMsTriggerLabel()}</span>
                  {selectedStatuses !== null && selectedStatuses.size > 1 && (
                    <span className="bg-blue-600 text-white rounded-full px-1.5 text-xs font-bold">{selectedStatuses.size}</span>
                  )}
                  <ChevronDown className={cn("w-3 h-3 text-gray-400 transition-transform", msOpen && "rotate-180")} />
                </button>

                {msOpen && (
                  <div className="absolute top-full mt-1 right-0 bg-white border border-gray-200 rounded-xl shadow-lg z-50 min-w-[220px] overflow-hidden">
                    <div className="p-2 border-b border-gray-100">
                      <input autoFocus value={msSearch} onChange={e => setMsSearch(e.target.value)}
                        placeholder="חפש סטטוס..."
                        className="w-full px-2.5 py-1.5 bg-gray-50 border border-gray-200 rounded-lg text-sm outline-none focus:border-blue-500" />
                    </div>
                    <div className="flex border-b border-gray-100">
                      <button onClick={() => { setSelectedStatuses(null); setMsOpen(false); }}
                        className="flex-1 py-1.5 text-xs font-semibold text-blue-600 hover:bg-gray-50 border-l border-gray-100">בחר הכל</button>
                      <button onClick={() => setSelectedStatuses(new Set())}
                        className="flex-1 py-1.5 text-xs font-semibold text-blue-600 hover:bg-gray-50">נקה הכל</button>
                    </div>
                    <div className="max-h-52 overflow-y-auto py-1">
                      {msFiltered.map(s => {
                        const col = statusColorMap[s] || COLORS[0];
                        const cnt = allRows.filter(r => r[colStatus] === s).length;
                        const checked = isStatusChecked(s);
                        return (
                          <div key={s} onClick={() => toggleStatus(s)}
                            className={cn("flex items-center gap-2 px-3 py-1.5 cursor-pointer text-sm transition",
                              checked ? "bg-blue-50" : "hover:bg-gray-50")}>
                            <div className={cn("w-4 h-4 rounded border-2 flex items-center justify-center flex-shrink-0 transition",
                              checked ? "bg-blue-600 border-blue-600" : "border-gray-300 bg-white")}>
                              {checked && <svg viewBox="0 0 12 12" fill="none" stroke="white" strokeWidth="2.5" strokeLinecap="round" className="w-2.5 h-2.5"><polyline points="2 6 5 9 10 3"/></svg>}
                            </div>
                            <span className="w-2 h-2 rounded-full flex-shrink-0" style={{ background: col.color }} />
                            <span className="flex-1 truncate">{s}</span>
                            <span className="text-xs text-gray-400 font-semibold">{cnt.toLocaleString("he-IL")}</span>
                          </div>
                        );
                      })}
                    </div>
                  </div>
                )}
              </div>
            </div>

            {hasCalsFilter && (
              <div className="flex items-center gap-1.5">
                <span className="text-xs text-gray-500 font-semibold">כיילן:</span>
                <input value={calFilter} onChange={e => setCalFilter(e.target.value)}
                  placeholder="שם כיילן..."
                  className="border border-gray-200 rounded-lg px-2.5 py-1.5 text-sm outline-none focus:border-blue-500 bg-white min-w-[140px]" />
              </div>
            )}

            <button onClick={() => { setSelectedStatuses(null); setDateFrom(""); setDateTo(""); setCalFilter(""); setMsSearch(""); }}
              className="px-3 py-1.5 text-xs text-gray-500 border border-gray-200 rounded-lg hover:border-red-300 hover:text-red-600 hover:bg-red-50 transition">
              ✕ נקה
            </button>
          </div>
        )}

        {/* Summary bar */}
        {allRows.length > 0 && (
          <div className="bg-gray-50 border-b border-gray-200 px-6 py-2 flex items-center gap-3 text-sm text-gray-500 flex-wrap">
            <span>סה"כ: <strong className="text-gray-800">{total.toLocaleString("he-IL")}</strong></span>
            <span>•</span>
            <span>סטטוסים: <strong className="text-gray-800">{Object.keys(groups).length}</strong></span>
            {(selectedStatuses !== null || calFilter) && (
              <span className="bg-blue-50 border border-blue-200 text-blue-700 rounded px-2 py-0.5 text-xs font-semibold">
                🔍 {selectedStatuses !== null ? `${selectedStatuses.size} סטטוסים` : ""}{calFilter ? ` | כיילן: ${calFilter}` : ""}
              </span>
            )}
          </div>
        )}

        {/* Main content */}
        <div className="p-6">
          {loading && (
            <div className="flex flex-col items-center justify-center min-h-64 gap-4">
              <div className="w-10 h-10 rounded-full border-2 border-gray-200 border-t-blue-600 animate-spin" />
              <p className="text-sm text-gray-500">מתחבר ל-Google Sheets...</p>
              {loadProgress > 0 && <p className="text-sm text-blue-600 font-semibold">נטענו {loadProgress.toLocaleString("he-IL")} שורות...</p>}
            </div>
          )}

          {!loading && error && (
            <div className="max-w-lg mx-auto mt-12 bg-red-50 border border-red-200 rounded-2xl p-8 text-center">
              <div className="text-3xl mb-2">⚠️</div>
              <h3 className="text-red-600 font-bold text-lg mb-2">שגיאה בטעינת נתונים</h3>
              {error === "NETWORK" ? (
                <>
                  <p className="text-gray-600 text-sm mb-4">הדפדפן לא הצליח לגשת ל-Google Sheets.<br />הסיבה הנפוצה: <strong>הגיליון אינו ציבורי</strong>.</p>
                  <div className="text-right flex flex-col gap-2 mb-4">
                    {["פתח את הגיליון ב-Google Sheets","לחץ שיתוף (למעלה מימין)","שנה ל: \"כל מי שיש לו קישור — צופה\"","לחץ רענון"].map((step, i) => (
                      <div key={i} className="flex items-center gap-2 bg-white border border-red-200 rounded-lg px-3 py-2 text-sm">
                        <span className="bg-red-600 text-white rounded-full w-5 h-5 flex items-center justify-center text-xs font-bold flex-shrink-0">{i+1}</span>
                        {step}
                      </div>
                    ))}
                  </div>
                  <div className="flex gap-2 justify-center flex-wrap">
                    <a href={`https://docs.google.com/spreadsheets/d/${SHEET_ID}/gviz/tq?tqx=out:json&tq=select%20*%20limit%201`} target="_blank"
                      className="inline-flex items-center gap-1.5 px-3 py-2 bg-white border border-red-300 text-red-600 rounded-lg text-sm font-semibold">
                      🔍 בדוק גישה לגיליון
                    </a>
                    <button onClick={load} className="flex items-center gap-1.5 px-4 py-2 bg-blue-600 text-white rounded-lg text-sm font-semibold hover:bg-blue-700">
                      <RefreshCw className="w-3.5 h-3.5" /> נסה שוב
                    </button>
                  </div>
                </>
              ) : (
                <>
                  <p className="text-gray-600 text-sm mb-4">{error}</p>
                  <button onClick={load} className="px-4 py-2 bg-blue-600 text-white rounded-lg text-sm font-semibold hover:bg-blue-700">נסה שוב</button>
                </>
              )}
            </div>
          )}

          {!loading && !error && allRows.length > 0 && (
            <>
              {total === 0 ? (
                <div className="text-center py-16 text-gray-400">
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" className="w-10 h-10 mx-auto mb-3 opacity-30"><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/></svg>
                  <p>אין נתונים לפי הסינון הנוכחי</p>
                </div>
              ) : (
                <div className="grid gap-3" style={{ gridTemplateColumns: "repeat(auto-fill, minmax(190px, 1fr))" }}>
                  {sortedGroups.map(([status, rows]) => {
                    const col = statusColorMap[status] || COLORS[0];
                    const pct = ((rows.length / total) * 100).toFixed(1);
                    return (
                      <div key={status} data-testid={`card-status-${status}`}
                        onClick={() => { setSortCol(colDate); setSortDir(1); setModalSearch(""); setModal({ status, rows, color: col }); }}
                        className="relative bg-white border-[1.5px] border-gray-200 rounded-xl p-4 cursor-pointer transition-all hover:-translate-y-1 hover:shadow-lg group overflow-hidden"
                        style={{ borderColor: undefined }}
                      >
                        <div className="absolute top-0 right-0 left-0 h-0.5 rounded-t-xl" style={{ background: col.color }} />
                        <div className="w-9 h-9 rounded-xl flex items-center justify-center mb-3" style={{ background: col.bg }}>
                          <svg viewBox="0 0 24 24" fill="none" stroke={col.color} strokeWidth="2.2" strokeLinecap="round" className="w-4 h-4">
                            <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/>
                          </svg>
                        </div>
                        <p className="text-xs font-semibold text-gray-500 mb-2 truncate" title={status}>{status}</p>
                        <p className="text-4xl font-black leading-none mb-1" style={{ color: col.color }}>{rows.length.toLocaleString("he-IL")}</p>
                        <p className="text-xs text-gray-400">{pct}% מהסה"כ</p>
                        <div className="mt-3 pt-2.5 border-t border-gray-100 flex items-center justify-between text-xs text-gray-400">
                          <span>{rows.length} רשומות</span>
                          <span className="flex items-center gap-1 font-semibold opacity-0 group-hover:opacity-100 transition" style={{ color: col.color }}>
                            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" className="w-3 h-3"><polyline points="15 3 21 3 21 9"/><polyline points="9 21 3 21 3 15"/><line x1="21" y1="3" x2="14" y2="10"/><line x1="3" y1="21" x2="10" y2="14"/></svg>
                            פירוט
                          </span>
                        </div>
                      </div>
                    );
                  })}
                </div>
              )}
            </>
          )}
        </div>

        {/* Orders Modal */}
        {modal && (
          <div className="fixed inset-0 bg-black/40 backdrop-blur-sm z-50 flex items-center justify-center p-4"
            onClick={e => { if (e.target === e.currentTarget) setModal(null); }}>
            <div className="bg-white rounded-2xl w-full max-w-[98vw] max-h-[92vh] flex flex-col shadow-2xl"
              style={{ animation: "modal-in 0.2s ease" }}>
              <div className="flex items-center justify-between px-5 py-4 border-b border-gray-100 flex-shrink-0">
                <div className="flex items-center gap-2.5">
                  <div className="w-1 h-8 rounded-full" style={{ background: modal.color.color }} />
                  <h2 className="font-black text-base">{modal.status}</h2>
                  <span className="bg-gray-100 border border-gray-200 rounded-full px-2.5 py-0.5 text-xs font-bold text-gray-500">
                    {modal.rows.length.toLocaleString("he-IL")} רשומות
                  </span>
                </div>
                <button onClick={() => setModal(null)}
                  className="w-8 h-8 flex items-center justify-center border border-gray-200 rounded-lg text-gray-400 hover:bg-red-50 hover:border-red-200 hover:text-red-500 transition">
                  <X className="w-4 h-4" />
                </button>
              </div>
              <div className="flex items-center gap-2.5 px-5 py-2.5 border-b border-gray-100 flex-shrink-0">
                <div className="relative flex-1">
                  <Search className="absolute right-3 top-1/2 -translate-y-1/2 w-3.5 h-3.5 text-gray-400" />
                  <input autoFocus value={modalSearch} onChange={e => setModalSearch(e.target.value)}
                    placeholder="🔍  חיפוש בתוך הרשימה..."
                    className="w-full pr-9 pl-3 py-1.5 bg-gray-50 border border-gray-200 rounded-lg text-sm outline-none focus:border-blue-500" />
                </div>
                <button onClick={exportCSV}
                  className="flex items-center gap-1.5 px-3 py-1.5 bg-gray-50 border border-gray-200 text-gray-500 rounded-lg text-xs font-semibold hover:bg-blue-50 hover:border-blue-200 hover:text-blue-600 transition">
                  <Download className="w-3 h-3" /> ייצוא CSV
                </button>
              </div>
              <div className="overflow-auto flex-1">
                <table className="w-max min-w-full border-collapse text-sm" dir="rtl">
                  <thead>
                    <tr>
                      {modalCols.map(col => {
                        const isActive = sortCol === col;
                        return (
                          <th key={col} onClick={() => handleSort(col)}
                            className={cn("text-right px-3 py-2 text-xs font-bold text-gray-500 border-b-2 border-gray-100 sticky top-0 bg-white cursor-pointer hover:text-blue-600 hover:bg-blue-50 whitespace-nowrap select-none",
                              isActive && "text-blue-600 bg-blue-50")}>
                            {COL_LABELS[col] || col}
                            <span className="mr-1 opacity-40 text-[10px]">{isActive ? (sortDir === 1 ? "▲" : "▼") : "⇅"}</span>
                          </th>
                        );
                      })}
                    </tr>
                  </thead>
                  <tbody>
                    {modalRows.length === 0 ? (
                      <tr><td colSpan={modalCols.length} className="text-center py-10 text-gray-400">אין תוצאות</td></tr>
                    ) : modalRows.map((row, i) => (
                      <tr key={i} className="hover:bg-gray-50 border-b border-gray-50">
                        {modalCols.map(col => {
                          if (col === colOrderNum) {
                            return (
                              <td key={col} className="px-3 py-2 whitespace-nowrap">
                                <span className="inline-block bg-blue-50 border border-blue-200 text-blue-600 rounded px-2 py-0.5 font-bold text-xs font-mono">
                                  {row[col] || ""}
                                </span>
                              </td>
                            );
                          }
                          if (col === COL_CALS) {
                            const v = row[col] || "";
                            if (!v) return <td key={col} className="px-3 py-2 text-gray-400 text-xs">—</td>;
                            return (
                              <td key={col} className="px-3 py-2 whitespace-nowrap">
                                {v.split(",").map(s => s.trim()).filter(Boolean).map((s, j) => (
                                  <span key={j} className="inline-block bg-green-50 border border-green-200 text-green-700 rounded px-1.5 py-0.5 text-xs font-semibold mx-0.5">{s}</span>
                                ))}
                              </td>
                            );
                          }
                          if (col === COL_PDF) {
                            const orderNum = normalizeOrderNum(row[colOrderNum] || "");
                            const has = pdfSet.has(orderNum);
                            return (
                              <td key={col} className="px-3 py-2 text-center">
                                <span title={has ? "קיים PDF בדיסק" : "אין PDF בדיסק"} style={{ opacity: has ? 1 : 0.2 }} className="text-base">📁</span>
                              </td>
                            );
                          }
                          if (col === COL_REPORTS) {
                            const orderNum = normalizeOrderNum(row[colOrderNum] || "");
                            const reports = reportsMap.get(orderNum);
                            if (reports?.length) {
                              return (
                                <td key={col} className="px-3 py-2 text-center">
                                  <button onClick={e => { e.stopPropagation(); setReportsModal({ orderNum, reports }); }}
                                    title={`${reports.length} דוחות`}
                                    className="text-base hover:scale-125 transition-transform">✅</button>
                                </td>
                              );
                            }
                            return <td key={col} className="px-3 py-2 text-center"><span className="text-base opacity-50">❌</span></td>;
                          }
                          return <td key={col} className="px-3 py-2 whitespace-nowrap text-gray-700">{row[col] || ""}</td>;
                        })}
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
          </div>
        )}

        {/* Reports Sub-Modal */}
        {reportsModal && (
          <div className="fixed inset-0 bg-black/50 backdrop-blur-sm flex items-center justify-center p-4 z-[60]"
            onClick={e => { if (e.target === e.currentTarget) setReportsModal(null); }}>
            <div className="bg-white rounded-2xl w-full max-w-[96vw] max-h-[90vh] flex flex-col shadow-2xl">
              <div className="flex items-center justify-between px-5 py-4 border-b border-gray-100 flex-shrink-0">
                <div className="flex items-center gap-2.5">
                  <div className="w-1 h-8 rounded-full bg-blue-600" />
                  <h2 className="font-black text-base">דוחות קליטה {reportsModal.orderNum}</h2>
                  <span className="bg-gray-100 border border-gray-200 rounded-full px-2.5 py-0.5 text-xs font-bold text-gray-500">
                    {reportsModal.reports.length} דוחות
                  </span>
                </div>
                <button onClick={() => setReportsModal(null)}
                  className="w-8 h-8 flex items-center justify-center border border-gray-200 rounded-lg text-gray-400 hover:bg-red-50 hover:border-red-200 hover:text-red-500 transition">
                  <X className="w-4 h-4" />
                </button>
              </div>
              <div className="overflow-auto flex-1">
                <table className="w-max min-w-full border-collapse text-sm" dir="rtl">
                  <thead>
                    <tr>
                      {["Formatted_CDATE","MBANUM","USERLOGIN","PARTDES","STATCODE","AUTHNAME"].map(c => (
                        <th key={c} className="text-right px-3 py-2 text-xs font-bold text-gray-500 border-b-2 border-gray-100 sticky top-0 bg-white whitespace-nowrap">
                          {{"Formatted_CDATE":"תאריך ושעה","MBANUM":"מס׳ דוח","USERLOGIN":"שם הכייל","PARTDES":"שם הפריט","STATCODE":"סטטוס","AUTHNAME":"חותם שני"}[c] || c}
                        </th>
                      ))}
                    </tr>
                  </thead>
                  <tbody>
                    {reportsModal.reports.map((r, i) => {
                      const code = (r["STATCODE"] || "").trim();
                      const statLabel = STATCODE_MAP[code] || code;
                      const statColor = STATCODE_COLOR[code] || "#6b7280";
                      return (
                        <tr key={i} className="hover:bg-gray-50 border-b border-gray-50">
                          {["Formatted_CDATE","MBANUM","USERLOGIN","PARTDES","STATCODE","AUTHNAME"].map(c => (
                            <td key={c} className="px-3 py-2 whitespace-nowrap text-gray-700">
                              {c === "STATCODE" ? (
                                <span className="inline-block border rounded px-2 py-0.5 text-xs font-bold" style={{background: statColor+"22", color: statColor, borderColor: statColor+"55"}}>
                                  {statLabel}
                                </span>
                              ) : r[c] || "—"}
                            </td>
                          ))}
                        </tr>
                      );
                    })}
                  </tbody>
                </table>
              </div>
            </div>
          </div>
        )}
      </div>

      <style>{`
        @keyframes modal-in {
          from { transform: scale(0.97) translateY(6px); opacity: 0; }
          to   { transform: scale(1) translateY(0); opacity: 1; }
        }
      `}</style>
    </DashboardLayout>
  );
}
