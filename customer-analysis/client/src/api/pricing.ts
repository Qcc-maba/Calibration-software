/**
 * קליינט ה-API של מסך התמחור.
 *
 * הגיע ממערכת נפרדת שדיברה עם שרת משלה על :4000 דרך axios. כאן הכל עובר
 * לאותו שרת של הדשבורד תחת התחילית /api/pricing, ו-fetch מספיק — axios לא
 * נמצא בקליינט הזה ואין סיבה להוסיף אותו בשביל שכבה דקה כזו.
 */

const BASE = '/api/pricing';

export interface PriceListItem {
  partNumber: string;
  description: string;
  manufacturer?: string;
  model?: string;
  category?: string;
  price?: number;
  currency?: string;
  unit?: string;
  notes?: string;
}

export interface CustomerProductInput {
  customerDescription: string;
  customerPartNumber?: string;
  customerName?: string;
  customerContext?: string;   // יצרן / דגם / מאפיינים מהקובץ
  customerSerial?: string;    // מספר סידורי - תצוגה בלבד
  quantity?: number;
}

export interface PricingResult {
  input: CustomerProductInput;
  matched: PriceListItem | null;
  matchType: 'exact' | 'close' | 'weak' | 'none';
  matchScore: number;
  matchSource?: 'serial' | 'override' | 'partNumber' | 'description' | 'history' | 'fuzzy';
  matchNote?: string;
  mbaNumber?: string;        // מספר מ.ב.א. של הכיול האחרון
  lastChargedPart?: string;
  alternatives: Array<{ item: PriceListItem; score: number }>;
}

export interface SourceStatus {
  excelLoaded: boolean;
  priorityConnected: boolean;
  itemsInIndex: number;
  modelsInIndex?: number;
}

export interface UploadProgress {
  phase: 'idle' | 'parsing' | 'matching' | 'ai' | 'done';
  done: number;
  total: number;
  startedAt: number;
}

export interface CustomerRef {
  name: string;               // השם כפי שהוא בפריוריטי - זה גם מפתח הלמידה
  display?: string;           // אותו שם קריא, לשמות לטיניים ששמורים הפוך
  overrides: number;          // כמה התאמות נלמדו מהלקוח הזה
  source?: 'local' | 'priority';
  code?: string;              // קוד הלקוח בפריוריטי
}

export interface UploadResponse {
  customerName?: string | null;
  registeredDevices?: number;   // מכשירים של הלקוח שכבר רשומים בפריוריטי
  detectedColumns: {
    description: string | null;
    partNumber: string | null;
    serial?: string | null;
    quantity: string | null;
    manufacturer?: string | null;
    model?: string | null;
    attributes?: string | null;
  };
  totalRows: number;
  skippedRows: number;
  sectionHeaderRows?: number;
  hiddenRows?: number;
  results: PricingResult[];
  allHeaders?: string[];
  headerRowIndex?: number;
  sheetName?: string;
  preview?: string[][];
}

export interface LearningImportResult {
  ok: boolean;
  learned: number;
  customerName?: string | null;
  totalOverrides: number;
  detectedColumns: { description: string; partNumber: string };
  totalRows: number;
  skippedRows: number;
  invalidPartNumbers: number;
  notInPricelist: number;
  sampleLearned: Array<{ description: string; partNumber: string }>;
}

/**
 * השרת מחזיר שגיאות כ-{ error }. בלי החילוץ הזה המשתמש מקבל "500" סתמי במקום
 * ההסבר בעברית שהשרת דווקא טרח להחזיר (למשל "הקובץ גדול מהמותר").
 */
async function request<T>(path: string, init?: RequestInit): Promise<T> {
  const res = await fetch(`${BASE}${path}`, init);
  if (!res.ok) {
    const body = await res.json().catch(() => null);
    throw new Error(body?.error || body?.message || `שגיאת שרת (${res.status})`);
  }
  return res.json() as Promise<T>;
}

function postJson<T>(path: string, body: unknown, method = 'POST'): Promise<T> {
  return request<T>(path, {
    method,
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
}

export function getStatus(): Promise<SourceStatus> {
  return request<SourceStatus>('/source-status');
}

export function getProgress(): Promise<UploadProgress> {
  return request<UploadProgress>('/progress');
}

/**
 * שומר override (בחירה ידנית של מק"ט עבור תיאור לקוח), ואם rematch מועבר -
 * מחזיר את התוצאה המעודכנת כדי שהפרונט יוכל לעדכן את השורה מיד.
 */
export function setOverride(
  customerDescription: string,
  partNumber: string,
  rematch?: CustomerProductInput,
  customerName?: string,
  customerContext?: string,
): Promise<{ ok: boolean; result?: PricingResult }> {
  return postJson('/override', { customerDescription, partNumber, rematch, customerName, customerContext });
}

export async function removeOverride(
  customerDescription: string,
  customerName?: string,
  customerContext?: string,
): Promise<void> {
  await postJson('/override', { customerDescription, customerName, customerContext }, 'DELETE');
}

/** רשימת לקוחות להשלמה אוטומטית: מקומיים (שנלמדו) + רשימת הלקוחות מפריוריטי */
export async function listCustomers(q?: string, limit = 20): Promise<CustomerRef[]> {
  const params = new URLSearchParams({ limit: String(limit) });
  if (q) params.set('q', q);
  const data = await request<{ customers: CustomerRef[] }>(`/customers?${params}`);
  return data.customers;
}

/** רישום שם לקוח חדש כדי שיופיע בהשלמה בפעם הבאה */
export async function registerCustomer(name: string): Promise<void> {
  await postJson('/customers', { name });
}

export async function lookupPartNumber(partNumber: string): Promise<PriceListItem | null> {
  try {
    const data = await request<{ item: PriceListItem }>(`/item/${encodeURIComponent(partNumber)}`);
    return data.item;
  } catch {
    return null;
  }
}

// השלמה אוטומטית מתוך המחירון (לא Priority)
export async function suggestItems(q: string, limit = 10): Promise<PriceListItem[]> {
  if (!q || q.trim().length < 1) return [];
  const params = new URLSearchParams({ q, limit: String(limit) });
  const data = await request<{ items: PriceListItem[] }>(`/suggest?${params}`);
  return data.items;
}

export function refreshData(): Promise<{ source: string; count: number; models: number }> {
  return postJson('/refresh', {});
}

export async function priceBatch(items: CustomerProductInput[], customerName?: string): Promise<PricingResult[]> {
  const data = await postJson<{ results: PricingResult[] }>('/price/batch', { items, customerName });
  return data.results;
}

export function uploadCustomerExcel(file: File, customerName?: string): Promise<UploadResponse> {
  const form = new FormData();
  form.append('file', file);
  if (customerName) form.append('customerName', customerName);
  return request<UploadResponse>('/upload', { method: 'POST', body: form });
}

export function importLearning(file: File, customerName?: string): Promise<LearningImportResult> {
  const form = new FormData();
  form.append('file', file);
  if (customerName) form.append('customerName', customerName);
  return request<LearningImportResult>('/learn', { method: 'POST', body: form });
}

export function uploadPriceList(file: File): Promise<{ count: number; originalName: string }> {
  const form = new FormData();
  form.append('file', file);
  return request('/upload-pricelist', { method: 'POST', body: form });
}
