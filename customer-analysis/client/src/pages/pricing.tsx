import { useEffect, useRef, useState } from "react";
import { BadgeCheck, Calculator, CloudUpload, Database, FileSpreadsheet, Lightbulb, RefreshCw, Upload, User } from "lucide-react";
import DashboardLayout from "@/components/layout/DashboardLayout";
import { cn } from "@/lib/utils";
import { useToast } from "@/hooks/use-toast";
import ExcelUpload from "@/components/pricing/ExcelUpload";
import ProductEntry from "@/components/pricing/ProductEntry";
import ResultsTable from "@/components/pricing/ResultsTable";
import {
  CustomerProductInput,
  PricingResult,
  SourceStatus,
  getStatus,
  importLearning,
  priceBatch,
  refreshData,
  uploadPriceList,
} from "@/api/pricing";

type Tab = "upload" | "manual";

/**
 * מסך תמחור המוצרים: מקבל את רשימת המוצרים של הלקוח (קובץ אקסל או הזנה ידנית)
 * ומחזיר את מק"ט מ.ב.א. המתאים עם המחיר. מה שהמשתמש מתקן ידנית נשמר בשרת
 * ומשפיע על הקבצים הבאים - ולכן מסך אחד, לא כלי חד-פעמי.
 */
export default function PricingPage() {
  const { toast } = useToast();
  const [tab, setTab] = useState<Tab>("upload");
  const [status, setStatus] = useState<SourceStatus | null>(null);
  // הלקוח הנבחר מסנן את ההתאמות הנלמדות, ומשמש גם להעלאה, לתיקון ידני וללמידה
  const [customerName, setCustomerName] = useState("");
  const [results, setResults] = useState<PricingResult[]>([]);
  const [loading, setLoading] = useState(false);
  const [refreshing, setRefreshing] = useState(false);
  const [uploadingPricelist, setUploadingPricelist] = useState(false);
  const [importingLearning, setImportingLearning] = useState(false);
  const pricelistInputRef = useRef<HTMLInputElement>(null);
  const learningInputRef = useRef<HTMLInputElement>(null);

  const loadStatus = async () => {
    try {
      setStatus(await getStatus());
    } catch {
      toast({ title: "שגיאה בטעינת סטטוס השרת", variant: "destructive" });
    }
  };

  useEffect(() => {
    loadStatus();
    const onFocus = () => loadStatus();
    window.addEventListener("focus", onFocus);
    return () => window.removeEventListener("focus", onFocus);
  }, []);

  const handlePricelistUpload = async (file: File) => {
    setUploadingPricelist(true);
    try {
      const res = await uploadPriceList(file);
      toast({ title: "המחירון עודכן", description: `${res.count} פריטים מהקובץ ${res.originalName}` });
      await loadStatus();
    } catch (e: any) {
      toast({ title: "שגיאה בהעלאת המחירון", description: e?.message, variant: "destructive" });
    } finally {
      setUploadingPricelist(false);
      if (pricelistInputRef.current) pricelistInputRef.current.value = "";
    }
  };

  const handleLearningImport = async (file: File) => {
    setImportingLearning(true);
    try {
      const res = await importLearning(file, customerName.trim() || undefined);
      toast({
        title: `נלמדו ${res.learned} התאמות ${res.customerName ? `עבור "${res.customerName}"` : "(מאגר כללי)"}`,
        description:
          `סה"כ ${res.totalOverrides} שמורות. זוהו: תיאור="${res.detectedColumns.description}", ` +
          `מק"ט="${res.detectedColumns.partNumber}"` +
          (res.notInPricelist ? `. ${res.notInPricelist} מק"טים לא נמצאו במחירון` : ""),
      });
    } catch (e: any) {
      toast({ title: "שגיאה בייבוא קובץ הלמידה", description: e?.message, variant: "destructive" });
    } finally {
      setImportingLearning(false);
      if (learningInputRef.current) learningInputRef.current.value = "";
    }
  };

  const handleRefresh = async () => {
    setRefreshing(true);
    try {
      const res = await refreshData();
      toast({
        title: "הנתונים רועננו",
        description: `נטענו ${res.count} פריטים ממקור: ${res.source === "priority" ? "פריוריטי" : "אקסל"}`,
      });
      await loadStatus();
    } catch (e: any) {
      toast({ title: "שגיאה ברענון הנתונים", description: e?.message, variant: "destructive" });
    } finally {
      setRefreshing(false);
    }
  };

  const handlePrice = async (items: CustomerProductInput[]) => {
    setLoading(true);
    try {
      const res = await priceBatch(items, customerName.trim() || undefined);
      setResults(res);
      toast({
        title: `תומחרו ${res.filter(r => r.matched).length} מתוך ${res.length} מוצרים`,
      });
    } catch (e: any) {
      toast({ title: "שגיאה בתמחור", description: e?.message, variant: "destructive" });
    } finally {
      setLoading(false);
    }
  };

  const TOOLBAR_BTN =
    "flex items-center gap-1.5 px-3 py-1.5 border border-gray-200 bg-white text-gray-600 rounded-lg text-sm font-semibold hover:bg-gray-50 disabled:opacity-40 transition whitespace-nowrap";

  return (
    <DashboardLayout>
      <div className="min-h-screen bg-gray-50 -m-6 md:-m-8" dir="rtl" style={{ fontFamily: "Heebo, sans-serif" }}>
        {/* Header. לא sticky בכוונה: ה-<main> של הדשבורד הוא scroll container עם
            padding, וכותרת דביקה בתוכו נדחפת מטה ומכסה את שורת הלשוניות. */}
        <div className="bg-white border-b border-gray-200 px-6 py-3 flex items-center justify-between gap-3 flex-wrap shadow-sm">
          <div className="flex items-center gap-3">
            <div className="w-9 h-9 rounded-xl bg-indigo-600 flex items-center justify-center">
              <Calculator className="w-5 h-5 text-white" />
            </div>
            <div>
              <h1 className="text-lg font-black tracking-tight">תמחור מוצרים</h1>
              <p className="text-xs text-gray-500">מק״ט ומחיר מ.ב.א. הזורע לרשימת המוצרים של הלקוח</p>
            </div>
          </div>

          <div className="flex items-center gap-2 flex-wrap">
            {status === null ? (
              <div className="w-4 h-4 rounded-full border-2 border-gray-200 border-t-indigo-600 animate-spin" />
            ) : (
              <>
                <span
                  data-testid="pricing-priority-status"
                  className={cn(
                    "flex items-center gap-1 px-2 py-1 rounded-lg border text-xs font-semibold",
                    status.priorityConnected
                      ? "bg-emerald-50 border-emerald-200 text-emerald-700"
                      : "bg-gray-50 border-gray-200 text-gray-500",
                  )}
                >
                  <Database className="w-3.5 h-3.5" />
                  פריוריטי {status.priorityConnected ? "מחובר" : "לא זמין"}
                </span>
                <span
                  className={cn(
                    "flex items-center gap-1 px-2 py-1 rounded-lg border text-xs font-semibold",
                    status.excelLoaded
                      ? "bg-emerald-50 border-emerald-200 text-emerald-700"
                      : "bg-gray-50 border-gray-200 text-gray-500",
                  )}
                >
                  <FileSpreadsheet className="w-3.5 h-3.5" />
                  מחירון {status.excelLoaded ? `(${status.itemsInIndex} פריטים)` : "לא נטען"}
                </span>
                {customerName.trim() && (
                  <span className="flex items-center gap-1 px-2 py-1 rounded-lg border bg-indigo-50 border-indigo-200 text-indigo-700 text-xs font-semibold">
                    <User className="w-3.5 h-3.5" /> לקוח: {customerName.trim()}
                  </span>
                )}
              </>
            )}

            <input
              ref={pricelistInputRef}
              type="file"
              accept=".xlsx,.xls,.csv"
              className="hidden"
              onChange={e => {
                const f = e.target.files?.[0];
                if (f) handlePricelistUpload(f);
              }}
            />
            <button className={TOOLBAR_BTN} disabled={uploadingPricelist} onClick={() => pricelistInputRef.current?.click()}>
              <CloudUpload className={cn("w-3.5 h-3.5", uploadingPricelist && "animate-pulse")} /> העלאת מחירון
            </button>

            <input
              ref={learningInputRef}
              type="file"
              accept=".xlsx,.xls,.csv"
              className="hidden"
              onChange={e => {
                const f = e.target.files?.[0];
                if (f) handleLearningImport(f);
              }}
            />
            <button
              className={TOOLBAR_BTN}
              disabled={importingLearning}
              onClick={() => learningInputRef.current?.click()}
              title={
                customerName.trim()
                  ? `ההתאמות ייקלטו עבור "${customerName.trim()}" בלבד`
                  : "לא נבחר לקוח — ההתאמות ייקלטו למאגר הכללי"
              }
            >
              <Lightbulb className={cn("w-3.5 h-3.5", importingLearning && "animate-pulse")} /> ייבוא קובץ למידה
            </button>

            <button className={TOOLBAR_BTN} disabled={refreshing} onClick={handleRefresh}>
              <RefreshCw className={cn("w-3.5 h-3.5", refreshing && "animate-spin")} /> רענון נתונים
            </button>
          </div>
        </div>

        <div className="px-6 py-4 space-y-4">
          {/* Tabs */}
          <div className="flex items-center gap-1 border-b border-gray-200">
            {([
              { key: "upload", label: "העלאת קובץ אקסל", icon: Upload },
              { key: "manual", label: "הזנה ידנית", icon: BadgeCheck },
            ] as const).map(t => (
              <button
                key={t.key}
                onClick={() => setTab(t.key)}
                data-testid={`pricing-tab-${t.key}`}
                className={cn(
                  "flex items-center gap-1.5 px-4 py-2 text-sm font-semibold border-b-2 -mb-px transition",
                  tab === t.key
                    ? "border-indigo-600 text-indigo-700"
                    : "border-transparent text-gray-500 hover:text-gray-700",
                )}
              >
                <t.icon className="w-4 h-4" /> {t.label}
              </button>
            ))}
          </div>

          {tab === "upload" ? (
            <ExcelUpload
              onResults={r => { setResults(r); loadStatus(); }}
              customerName={customerName}
              onCustomerNameChange={setCustomerName}
            />
          ) : (
            <ProductEntry
              onSubmit={handlePrice}
              loading={loading}
              customerName={customerName}
              onCustomerNameChange={setCustomerName}
            />
          )}

          <ResultsTable results={results} customerName={customerName.trim() || undefined} />
        </div>
      </div>
    </DashboardLayout>
  );
}
