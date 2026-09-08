import { useRef, useState } from "react";
import { FileSpreadsheet, Inbox, Loader2 } from "lucide-react";
import { cn } from "@/lib/utils";
import { useToast } from "@/hooks/use-toast";
import {
  PricingResult,
  UploadProgress,
  UploadResponse,
  getProgress,
  uploadCustomerExcel,
} from "@/api/pricing";
import CustomerSelect from "./CustomerSelect";

interface Props {
  onResults: (results: PricingResult[]) => void;
  customerName: string;
  onCustomerNameChange: (name: string) => void;
}

const PHASE_LABEL: Record<UploadProgress["phase"], string> = {
  idle: "מעבד",
  parsing: "מנתח את הקובץ",
  matching: "מתאים פריטים למחירון",
  ai: "מזהה פריטים דרך AI",
  done: "סיום",
};

/** תגית מידע קטנה בשורת הסיכום שאחרי העלאה */
function InfoTag({ children, tone = "gray" }: { children: React.ReactNode; tone?: "gray" | "indigo" | "green" | "amber" | "purple" }) {
  return (
    <span
      className={cn(
        "px-2 py-0.5 rounded-md border text-xs font-semibold whitespace-nowrap",
        tone === "indigo" && "bg-indigo-50 border-indigo-200 text-indigo-700",
        tone === "green" && "bg-emerald-50 border-emerald-200 text-emerald-700",
        tone === "amber" && "bg-amber-50 border-amber-200 text-amber-700",
        tone === "purple" && "bg-purple-50 border-purple-200 text-purple-700",
        tone === "gray" && "bg-gray-50 border-gray-200 text-gray-600",
      )}
    >
      {children}
    </span>
  );
}

export default function ExcelUpload({ onResults, customerName, onCustomerNameChange }: Props) {
  const { toast } = useToast();
  const [loading, setLoading] = useState(false);
  const [dragOver, setDragOver] = useState(false);
  const [lastInfo, setLastInfo] = useState<UploadResponse | null>(null);
  const [fileName, setFileName] = useState<string | null>(null);
  const [errorDetail, setErrorDetail] = useState<string | null>(null);
  const [progress, setProgress] = useState<UploadProgress | null>(null);
  const inputRef = useRef<HTMLInputElement>(null);
  const pollRef = useRef<number | null>(null);

  // Polling להתקדמות: השרת מחזיק שלב + מונה, והמסך שואל אותו כל 500ms.
  // בלי זה קובץ של אלפי שורות נראה תקוע במשך דקות.
  const startProgressPolling = () => {
    stopProgressPolling();
    const tick = async () => {
      try {
        setProgress(await getProgress());
      } catch {
        // כשל ב-polling אינו קריטי - ההעלאה עצמה ממשיכה
      }
    };
    tick();
    pollRef.current = window.setInterval(tick, 500);
  };
  const stopProgressPolling = () => {
    if (pollRef.current !== null) {
      window.clearInterval(pollRef.current);
      pollRef.current = null;
    }
  };

  const handleUpload = async (file: File) => {
    setLoading(true);
    setFileName(file.name);
    setErrorDetail(null);
    setLastInfo(null);
    setProgress(null);
    onResults([]); // ניקוי תוצאות קודמות - שלא יוצג מידע ישן לצד "מעבד..."
    startProgressPolling();
    try {
      const res = await uploadCustomerExcel(file, customerName.trim() || undefined);
      setLastInfo(res);
      onResults(res.results);
      const matched = res.results.filter(r => r.matched).length;
      if (res.results.length === 0) {
        toast({ title: "לא זוהו פריטים בקובץ", variant: "destructive" });
      } else {
        toast({
          title: `נטענו ${res.results.length} פריטים`,
          description: `${matched} תומחרו בהצלחה`,
        });
      }
    } catch (e: any) {
      const msg = e?.message || "שגיאה בקריאת הקובץ";
      toast({ title: "שגיאה בקריאת הקובץ", description: msg, variant: "destructive" });
      setErrorDetail(msg);
      setLastInfo(null);
      onResults([]);
    } finally {
      stopProgressPolling();
      setProgress(null);
      setLoading(false);
      if (inputRef.current) inputRef.current.value = "";
    }
  };

  const cols = lastInfo?.detectedColumns;

  return (
    <div className="bg-white border border-gray-200 rounded-2xl p-5">
      <h2 className="flex items-center gap-2 text-base font-black tracking-tight">
        <FileSpreadsheet className="w-4 h-4 text-emerald-600" />
        העלאת קובץ אקסל של הלקוח
      </h2>
      <p className="text-xs text-gray-500 mt-1">
        הקובץ יזוהה אוטומטית. נדרשת לפחות עמודת תיאור או מק״ט. ניתן לכלול גם עמודת כמות.
      </p>

      <div className="mt-4">
        <CustomerSelect value={customerName} onChange={onCustomerNameChange} disabled={loading} />
        <p className="text-xs text-gray-400 mt-1.5 max-w-2xl">
          כשנבחר לקוח, ההתאמות שנלמדו ישמשו אך ורק מאותו לקוח — התאמות של לקוחות אחרים לא ישפיעו.
          פריט שלא נלמד ממנו יעבור למאצ׳ר הרגיל.
        </p>
      </div>

      <input
        ref={inputRef}
        type="file"
        accept=".xlsx,.xls,.csv"
        className="hidden"
        onChange={e => {
          const f = e.target.files?.[0];
          if (f) handleUpload(f);
        }}
      />

      <div
        onClick={() => !loading && inputRef.current?.click()}
        onDragOver={e => { e.preventDefault(); if (!loading) setDragOver(true); }}
        onDragLeave={() => setDragOver(false)}
        onDrop={e => {
          e.preventDefault();
          setDragOver(false);
          const f = e.dataTransfer.files?.[0];
          if (f && !loading) handleUpload(f);
        }}
        data-testid="pricing-dropzone"
        className={cn(
          "mt-4 border-2 border-dashed rounded-xl py-8 px-4 text-center transition select-none",
          loading ? "opacity-60 cursor-wait" : "cursor-pointer",
          dragOver ? "border-indigo-500 bg-indigo-50" : "border-gray-200 hover:border-indigo-300 hover:bg-gray-50",
        )}
      >
        <Inbox className={cn("w-8 h-8 mx-auto mb-2", dragOver ? "text-indigo-600" : "text-gray-400")} />
        <p className="text-sm font-semibold text-gray-700">גרור קובץ אקסל לכאן, או לחץ לבחירה</p>
        <p className="text-xs text-gray-400 mt-0.5">תומך בפורמטים: .xlsx, .xls, .csv</p>
      </div>

      {fileName && (
        <p className="text-xs text-gray-500 mt-3">
          קובץ אחרון: <span className="font-mono bg-gray-100 rounded px-1.5 py-0.5">{fileName}</span>
        </p>
      )}

      {loading && (
        <div className="mt-3 bg-indigo-50 border border-indigo-200 rounded-xl p-3">
          <div className="flex items-center gap-2 text-sm font-semibold text-indigo-800">
            <Loader2 className="w-4 h-4 animate-spin" />
            {progress && progress.phase !== "idle" ? PHASE_LABEL[progress.phase] : "מעבד את הקובץ..."}
            {progress && progress.total > 0 && (
              <span className="text-indigo-600 font-black">
                {progress.done} / {progress.total} פריטים
              </span>
            )}
          </div>
          {progress && progress.total > 0 && (
            <div className="mt-2 h-1.5 w-full bg-indigo-100 rounded-full overflow-hidden">
              <div
                className={cn("h-full rounded-full transition-all", progress.phase === "ai" ? "bg-purple-500" : "bg-indigo-600")}
                style={{ width: `${Math.round((progress.done / progress.total) * 100)}%` }}
              />
            </div>
          )}
        </div>
      )}

      {lastInfo && (
        <div className="mt-3 bg-blue-50 border border-blue-200 rounded-xl p-3 flex flex-wrap items-center gap-2">
          <span className="text-sm font-bold text-blue-900">זוהו {lastInfo.totalRows} שורות נתונים</span>
          {lastInfo.customerName
            ? <InfoTag tone="indigo">לקוח: {lastInfo.customerName}</InfoTag>
            : <InfoTag>ללא לקוח (מאגר כללי)</InfoTag>}
          {!!lastInfo.registeredDevices && (
            <InfoTag tone="green">{lastInfo.registeredDevices} מכשירים רשומים ללקוח בפריוריטי</InfoTag>
          )}
          {lastInfo.skippedRows > 0 && <InfoTag tone="amber">{lastInfo.skippedRows} שורות ריקות דולגו</InfoTag>}
          {lastInfo.headerRowIndex !== undefined && lastInfo.headerRowIndex > 0 && (
            <InfoTag>כותרות בשורה {lastInfo.headerRowIndex + 1}</InfoTag>
          )}
          {cols?.description && <InfoTag tone="indigo">תיאור: {cols.description}</InfoTag>}
          {cols?.partNumber && <InfoTag tone="indigo">מק״ט: {cols.partNumber}</InfoTag>}
          {cols?.quantity && <InfoTag tone="indigo">כמות: {cols.quantity}</InfoTag>}
          {cols?.serial && <InfoTag tone="green">מס׳ סידורי (התאמה למכשיר רשום): {cols.serial}</InfoTag>}
          {cols?.manufacturer && <InfoTag tone="purple">יצרן: {cols.manufacturer}</InfoTag>}
          {cols?.model && <InfoTag tone="purple">דגם: {cols.model}</InfoTag>}
          {cols?.attributes && <InfoTag tone="purple">מאפיינים: {cols.attributes}</InfoTag>}
          {!!lastInfo.sectionHeaderRows && (
            <InfoTag tone="amber">{lastInfo.sectionHeaderRows} שורות כותרת דולגו</InfoTag>
          )}
          {!!lastInfo.hiddenRows && (
            <InfoTag tone="amber">{lastInfo.hiddenRows} שורות מוסתרות בגיליון דולגו</InfoTag>
          )}
        </div>
      )}

      {errorDetail && (
        <div className="mt-3 bg-red-50 border border-red-200 rounded-xl p-3">
          <p className="text-sm font-bold text-red-700">לא הצלחתי לקרוא את הקובץ</p>
          <p className="text-xs text-red-600 mt-1">{errorDetail}</p>
        </div>
      )}
    </div>
  );
}
