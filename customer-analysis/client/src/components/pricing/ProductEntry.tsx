import { useState } from "react";
import { Calculator, Plus, Trash2 } from "lucide-react";
import { useToast } from "@/hooks/use-toast";
import { CustomerProductInput } from "@/api/pricing";
import CustomerSelect from "./CustomerSelect";

interface Props {
  onSubmit: (items: CustomerProductInput[]) => void;
  loading: boolean;
  customerName: string;
  onCustomerNameChange: (name: string) => void;
}

interface Row extends CustomerProductInput {
  key: number;
}

let nextKey = 1;

const emptyRow = (): Row => ({
  key: nextKey++,
  customerDescription: "",
  customerPartNumber: "",
  customerContext: "",
  quantity: 1,
});

const FIELD =
  "w-full px-2.5 py-1.5 border border-gray-200 rounded-lg text-sm outline-none focus:border-indigo-500 bg-white";

export default function ProductEntry({ onSubmit, loading, customerName, onCustomerNameChange }: Props) {
  const { toast } = useToast();
  const [rows, setRows] = useState<Row[]>([emptyRow()]);

  const addRow = () => setRows(rs => [...rs, emptyRow()]);

  const removeRow = (key: number) =>
    setRows(rs => (rs.length === 1 ? rs : rs.filter(r => r.key !== key)));

  const updateRow = (key: number, patch: Partial<Row>) =>
    setRows(rs => rs.map(r => (r.key === key ? { ...r, ...patch } : r)));

  const handleSubmit = () => {
    const valid = rows
      .map(({ key, ...rest }) => rest)
      .filter(r => r.customerDescription.trim().length > 0);
    if (valid.length === 0) {
      toast({ title: "יש להזין לפחות מוצר אחד עם תיאור", variant: "destructive" });
      return;
    }
    onSubmit(valid);
  };

  return (
    <div className="bg-white border border-gray-200 rounded-2xl p-5">
      <h2 className="text-base font-black tracking-tight">הזנת מוצרי הלקוח</h2>

      <div className="mt-4">
        <CustomerSelect value={customerName} onChange={onCustomerNameChange} disabled={loading} />
      </div>

      <div className="mt-4 space-y-2">
        {rows.map((row, idx) => (
          <div key={row.key} className="flex items-end gap-2">
            <div className="flex-[3] min-w-0">
              {idx === 0 && <label className="block text-xs font-semibold text-gray-500 mb-1">תיאור המוצר</label>}
              <input
                className={FIELD}
                placeholder="למשל: מד טמפרטורה דיגיטלי Fluke 87V"
                value={row.customerDescription}
                onChange={e => updateRow(row.key, { customerDescription: e.target.value })}
                onKeyDown={e => { if (e.key === "Enter") handleSubmit(); }}
                data-testid={`pricing-desc-${idx}`}
              />
            </div>
            <div className="flex-[1.4] min-w-0">
              {idx === 0 && <label className="block text-xs font-semibold text-gray-500 mb-1">יצרן / דגם (אופציונלי)</label>}
              <input
                className={FIELD}
                placeholder="למשל: Fluke 87V"
                value={row.customerContext}
                onChange={e => updateRow(row.key, { customerContext: e.target.value })}
              />
            </div>
            <div className="flex-[1.2] min-w-0">
              {idx === 0 && <label className="block text-xs font-semibold text-gray-500 mb-1">מק״ט לקוח (אופציונלי)</label>}
              <input
                className={FIELD}
                placeholder="המק״ט שלך"
                value={row.customerPartNumber}
                onChange={e => updateRow(row.key, { customerPartNumber: e.target.value })}
              />
            </div>
            <div className="w-20 shrink-0">
              {idx === 0 && <label className="block text-xs font-semibold text-gray-500 mb-1">כמות</label>}
              <input
                type="number"
                min={1}
                className={FIELD}
                value={row.quantity ?? 1}
                onChange={e => updateRow(row.key, { quantity: parseInt(e.target.value, 10) || 1 })}
              />
            </div>
            <button
              type="button"
              onClick={() => removeRow(row.key)}
              disabled={rows.length === 1}
              title="הסר שורה"
              className="shrink-0 p-2 border border-gray-200 rounded-lg text-red-500 hover:bg-red-50 hover:border-red-200 disabled:opacity-30 disabled:hover:bg-transparent transition"
            >
              <Trash2 className="w-4 h-4" />
            </button>
          </div>
        ))}
      </div>

      <div className="flex items-center gap-2 mt-4">
        <button
          type="button"
          onClick={addRow}
          className="flex items-center gap-1.5 px-3 py-1.5 border border-gray-200 rounded-lg text-sm font-semibold text-gray-600 hover:bg-gray-50 transition"
        >
          <Plus className="w-3.5 h-3.5" /> הוסף שורה
        </button>
        <button
          type="button"
          onClick={handleSubmit}
          disabled={loading}
          data-testid="pricing-submit"
          className="flex items-center gap-1.5 px-4 py-1.5 bg-indigo-600 text-white rounded-lg text-sm font-semibold hover:bg-indigo-700 disabled:opacity-60 transition"
        >
          <Calculator className="w-3.5 h-3.5" /> {loading ? "מתמחר..." : "תמחר עכשיו"}
        </button>
      </div>
    </div>
  );
}
