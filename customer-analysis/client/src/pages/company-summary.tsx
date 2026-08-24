import React from 'react';
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { ScrollArea } from "@/components/ui/scroll-area";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Badge } from "@/components/ui/badge";
import { Dialog, DialogContent, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Tooltip, TooltipContent, TooltipProvider, TooltipTrigger } from "@/components/ui/tooltip";
import DashboardLayout from "@/components/layout/DashboardLayout";
import { 
  Building2, 
  TrendingUp, 
  TrendingDown,
  Package, 
  Clock,
  FileText,
  Loader2,
  DollarSign,
  Users,
  AlertTriangle,
  ArrowLeft,
  ReceiptText,
  Info,
  RefreshCw,
  Copy,
  Check,
  Terminal,
  Download
} from "lucide-react";
import { 
  Bar,
  BarChart,
  XAxis, 
  YAxis, 
  CartesianGrid, 
  Tooltip as RechartsTooltip, 
  ResponsiveContainer,
  PieChart,
  Pie,
  Cell,
  ComposedChart,
  Line,
  ReferenceLine,
  Legend
} from 'recharts';
import { motion } from "framer-motion";
import { useState, useMemo, useRef, useEffect, useCallback } from "react";
import { isSameDay, startOfMonth, endOfMonth, eachDayOfInterval, isWeekend } from 'date-fns';
import html2canvas from 'html2canvas';
import { jsPDF } from 'jspdf';

interface CustomerSummary {
  id: string;
  hp: string;
  companyName: string;
  agentName?: string;
  totalRevenue?: number;
  deviceInventory: {
    totalDevices: number;
    activeDevices: number;
    outForCalibration: number;
  };
  pendingForecast?: {
    totalDocuments: number;
    totalValue: number;
  };
  customerScore?: {
    grade: string;
    score: number;
  };
  alerts?: any[];
  monthlyRevenue?: { month: string; revenue: number; count: number }[];
  financials?: { year: number; revenue: number; invoicesCount: number }[];
}

interface YearlyFinancial {
  year: number;
  revenue: number;
  invoicesCount: number;
  quotesCount: number;
  quotesRevenue: number;
  ordersCount: number;
  ordersRevenue: number;
  returnsRevenue: number;
  returnsCount: number;
}

interface CompanySummaryData {
  customers: CustomerSummary[];
  count: number;
  yearlyFinancials?: YearlyFinancial[];
}

interface CompanyReturnsData {
  months: {
    name: string;
    key: string;
    documents: { customerName: string; customerHp: string; customerId: string; docNumber: string; openDate: string; totalPrice: number }[];
    totalCount: number;
    totalRevenue: number;
  }[];
  currentMonth: {
    name: string;
    key: string;
    documents: { customerName: string; customerHp: string; customerId: string; docNumber: string; openDate: string; totalPrice: number }[];
    totalCount: number;
    totalRevenue: number;
  };
  previousMonth: {
    name: string;
    key: string;
    documents: { customerName: string; customerHp: string; customerId: string; docNumber: string; openDate: string; totalPrice: number }[];
    totalCount: number;
    totalRevenue: number;
  };
}

type ReturnDoc = { customerName: string; customerHp: string; customerId: string; docNumber: string; openDate: string; totalPrice: number };

/** ספירות התראות הכיול, מצטברות בשרת לפי חודש/מיקום/סוג */
type AlertCount = { month: string; location: string; type: string; count: number };
type AlertsAggregate = {
  window: { from: string; to: string; monthsBack: number; monthsAhead: number };
  byMonth: AlertCount[];
  outsideWindow: { unparsable: number; older: number; ahead: number };
  grandTotal: number;
};
type MonthDevices = { rows: any[]; total: number; truncated: boolean; loading: boolean };

/**
 * סופר בתוך קבוצת חודש לפי הסינון הנבחר.
 * גם הכותרת, גם התגיות וגם הגרף עוברים דרך הפונקציה הזו — לכן הם תמיד עקביים
 * זה עם זה. קודם לכן הכותרת ספרה את החלון והתגיות ספרו את כל הטבלה.
 */
function countAlerts(counts: AlertCount[], location: string, type: string): number {
  return counts.reduce((sum, c) => {
    if (location !== 'all' && c.location !== location) return sum;
    if (type === 'overdue'  && c.type !== 'error') return sum;
    if (type === 'upcoming' && c.type === 'error') return sum;
    return sum + c.count;
  }, 0);
}

const SUMMARY_MONTH_NAMES = ['ינואר', 'פברואר', 'מרץ', 'אפריל', 'מאי', 'יוני', 'יולי', 'אוגוסט', 'ספטמבר', 'אוקטובר', 'נובמבר', 'דצמבר'];

const SUMMARY_HEBREW_HOLIDAYS: Date[] = [
  // 2024
  new Date(2024,2,24), new Date(2024,3,23), new Date(2024,3,24), new Date(2024,3,25), new Date(2024,3,26), new Date(2024,3,27), new Date(2024,3,28), new Date(2024,3,29), new Date(2024,3,30),
  new Date(2024,4,13), new Date(2024,4,14), new Date(2024,5,12),
  new Date(2024,9,3), new Date(2024,9,4), new Date(2024,9,12), new Date(2024,9,17), new Date(2024,9,18), new Date(2024,9,19), new Date(2024,9,20), new Date(2024,9,21), new Date(2024,9,22), new Date(2024,9,23), new Date(2024,9,24),
  // 2025
  new Date(2025,2,14), new Date(2025,3,13), new Date(2025,3,14), new Date(2025,3,15), new Date(2025,3,16), new Date(2025,3,17), new Date(2025,3,18), new Date(2025,3,19), new Date(2025,3,20),
  new Date(2025,3,30), new Date(2025,4,1), new Date(2025,5,2),
  new Date(2025,8,23), new Date(2025,8,24), new Date(2025,9,2), new Date(2025,9,7), new Date(2025,9,8), new Date(2025,9,9), new Date(2025,9,10), new Date(2025,9,11), new Date(2025,9,12), new Date(2025,9,13), new Date(2025,9,14),
  // 2026
  new Date(2026,2,3), new Date(2026,3,2), new Date(2026,3,3), new Date(2026,3,4), new Date(2026,3,5), new Date(2026,3,6), new Date(2026,3,7), new Date(2026,3,8), new Date(2026,3,9),
  new Date(2026,3,21), new Date(2026,3,22), new Date(2026,4,22),
  new Date(2026,8,12), new Date(2026,8,13), new Date(2026,8,21), new Date(2026,8,26), new Date(2026,8,27), new Date(2026,8,28), new Date(2026,8,29), new Date(2026,8,30), new Date(2026,9,1), new Date(2026,9,2), new Date(2026,9,3),
];

function computeWorkingDaysInMonth(year: number, month: number, companyDaysOff: Date[]): number {
  const start = startOfMonth(new Date(year, month));
  const end = endOfMonth(new Date(year, month));
  return eachDayOfInterval({ start, end }).filter(d => {
    if (isWeekend(d)) return false;
    if (SUMMARY_HEBREW_HOLIDAYS.some(h => isSameDay(h, d))) return false;
    if (companyDaysOff.some(co => isSameDay(co, d))) return false;
    return true;
  }).length;
}

function fmtILS(value: number): string {
  if (value >= 1_000_000) return `₪${(value / 1_000_000).toFixed(1)}מ'`;
  if (value >= 1_000) return `₪${Math.round(value / 1_000).toLocaleString()}k`;
  return `₪${Math.round(value).toLocaleString()}`;
}

export default function CompanySummary() {
  const queryClient = useQueryClient();
  const [selectedYear, setSelectedYear] = useState<number>(new Date().getFullYear());
  const [selectedAgent, setSelectedAgent] = useState<string>('all');
  const [selectedDoc, setSelectedDoc] = useState<ReturnDoc | null>(null);
  const [selectedSummaryFilterMonth, setSelectedSummaryFilterMonth] = useState<number | null>(null);
  const [alertsView, setAlertsView] = useState<'month' | 'customer'>('month');
  const [alertsLocation, setAlertsLocation] = useState<'all' | 'internal' | 'external' | 'subcontractor'>('all');
  const [alertsType, setAlertsType] = useState<'all' | 'overdue' | 'upcoming'>('all');
  const [alertsAgent, setAlertsAgent] = useState<string>('all');
  const [expandedAlertMonths, setExpandedAlertMonths] = useState<Set<string>>(new Set());
  const [activityDropThreshold, setActivityDropThreshold] = useState<number>(40);
  const [alertSearch, setAlertSearch] = useState<string>('');
  const [activityDropAgentFilter, setActivityDropAgentFilter] = useState<string>('all');
  const [activityDropCustomRange, setActivityDropCustomRange] = useState<boolean>(false);
  const [activityDropFromDate, setActivityDropFromDate] = useState<string>('');
  const [activityDropToDate, setActivityDropToDate] = useState<string>('');
  const [isRefreshingGlobal, setIsRefreshingGlobal] = useState(false);
  const [commandCopied, setCommandCopied] = useState(false);
  const [localRequestedAt, setLocalRequestedAt] = useState<string | null>(
    () => localStorage.getItem('qcc_global_sync_requested_at')
  );
  const [showSyncCompleteBanner, setShowSyncCompleteBanner] = useState(false);
  const localRequestedAtRef = useRef(localRequestedAt);
  const prevSyncStatusRef = useRef<string | null>(null);
  const monthGroupRefs = useRef<Map<string, HTMLDivElement>>(new Map());
  const calChartRef = useRef<HTMLDivElement>(null);
  const [isExporting, setIsExporting] = useState(false);
  const availableYears = [2024, 2025, 2026];
  
  const { data, isLoading, error } = useQuery<CompanySummaryData>({
    queryKey: ['/api/customers/list'],
    queryFn: async () => {
      const response = await fetch('/api/customers/list');
      if (!response.ok) throw new Error('Failed to fetch customers');
      return response.json();
    }
  });

  const { data: returnsData } = useQuery<CompanyReturnsData>({
    queryKey: ['/api/company/returns'],
    queryFn: async () => {
      const response = await fetch('/api/company/returns');
      if (!response.ok) throw new Error('Failed to fetch returns');
      return response.json();
    }
  });

  const { data: agentsData } = useQuery<{ agents: string[] }>({
    queryKey: ['/api/agents'],
    queryFn: async () => {
      const response = await fetch('/api/agents');
      if (!response.ok) throw new Error('Failed to fetch agents');
      return response.json();
    }
  });

  const { data: monthlyReturnsData } = useQuery<{
    year: number;
    companyMonthly: { month: string; revenue: number; count: number }[];
    agentMonthly: Record<string, { month: string; revenue: number; count: number }[]>;
  }>({
    queryKey: ['/api/agents/monthly-returns', selectedYear],
    queryFn: async () => {
      const res = await fetch(`/api/agents/monthly-returns?year=${selectedYear}`);
      if (!res.ok) throw new Error('Failed to fetch monthly returns');
      return res.json();
    }
  });

  const { data: returnsByYear } = useQuery<{ year: number; count: number; totalValue: number }>({
    queryKey: ['/api/summary/returns-by-year', selectedYear],
    queryFn: async () => {
      const response = await fetch(`/api/summary/returns-by-year?year=${selectedYear}`);
      if (!response.ok) throw new Error('Failed to fetch returns by year');
      return response.json();
    }
  });

  const { data: calibratedDevicesData } = useQuery<{ year: number; count: number }>({
    queryKey: ['/api/summary/calibrated-devices', selectedYear],
    queryFn: async () => {
      const res = await fetch(`/api/summary/calibrated-devices?year=${selectedYear}`);
      if (!res.ok) throw new Error('Failed to fetch calibrated devices');
      return res.json();
    }
  });

  const { data: growthRateSetting } = useQuery<{ rate: number; mode?: string; dailyRate?: number }>({
    queryKey: ['/api/settings/growth-rate'],
    queryFn: async () => {
      const res = await fetch('/api/settings/growth-rate');
      if (!res.ok) return { rate: 6 };
      return res.json();
    },
  });

  const { data: summaryDaysOff } = useQuery<{ id: string; date: string }[]>({
    queryKey: ['/api/company/days-off', selectedYear],
    queryFn: async () => {
      const res = await fetch(`/api/company/days-off?year=${selectedYear}`);
      if (!res.ok) return [];
      return res.json();
    },
  });

  // ספירות מצטברות בלבד. קודם לכן נמשכו כל 452,269 שורות ההתראות (165MB)
  // רק כדי לספור אותן בדפדפן — זו הייתה הסיבה העיקרית לאיטיות העמוד.
  const { data: alertsAgg } = useQuery<AlertsAggregate>({
    queryKey: ['/api/company/calibration-alerts'],
    queryFn: async () => {
      const res = await fetch('/api/company/calibration-alerts');
      if (!res.ok) throw new Error('Failed to fetch calibration alerts');
      return res.json();
    },
    staleTime: 5 * 60 * 1000,
  });

  // תצוגת "לפי לקוח" — גם היא מצטברת בשרת, על אותו חלון ואותם מסננים
  const { data: alertCustomers } = useQuery<{ id: string; companyName: string; count: number }[]>({
    queryKey: ['/api/company/calibration-alerts/customers', alertsLocation, alertsType],
    queryFn: async () => {
      const res = await fetch(`/api/company/calibration-alerts/customers?location=${alertsLocation}&type=${alertsType}&limit=10`);
      if (!res.ok) throw new Error('Failed to fetch alert customers');
      return res.json();
    },
    staleTime: 5 * 60 * 1000,
  });

  // רשימת המכשירים של חודש נטענת רק כשפותחים אותו
  const [monthDevices, setMonthDevices] = useState<Record<string, MonthDevices>>({});
  const loadMonthDevices = useCallback(async (month: string, location: string, type: string) => {
    const cacheKey = `${month}|${location}|${type}`;
    setMonthDevices(prev => (prev[cacheKey] ? prev : { ...prev, [cacheKey]: { rows: [], total: 0, truncated: false, loading: true } }));
    try {
      const res = await fetch(`/api/company/calibration-alerts/devices?month=${month}&location=${location}&type=${type}`);
      const json = await res.json();
      setMonthDevices(prev => ({ ...prev, [cacheKey]: { rows: json.rows || [], total: json.total || 0, truncated: !!json.truncated, loading: false } }));
    } catch {
      setMonthDevices(prev => ({ ...prev, [cacheKey]: { rows: [], total: 0, truncated: false, loading: false } }));
    }
  }, []);

  type GlobalSyncStateStatus = 'idle' | 'requested' | 'running' | 'complete' | 'error';
  interface GlobalSyncStatus {
    lastSync: string | null;
    syncState: {
      status: GlobalSyncStateStatus;
      requestedAt: string | null;
      startedAt: string | null;
      completedAt: string | null;
      error: string | null;
    };
  }

  const { data: globalSyncStatus, refetch: refetchGlobalSyncStatus } = useQuery<GlobalSyncStatus>({
    queryKey: ['/api/company/global-sync-status'],
    queryFn: async () => {
      const res = await fetch('/api/company/global-sync-status');
      if (!res.ok) return { lastSync: null, syncState: { status: 'idle', requestedAt: null, startedAt: null, completedAt: null, error: null } };
      return res.json();
    },
    refetchInterval: (data) => {
      const st = data?.state?.data?.syncState?.status;
      if (st === 'requested' || st === 'running') return 3000;
      if (localRequestedAtRef.current) return 3000;
      return false;
    },
  });

  const syncStateStatus: GlobalSyncStateStatus = (() => {
    const serverStatus = globalSyncStatus?.syncState?.status ?? 'idle';
    if (serverStatus === 'idle' && localRequestedAt) {
      const lastSync = globalSyncStatus?.lastSync ? new Date(globalSyncStatus.lastSync).getTime() : null;
      const requestedTime = new Date(localRequestedAt).getTime();
      if (!lastSync || requestedTime > lastSync) return 'requested';
    }
    return serverStatus;
  })();
  const isSyncActive = syncStateStatus === 'requested' || syncStateStatus === 'running';

  useEffect(() => {
    localRequestedAtRef.current = localRequestedAt;
  }, [localRequestedAt]);

  useEffect(() => {
    if (!localRequestedAt) return;
    const serverStatus = globalSyncStatus?.syncState?.status;
    const lastSync = globalSyncStatus?.lastSync ? new Date(globalSyncStatus.lastSync).getTime() : null;
    const requestedTime = new Date(localRequestedAt).getTime();
    const syncCompletedAfterRequest = lastSync !== null && lastSync >= requestedTime;
    if (serverStatus === 'complete' || serverStatus === 'error' || syncCompletedAfterRequest) {
      localStorage.removeItem('qcc_global_sync_requested_at');
      setLocalRequestedAt(null);
    }
  }, [globalSyncStatus?.syncState?.status, globalSyncStatus?.lastSync, localRequestedAt]);

  useEffect(() => {
    const currentStatus = globalSyncStatus?.syncState?.status ?? null;
    const prev = prevSyncStatusRef.current;
    prevSyncStatusRef.current = currentStatus;
    if (prev === 'running' && currentStatus === 'complete') {
      queryClient.invalidateQueries({ queryKey: ['/api/customers/list'] });
      queryClient.invalidateQueries({ queryKey: ['/api/company/calibration-alerts'] });
      queryClient.invalidateQueries({ queryKey: ['/api/company/returns'] });
      setShowSyncCompleteBanner(true);
      const timer = setTimeout(() => setShowSyncCompleteBanner(false), 5000);
      return () => clearTimeout(timer);
    }
  }, [globalSyncStatus?.syncState?.status]);

  const isStale = (() => {
    if (!globalSyncStatus?.lastSync) return true;
    const lastSyncDate = new Date(globalSyncStatus.lastSync);
    if (isNaN(lastSyncDate.getTime())) return true;
    const hoursAgo = (Date.now() - lastSyncDate.getTime()) / (1000 * 60 * 60);
    return hoursAgo > 24;
  })();

  const GLOBAL_SYNC_COMMAND = 'py sync-customer-data.py --global-sync';

  const handleRefreshGlobalData = async () => {
    setIsRefreshingGlobal(true);
    const requestedAt = new Date().toISOString();
    localStorage.setItem('qcc_global_sync_requested_at', requestedAt);
    setLocalRequestedAt(requestedAt);
    localRequestedAtRef.current = requestedAt;
    try {
      await fetch('/api/sync/global-sync', { method: 'POST', headers: { 'Content-Type': 'application/json' } });
      await refetchGlobalSyncStatus();
    } finally {
      setIsRefreshingGlobal(false);
    }
  };

  const handleCopyCommand = async () => {
    try {
      await navigator.clipboard.writeText(GLOBAL_SYNC_COMMAND);
      setCommandCopied(true);
      setTimeout(() => setCommandCopied(false), 2000);
    } catch {
      // fallback: select text manually if clipboard API unavailable
    }
  };

  // Monthly calibration alerts grouped by nextCalDate month
  // Uses the company-wide table (all customers, no [:10] limit) when available,
  // falls back to per-customer alerts from the customer list cache.
  // Filtered by selectedAgent when applicable.
  const monthlyAlertsMap = useMemo(() => {
    const now = new Date();
    const thisMonthStart = new Date(now.getFullYear(), now.getMonth(), 1);
    const label = (y: number, m: number) =>
      new Date(y, m - 1, 1).toLocaleDateString('he-IL', { month: 'long', year: 'numeric' });

    // מקור ראשי: הספירות המצטברות מהשרת (כבר מסוננות לחלון 3 שנים אחורה / 12 קדימה)
    if (alertsAgg?.byMonth?.length) {
      const map = new Map<string, { key: string; monthLabel: string; year: number; month: number; isPast: boolean; counts: AlertCount[] }>();
      for (const row of alertsAgg.byMonth) {
        const [yy, mm] = row.month.split('-').map(Number);
        if (!yy || !mm) continue;
        if (!map.has(row.month)) {
          map.set(row.month, {
            key: row.month, monthLabel: label(yy, mm), year: yy, month: mm,
            isPast: new Date(yy, mm - 1, 1) < thisMonthStart, counts: [],
          });
        }
        map.get(row.month)!.counts.push({ ...row, count: Number(row.count) || 0 });
      }
      return Array.from(map.values()).sort((a, b) => b.key.localeCompare(a.key));
    }

    // גיבוי: כשאין נתונים גלובליים, נגזר מקאש הלקוחות.
    // חודשים עתידיים מושמטים — "10 ההתראות הבאות" של כל לקוח מצטופפות סביב העתיד הקרוב
    // ויוצרות קפיצה מלאכותית.
    const map = new Map<string, { key: string; monthLabel: string; year: number; month: number; isPast: boolean; counts: AlertCount[] }>();
    const threeYearsAgo = new Date(now.getFullYear() - 3, now.getMonth(), 1);
    const bump = (key: string, y: number, m: number, location: string, type: string) => {
      if (!map.has(key)) {
        map.set(key, { key, monthLabel: label(y, m), year: y, month: m, isPast: new Date(y, m - 1, 1) < thisMonthStart, counts: [] });
      }
      const g = map.get(key)!;
      const hit = g.counts.find(c => c.location === location && c.type === type);
      if (hit) hit.count++;
      else g.counts.push({ month: key, location, type, count: 1 });
    };

    (data?.customers || []).forEach((c: any) => {
      const serialToLocation = new Map<string, string>();
      (c.devicesList || []).forEach((d: any) => {
        if (d.serialNo) serialToLocation.set(d.serialNo, d.location || 'internal');
      });
      (c.alerts || []).forEach((alert: any) => {
        const parts = String(alert.nextCalDate || '').split('/');
        if (parts.length < 3) return;
        const [, mm, yy] = parts.map(Number);
        if (!yy || !mm) return;
        const monthDate = new Date(yy, mm - 1, 1);
        if (monthDate >= thisMonthStart || monthDate < threeYearsAgo) return;
        bump(`${yy}-${String(mm).padStart(2, '0')}`, yy, mm,
             alert.location || serialToLocation.get(alert.serialNo || '') || 'internal',
             alert.type || 'warning');
      });
    });

    return Array.from(map.values()).sort((a, b) => b.key.localeCompare(a.key));
  }, [data, alertsAgg]);

  // Mini bar chart data — calibration load by location per month (chronological)
  const { calLoadChartData, calLoadAvg } = useMemo(() => {
    const raw = [...monthlyAlertsMap].reverse().map(group => {
      const internal = countAlerts(group.counts, 'internal', alertsType);
      const external = countAlerts(group.counts, 'external', alertsType);
      const shortLabel = new Date(group.year, group.month - 1, 1)
        .toLocaleDateString('he-IL', { month: 'short', year: '2-digit' });
      return { key: group.key, label: shortLabel, internal, external };
    }).filter(d => d.internal + d.external > 0);

    const avg = raw.length > 0
      ? raw.reduce((sum, d) => sum + d.internal + d.external, 0) / raw.length
      : 0;

    const data = raw.map(d => ({ ...d, isAboveAvg: (d.internal + d.external) > avg }));
    return { calLoadChartData: data, calLoadAvg: avg };
  }, [monthlyAlertsMap, alertsType]);

  const handleCalBarClick = (data: any) => {
    const key = data?.activePayload?.[0]?.payload?.key;
    if (!key) return;
    setExpandedAlertMonths(prev => { const next = new Set(prev); next.add(key); return next; });
    setTimeout(() => {
      const el = monthGroupRefs.current.get(key);
      if (el) el.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
    }, 50);
  };

  const handleExportChart = useCallback(async (format: 'png' | 'pdf') => {
    if (!calChartRef.current || isExporting) return;
    setIsExporting(true);
    try {
      const canvas = await html2canvas(calChartRef.current, {
        backgroundColor: '#ffffff',
        scale: 2,
        useCORS: true,
      });
      const title = 'עומס כיול חודשי';
      const timestamp = new Date().toLocaleDateString('he-IL').replace(/\//g, '-');
      if (format === 'png') {
        const link = document.createElement('a');
        link.download = `${title}-${timestamp}.png`;
        link.href = canvas.toDataURL('image/png');
        link.click();
      } else {
        const imgData = canvas.toDataURL('image/png');
        const pdf = new jsPDF({ orientation: 'landscape', unit: 'px', format: [canvas.width / 2 + 40, canvas.height / 2 + 60] });
        pdf.addImage(imgData, 'PNG', 20, 40, canvas.width / 2, canvas.height / 2);
        pdf.setFontSize(14);
        pdf.text(title, 20, 24);
        pdf.save(`${title}-${timestamp}.pdf`);
      }
    } catch (e) {
      console.error('Export failed', e);
    } finally {
      setIsExporting(false);
    }
  }, [isExporting]);

  // Month customer breakdown (before early returns — Rules of Hooks)
  const summaryMonthCustomerBreakdown = useMemo(() => {
    if (selectedSummaryFilterMonth === null || !data?.customers) return [];
    const monthKey = `${selectedYear}-${String(selectedSummaryFilterMonth + 1).padStart(2, '0')}`;
    return (data.customers as any[])
      .map((c: any) => {
        const entry = c.monthlyRevenue?.find((m: any) => m.month === monthKey);
        return { id: c.customerId || c.id, name: c.companyName || c.name, revenue: entry?.revenue || 0, count: entry?.count || 0 };
      })
      .filter((c: any) => c.revenue > 0)
      .sort((a: any, b: any) => b.revenue - a.revenue);
  }, [selectedSummaryFilterMonth, selectedYear, data]);

  const summaryAllYearBreakdown = useMemo(() => {
    if (!data?.customers) return [];
    const prefix = `${selectedYear}-`;
    return (data.customers as any[])
      .map((c: any) => {
        const revenue = (c.monthlyRevenue || [])
          .filter((m: any) => m.month?.startsWith(prefix))
          .reduce((s: number, m: any) => s + (m.revenue || 0), 0);
        const count = (c.monthlyRevenue || [])
          .filter((m: any) => m.month?.startsWith(prefix))
          .reduce((s: number, m: any) => s + (m.count || 0), 0);
        return { id: c.customerId || c.id, name: c.companyName || c.name, revenue, count };
      })
      .filter((c: any) => c.revenue > 0)
      .sort((a: any, b: any) => b.revenue - a.revenue);
  }, [selectedYear, data]);

  // Activity drop anomaly detection — supports custom date ranges and agent filter
  const activityDropAlerts = useMemo(() => {
    if (!data?.customers) return [];

    const shiftMonth = (y: number, mo: number, delta: number): [number, number] => {
      let m = mo + delta;
      let yr = y;
      while (m <= 0) { m += 12; yr--; }
      while (m > 12) { m -= 12; yr++; }
      return [yr, m];
    };
    const toKey = (y: number, m: number) => `${y}-${String(m).padStart(2, '0')}`;
    const fmtMonth = (y: number, m: number) =>
      new Date(y, m - 1, 1).toLocaleDateString('he-IL', { month: 'short' });

    const now = new Date();
    const cy = now.getFullYear();
    const cm = now.getMonth() + 1;

    let recentKeys: string[];

    if (activityDropCustomRange && activityDropFromDate && activityDropToDate && activityDropFromDate <= activityDropToDate) {
      const [fromY, fromM] = activityDropFromDate.split('-').map(Number);
      const [toY, toM] = activityDropToDate.split('-').map(Number);
      recentKeys = [];
      let y = fromY, m = fromM;
      while (y < toY || (y === toY && m <= toM)) {
        recentKeys.push(toKey(y, m));
        [y, m] = shiftMonth(y, m, 1);
      }
    } else {
      recentKeys = [3, 2, 1].map(d => toKey(...shiftMonth(cy, cm, -d)));
    }

    const splyKeys = recentKeys.map(k => {
      const [ky, km] = k.split('-').map(Number);
      return toKey(ky - 1, km);
    });

    const periodLabel = (keys: string[]) => {
      const sorted = [...keys].sort();
      const [fy, fm] = sorted[0].split('-').map(Number);
      const [ly, lm] = sorted[sorted.length - 1].split('-').map(Number);
      return fy === ly
        ? `${fmtMonth(fy, fm)}–${fmtMonth(ly, lm)} ${ly}`
        : `${fmtMonth(fy, fm)} ${fy}–${fmtMonth(ly, lm)} ${ly}`;
    };

    const recentLabel = recentKeys.length > 0 ? periodLabel(recentKeys) : '';
    const splyLabel   = splyKeys.length > 0 ? periodLabel(splyKeys) : '';

    let customers = data.customers as any[];
    if (activityDropAgentFilter !== 'all') {
      customers = customers.filter((c: any) => c.agentName === activityDropAgentFilter);
    }

    return customers
      .map((c: any) => {
        const allMonthly: any[] = c.monthlyRevenue || [];
        const getM = (key: string) =>
          allMonthly.find((m: any) => m.month === key) ?? { count: 0, revenue: 0, month: key };

        const recent    = recentKeys.map(getM);
        const splyMonths = splyKeys.map(getM);

        const recentTotalRevenue = recent.reduce((s, m) => s + (m.revenue || 0), 0);
        const splyTotalRevenue   = splyMonths.reduce((s, m) => s + (m.revenue || 0), 0);

        const fin = c.financials || [];
        const prevYearRevenue = fin.find((f: any) => Number(f.year) === selectedYear - 1)?.revenue || 0;
        if (prevYearRevenue < 50000) return null;

        if (splyTotalRevenue < 50000) return null;

        const dropPct = (1 - recentTotalRevenue / splyTotalRevenue) * 100;
        if (dropPct < activityDropThreshold) return null;

        const currentYearRevenue = fin.find((f: any) => Number(f.year) === selectedYear)?.revenue || 0;

        return {
          id: c.id,
          hp: c.hp,
          companyName: c.companyName,
          agentName: c.agentName,
          dropPct: Math.round(dropPct),
          recentTotalRevenue: Math.round(recentTotalRevenue),
          splyTotalRevenue:   Math.round(splyTotalRevenue),
          splyPeriodLabel: splyLabel,
          recent3Label: recentLabel,
          currentYearRevenue,
          prevYearRevenue,
        };
      })
      .filter(Boolean)
      .sort((a: any, b: any) => b.dropPct - a.dropPct);
  }, [data, selectedYear, activityDropThreshold, activityDropAgentFilter, activityDropCustomRange, activityDropFromDate, activityDropToDate]);

  // Monthly target vs actual chart data — must be before early returns (Rules of Hooks)
  const summaryChartData = useMemo(() => {
    const customers = (data?.customers || []).filter((c: any) => selectedAgent === 'all' || c.agentName === selectedAgent);
    const financials = data?.yearlyFinancials || [];
    const companyDaysOffDates = (summaryDaysOff || []).map(d => new Date(d.date + 'T12:00:00'));
    const workingDaysPerMonth = Array.from({ length: 12 }, (_, i) => computeWorkingDaysInMonth(selectedYear, i, companyDaysOffDates));
    const totalWorkingDays = workingDaysPerMonth.reduce((a, b) => a + b, 0);

    const targetMode = (growthRateSetting as any)?.mode || 'growth';
    const growthRate = ((growthRateSetting?.rate) || 6) / 100;
    const dailyRate = (growthRateSetting as any)?.dailyRate || 5000;
    const rawMonthlyDailyRates: number[] | undefined = (growthRateSetting as any)?.monthlyDailyRates;
    const monthlyDailyRates: number[] = (rawMonthlyDailyRates?.length === 12)
      ? rawMonthlyDailyRates
      : Array(12).fill(dailyRate);
    const prevYearRevenue = financials.find((y: any) => y.year === selectedYear - 1)?.revenue || 0;

    const annualTarget = targetMode === 'daily'
      ? monthlyDailyRates.reduce((sum, rate, i) => sum + rate * workingDaysPerMonth[i], 0)
      : (prevYearRevenue > 0 ? prevYearRevenue * (1 + growthRate) : 1000000);

    const dailyTargetBase = totalWorkingDays > 0 ? annualTarget / totalWorkingDays : 0;

    const monthlyRevenue: number[] = Array(12).fill(0);
    customers.forEach((c: any) => {
      (c.monthlyRevenue || []).forEach((m: any) => {
        if (!m.month || !m.revenue) return;
        const [y, mo] = m.month.split('-').map(Number);
        if (y === selectedYear) monthlyRevenue[mo - 1] += m.revenue || 0;
      });
    });

    return Array.from({ length: 12 }, (_, month) => {
      const workingDays = workingDaysPerMonth[month];
      const monthTarget = targetMode === 'daily'
        ? monthlyDailyRates[month] * workingDays
        : dailyTargetBase * workingDays;
      const actual = monthlyRevenue[month];
      const progress = monthTarget > 0 ? (actual / monthTarget) * 100 : 0;
      return { name: SUMMARY_MONTH_NAMES[month], יעד: Math.round(monthTarget), בפועל: Math.round(actual), progress };
    });
  }, [data, selectedYear, growthRateSetting, summaryDaysOff, selectedAgent]);

  const returnsChartData = useMemo(() => {
    const monthlyArr: { month: string; revenue: number; count: number }[] =
      selectedAgent === 'all'
        ? (monthlyReturnsData?.companyMonthly || [])
        : (monthlyReturnsData?.agentMonthly?.[selectedAgent] || []);

    const byMonth: Record<string, { revenue: number; count: number }> = {};
    for (const row of monthlyArr) {
      if (row.month) byMonth[row.month] = { revenue: row.revenue, count: row.count };
    }

    return Array.from({ length: 12 }, (_, i) => {
      const key = `${selectedYear}-${String(i + 1).padStart(2, '0')}`;
      const d = byMonth[key] || { revenue: 0, count: 0 };
      return { name: SUMMARY_MONTH_NAMES[i], ערך: Math.round(d.revenue), מספר: d.count };
    });
  }, [monthlyReturnsData, selectedAgent, selectedYear]);

  // Last 3 months actual revenue (relative to today, regardless of selectedYear)
  const pastThreeMonthsRevenue = useMemo(() => {
    const now = new Date();
    const result = [];
    for (let i = 2; i >= 0; i--) {
      const d = new Date(now.getFullYear(), now.getMonth() - i, 1);
      const key = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;
      const prevKey = `${d.getFullYear() - 1}-${String(d.getMonth() + 1).padStart(2, '0')}`;
      const monthName = d.toLocaleDateString('he-IL', { month: 'long', year: 'numeric' });
      const filtered = (data?.customers || []).filter((c: any) => selectedAgent === 'all' || c.agentName === selectedAgent);
      const revenue = filtered.reduce((sum: number, c: any) => {
        const mr = (c.monthlyRevenue || []).find((m: any) => m.month === key);
        return sum + (mr?.revenue || 0);
      }, 0);
      const prevYearRevenue = filtered.reduce((sum: number, c: any) => {
        const mr = (c.monthlyRevenue || []).find((m: any) => m.month === prevKey);
        return sum + (mr?.revenue || 0);
      }, 0);
      const monthIdx = d.getMonth();
      const target = (d.getFullYear() === selectedYear && summaryChartData[monthIdx])
        ? (summaryChartData[monthIdx].יעד || 0)
        : 0;
      result.push({ key, monthName, revenue, prevYearRevenue, target });
    }
    return result;
  }, [data, selectedAgent, selectedYear, summaryChartData]);

  if (isLoading) {
    return (
      <DashboardLayout>
        <div className="flex items-center justify-center h-[60vh]">
          <Loader2 className="w-8 h-8 animate-spin text-primary" />
          <span className="mr-3 text-lg">טוען נתוני חברה...</span>
        </div>
      </DashboardLayout>
    );
  }

  if (error || !data) {
    return (
      <DashboardLayout>
        <div className="flex items-center justify-center h-[60vh]">
          <AlertTriangle className="w-8 h-8 text-destructive" />
          <span className="mr-3 text-lg">שגיאה בטעינת נתונים</span>
        </div>
      </DashboardLayout>
    );
  }

  const allCustomers = data.customers || [];

  const uniqueAgents = agentsData?.agents || [];
  
  // Helper function to check if customer has revenue in selected year
  const hasRevenueInYear = (customer: CustomerSummary, year: number): boolean => {
    if (customer.financials) {
      return customer.financials.some(f => f.year === year && f.revenue > 0);
    }
    if (customer.monthlyRevenue) {
      return customer.monthlyRevenue.some(m => {
        const [y] = (m.month || '').split('-');
        return parseInt(y) === year && m.revenue > 0;
      });
    }
    return false;
  };
  
  // Get customer revenue for selected year
  const getCustomerYearRevenue = (customer: CustomerSummary, year: number): number => {
    if (customer.financials) {
      const yearData = customer.financials.find(f => f.year === year);
      return yearData?.revenue || 0;
    }
    if (customer.monthlyRevenue) {
      return customer.monthlyRevenue
        .filter(m => {
          const [y] = (m.month || '').split('-');
          return parseInt(y) === year;
        })
        .reduce((sum, m) => sum + (m.revenue || 0), 0);
    }
    return 0;
  };
  
  // Filter by year, then by agent, and sort by year revenue
  const customersFilteredByYear = allCustomers.filter(c => hasRevenueInYear(c, selectedYear));
  
  const customers = selectedAgent === 'all' 
    ? customersFilteredByYear.sort((a, b) => getCustomerYearRevenue(b, selectedYear) - getCustomerYearRevenue(a, selectedYear))
    : customersFilteredByYear
        .filter(c => c.agentName === selectedAgent)
        .sort((a, b) => getCustomerYearRevenue(b, selectedYear) - getCustomerYearRevenue(a, selectedYear));

  const totalDevices = customers.reduce((sum, c) => sum + (c.deviceInventory?.totalDevices || 0), 0);
  const activeDevices = customers.reduce((sum, c) => sum + (c.deviceInventory?.activeDevices || 0), 0);
  const expiredDevices = customers.reduce((sum, c) => sum + (c.deviceInventory?.outForCalibration || 0), 0);

  const ytdRevenue = customers.reduce((sum, c) => {
    const yearData = c.financials?.find(f => f.year === selectedYear);
    return sum + (yearData?.revenue || 0);
  }, 0);
  const ytdInvoicesCount = customers.reduce((sum, c) => {
    const yearData = c.financials?.find(f => f.year === selectedYear);
    return sum + (yearData?.invoicesCount || 0);
  }, 0);

  const totalForecastValue = customers.reduce((sum, c) => sum + (c.pendingForecast?.totalValue || 0), 0);
  const totalForecastDocs = customers.reduce((sum, c) => sum + (c.pendingForecast?.totalDocuments || 0), 0);

  const ytdTarget = (() => {
    const now = new Date();
    if (selectedYear !== now.getFullYear()) return 0;
    const currentMonthIdx = now.getMonth();
    return summaryChartData.slice(0, currentMonthIdx + 1).reduce((s, m) => s + (m.יעד || 0), 0);
  })();

  const totalAlerts = customers.reduce((sum, c) => sum + (c.alerts?.length || 0), 0);

  const gradeDistribution = customers.reduce((acc, c) => {
    const grade = c.customerScore?.grade || 'E';
    acc[grade] = (acc[grade] || 0) + 1;
    return acc;
  }, {} as Record<string, number>);

  const gradeColors: Record<string, string> = {
    'A': '#10b981',
    'B': '#3b82f6',
    'C': '#f59e0b',
    'D': '#f97316',
    'E': '#ef4444'
  };

  const gradeChartData = Object.entries(gradeDistribution).map(([grade, count]) => ({
    name: `דירוג ${grade}`,
    value: count,
    color: gradeColors[grade] || '#6b7280'
  }));

  const customersWithForecast = customers
    .filter(c => c.pendingForecast && c.pendingForecast.totalValue > 0)
    .sort((a, b) => (b.pendingForecast?.totalValue || 0) - (a.pendingForecast?.totalValue || 0))
    .slice(0, 20);

  // Get yearly financial data
  const yearlyFinancials = data.yearlyFinancials || [];

  const currentYear = selectedYear;
  const previousYear = selectedYear - 1;
  
  const currentYearData = yearlyFinancials.find(y => y.year === currentYear) || { revenue: 0, invoicesCount: 0, quotesCount: 0, quotesRevenue: 0 };
  const previousYearData = yearlyFinancials.find(y => y.year === previousYear) || { revenue: 0, invoicesCount: 0, quotesCount: 0, quotesRevenue: 0 };
  
  // Calculate YoY change
  const revenueChange = previousYearData.revenue > 0 
    ? Math.round(((currentYearData.revenue - previousYearData.revenue) / previousYearData.revenue) * 100) 
    : 0;

  // customersWithAlerts computed inline (not useMemo) to avoid Rules of Hooks violation
  // Must be after `customers` is defined (after early returns)
  let customersWithAlerts: any[] = [];
  if (alertCustomers && alertCustomers.length > 0) {
    // מצטבר בשרת על אותו חלון תאריכים ואותם מסננים
    customersWithAlerts = alertCustomers.map(c => ({
      id: c.id,
      companyName: c.companyName,
      hp: c.id,
      deviceInventory: { outForCalibration: c.count },
      alerts: [] as any[],
    }));
  } else {
    customersWithAlerts = customers
      .filter(c => c.alerts && c.alerts.length > 0 && (alertsAgent === 'all' || c.agentName === alertsAgent))
      .sort((a, b) => (b.alerts?.length || 0) - (a.alerts?.length || 0))
      .slice(0, 10);
  }

  return (
    <DashboardLayout>
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        className="space-y-6"
      >
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-3xl font-bold text-foreground">ניתוח תעודות החזרה {selectedYear}</h1>
            <p className="text-muted-foreground">
              {selectedAgent === 'all'
                ? 'סקירה כוללת של תעודות החזרה לכל הלקוחות'
                : `תעודות החזרה של ${selectedAgent}`}
            </p>
            <div className="flex items-center gap-2 mt-1 flex-wrap">
              <span className="inline-flex items-center gap-1 text-xs bg-orange-50 border border-orange-200 text-orange-700 rounded-full px-2.5 py-0.5 font-medium">
                <ReceiptText className="w-3 h-3" />
                נתונים לפי תעודות החזרה
              </span>
            </div>
          </div>
          <div className="flex items-center gap-3 flex-row-reverse">
            <Select value={selectedAgent} onValueChange={setSelectedAgent}>
              <SelectTrigger className="w-40">
                <SelectValue placeholder="סוכן" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="all">כל הסוכנים</SelectItem>
                {uniqueAgents.map(agent => (
                  <SelectItem key={agent} value={agent}>{agent}</SelectItem>
                ))}
              </SelectContent>
            </Select>
            <Select value={selectedYear.toString()} onValueChange={(v) => setSelectedYear(parseInt(v))}>
              <SelectTrigger className="w-32">
                <SelectValue placeholder="שנה" />
              </SelectTrigger>
              <SelectContent>
                {availableYears.map(year => (
                  <SelectItem key={year} value={year.toString()}>{year}</SelectItem>
                ))}
              </SelectContent>
            </Select>
            <TooltipProvider>
              <Tooltip>
                <TooltipTrigger asChild>
                  <div className="flex flex-col items-end gap-1">
                    <Button
                      variant={syncStateStatus === 'error' ? 'destructive' : syncStateStatus === 'complete' ? 'default' : 'outline'}
                      size="sm"
                      onClick={handleRefreshGlobalData}
                      disabled={isRefreshingGlobal || isSyncActive}
                      data-testid="button-refresh-global-data"
                      className={`gap-2 ${isStale && !isSyncActive ? 'border-amber-400 bg-amber-50 text-amber-800 hover:bg-amber-100 hover:border-amber-500' : ''}`}
                    >
                      {isStale && !isSyncActive
                        ? <AlertTriangle className="w-4 h-4 text-amber-500" />
                        : <RefreshCw className={`w-4 h-4 ${(isRefreshingGlobal || isSyncActive) ? 'animate-spin' : ''}`} />
                      }
                      {syncStateStatus === 'requested' ? 'ממתין לסקריפט...' :
                       syncStateStatus === 'running' ? 'מסנכרן...' :
                       syncStateStatus === 'complete' ? 'סונכרן ✓' :
                       syncStateStatus === 'error' ? 'שגיאה — נסה שוב' :
                       'רענן נתוני חברה'}
                    </Button>
                    {isStale && !isSyncActive && (
                      <span className="text-xs font-medium text-amber-600" data-testid="badge-stale-data">
                        ⚠ נתונים ישנים
                      </span>
                    )}
                    {syncStateStatus === 'requested' && (
                      <div className="flex flex-col items-center gap-1 mt-1" data-testid="text-global-sync-instruction">
                        <span className="text-xs text-amber-700 font-medium">הרץ את הפקודה הבאה במחשב המקומי:</span>
                        <button
                          onClick={handleCopyCommand}
                          data-testid="button-copy-sync-command"
                          className="flex items-center gap-2 px-3 py-1.5 rounded-md bg-amber-50 border border-amber-300 hover:bg-amber-100 transition-colors cursor-pointer group"
                          title="לחץ להעתקה"
                        >
                          <Terminal className="w-3.5 h-3.5 text-amber-600 shrink-0" />
                          <code className="text-xs font-mono text-amber-800 select-all">{GLOBAL_SYNC_COMMAND}</code>
                          {commandCopied
                            ? <Check className="w-3.5 h-3.5 text-green-600 shrink-0" />
                            : <Copy className="w-3.5 h-3.5 text-amber-500 shrink-0 opacity-60 group-hover:opacity-100 transition-opacity" />
                          }
                        </button>
                        {commandCopied && (
                          <span className="text-xs text-green-600 font-medium" data-testid="text-copy-confirmation">הועתק ללוח!</span>
                        )}
                      </div>
                    )}
                    {globalSyncStatus?.lastSync && syncStateStatus !== 'requested' && (
                      <span className="text-xs text-muted-foreground" data-testid="text-global-sync-time">
                        עודכן: {new Date(globalSyncStatus.lastSync).toLocaleString('he-IL', { day: '2-digit', month: '2-digit', year: '2-digit', hour: '2-digit', minute: '2-digit' })}
                      </span>
                    )}
                  </div>
                </TooltipTrigger>
                <TooltipContent side="bottom" className="max-w-xs text-right" dir="rtl">
                  {syncStateStatus === 'requested' && (
                    <>
                      <p className="font-semibold">הסנכרון התבקש</p>
                      <p className="text-xs text-amber-600 mt-1">לחץ על הפקודה להעתקה, ואז הרץ אותה במחשב המקומי</p>
                    </>
                  )}
                  {syncStateStatus === 'running' && <p className="font-semibold">מסנכרן נתוני חברה...</p>}
                  {syncStateStatus === 'error' && <p className="text-destructive">{globalSyncStatus?.syncState?.error}</p>}
                  {isStale && !isSyncActive && (
                    <p className="font-semibold text-amber-600 mb-1">
                      {globalSyncStatus?.lastSync ? 'הנתונים ישנים (מעל 24 שעות)' : 'לא בוצע סנכרון מעולם'}
                    </p>
                  )}
                  <p className="text-xs text-muted-foreground mt-1">מסנכרן תעודות החזרה והתראות כיול ישירות מ-Priority</p>
                  {globalSyncStatus?.lastSync
                    ? <p className="text-xs text-muted-foreground">סנכרון אחרון: {new Date(globalSyncStatus.lastSync).toLocaleString('he-IL')}</p>
                    : <p className="text-xs text-muted-foreground">לא נמצא סנכרון קודם</p>
                  }
                  {isStale && !isSyncActive && (
                    <p className="text-xs text-amber-600 mt-1 font-medium">מומלץ להריץ: py sync-customer-data.py --global-sync</p>
                  )}
                </TooltipContent>
              </Tooltip>
            </TooltipProvider>
          </div>
        </div>

        {showSyncCompleteBanner && (
          <motion.div
            initial={{ opacity: 0, y: -12 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -12 }}
            className="flex items-center gap-3 px-4 py-3 rounded-lg bg-emerald-50 border border-emerald-200 text-emerald-800"
            data-testid="banner-sync-complete"
            dir="rtl"
          >
            <Check className="w-5 h-5 text-emerald-600 shrink-0" />
            <span className="font-medium">הסנכרון הושלם — הנתונים עודכנו</span>
          </motion.div>
        )}

        <div className="grid grid-cols-4 gap-3" dir="rtl">
          {/* כרטיס לקוחות */}
          <div className="bg-blue-50 rounded-xl p-4 border border-blue-200 flex flex-col justify-between min-h-[110px]">
            <div className="flex items-start justify-between">
              <div className="text-right">
                <p className="text-sm font-medium text-blue-600/80">סה"כ לקוחות</p>
                <p className="text-3xl font-bold text-blue-700 mt-1 leading-none">{customers.length.toLocaleString()}</p>
              </div>
              <div className="bg-blue-100 rounded-lg p-2">
                <Users className="w-5 h-5 text-blue-500" />
              </div>
            </div>
          </div>

          {/* כרטיס מכשירים שנכנסו לכיול */}
          <div className="bg-emerald-50 rounded-xl p-4 border border-emerald-200 flex flex-col justify-between min-h-[110px]">
            <div className="flex items-start justify-between">
              <div className="text-right">
                <p className="text-sm font-medium text-emerald-600/80">מכשירים שנכנסו לכיול</p>
                <p className="text-3xl font-bold text-emerald-700 mt-1 leading-none">
                  {(calibratedDevicesData?.count ?? 0).toLocaleString()}
                </p>
                <p className="text-xs text-muted-foreground mt-1">בשנת {selectedYear}</p>
              </div>
              <div className="bg-emerald-100 rounded-lg p-2">
                <Package className="w-5 h-5 text-emerald-500" />
              </div>
            </div>
          </div>

          {/* כרטיס 3 חודשים אחרונים — תעודות החזרה */}
          <div className="bg-purple-50 rounded-xl p-4 border border-purple-200 flex flex-col min-h-[110px]">
            <p className="text-sm font-medium text-purple-600/80 mb-2">3 חודשים אחרונים</p>
            <div className="flex flex-col gap-1.5 flex-1">
              {(() => {
                const monthIdx = new Date().getMonth();
                const last3 = [2, 1, 0].map(i => returnsChartData[monthIdx - i]).filter(Boolean);
                if (last3.length === 0) return <p className="text-xs text-muted-foreground text-center py-1">אין נתוני החזרות</p>;
                return last3.map((m, i) => (
                  <div key={m.name} className={`flex items-center justify-between rounded-md px-2 py-1 ${i === 2 ? 'bg-purple-100' : 'bg-white/60'}`}>
                    <span className="text-xs text-muted-foreground">{m.name}</span>
                    <div className="flex items-center gap-2 text-right">
                      <span className={`text-sm font-bold ${i === 2 ? 'text-purple-700' : 'text-gray-700'}`}>
                        {fmtILS(m.ערך)}
                      </span>
                      {m.מספר > 0 && (
                        <span className="text-xs text-muted-foreground">({m.מספר} תע׳)</span>
                      )}
                    </div>
                  </div>
                ));
              })()}
            </div>
          </div>

          {/* כרטיס סה"כ תעודות החזרה שנה */}
          <div className="bg-orange-50 rounded-xl p-4 border border-orange-200 flex flex-col justify-between min-h-[110px]">
            <div className="flex items-start justify-between">
              <div className="text-right">
                <p className="text-sm font-medium text-orange-600/80">תעודות החזרה {selectedYear}</p>
                <p className="text-2xl font-bold text-orange-700 mt-1 leading-none">
                  {fmtILS(returnsChartData.reduce((s, m) => s + m.ערך, 0))}
                </p>
                <p className="text-xs text-muted-foreground mt-1">
                  {returnsChartData.reduce((s, m) => s + m.מספר, 0)} תעודות
                </p>
              </div>
              <div className="bg-orange-100 rounded-lg p-2">
                <ReceiptText className="w-5 h-5 text-orange-500" />
              </div>
            </div>
            <div className="mt-2">
              {(() => {
                const monthIdx = new Date().getMonth();
                const currentMonthData = returnsChartData[monthIdx];
                if (!currentMonthData || currentMonthData.מספר === 0) return null;
                return (
                  <div className="flex items-center justify-between gap-2">
                    <span className="text-xs text-muted-foreground">חודש נוכחי</span>
                    <span className="text-xs font-semibold text-orange-700">
                      {fmtILS(currentMonthData.ערך)}
                      <span className="text-muted-foreground font-normal mr-1">({currentMonthData.מספר} תע׳)</span>
                    </span>
                  </div>
                );
              })()}
            </div>
          </div>
        </div>

        {/* Calibration Alerts */}
        <Card dir="rtl">
          <CardHeader>
            <div className="flex items-center justify-between flex-wrap gap-2">
              <CardTitle className="flex items-center gap-2">
                התראות כיול
                <span className="text-sm font-normal text-muted-foreground">
                  ({monthlyAlertsMap.reduce((s, g) => s + countAlerts(g.counts, alertsLocation, alertsType), 0).toLocaleString()} מכשירים)
                </span>
              </CardTitle>
              <div className="flex items-center gap-2 flex-wrap">
                {/* פנים / חוץ filter */}
                <div className="flex rounded-lg border overflow-hidden text-xs">
                  {(['all', 'internal', 'external', 'subcontractor'] as const).map(loc => (
                    <button
                      key={loc}
                      className={`px-3 py-1.5 transition-colors ${alertsLocation === loc ? 'bg-blue-600 text-white' : 'bg-background hover:bg-muted'}`}
                      onClick={() => setAlertsLocation(loc)}
                    >
                      {loc === 'all' ? 'הכל' : loc === 'internal' ? 'פנים' : loc === 'external' ? 'חוץ' : 'קבלנים'}
                    </button>
                  ))}
                </div>
                {/* Agent filter for calibration alerts */}
                <Select value={alertsAgent} onValueChange={setAlertsAgent}>
                  <SelectTrigger className="w-36 h-7 text-xs">
                    <SelectValue placeholder="כל הסוכנים" />
                  </SelectTrigger>
                  <SelectContent dir="rtl">
                    <SelectItem value="all">כל הסוכנים</SelectItem>
                    {['ורד גנון','ורד לב','דברת לוי','יונת בן יוסף','קרן שרעבי','אופיר בסביץ','רקפת חי','לילך שאוט'].map(a => (
                      <SelectItem key={a} value={a}>{a}</SelectItem>
                    ))}
                  </SelectContent>
                </Select>
                {/* Month / Customer view */}
                <div className="flex rounded-lg border overflow-hidden text-xs">
                  <button
                    className={`px-3 py-1.5 transition-colors ${alertsView === 'month' ? 'bg-primary text-primary-foreground' : 'bg-background hover:bg-muted'}`}
                    onClick={() => setAlertsView('month')}
                  >
                    לפי חודש
                  </button>
                  <button
                    className={`px-3 py-1.5 transition-colors ${alertsView === 'customer' ? 'bg-primary text-primary-foreground' : 'bg-background hover:bg-muted'}`}
                    onClick={() => setAlertsView('customer')}
                  >
                    לפי לקוח
                  </button>
                </div>
              </div>
            </div>
            <div className="flex items-center justify-between flex-wrap gap-2 mt-1">
              <CardDescription>מכשירים שפג תוקף הכיול שלהם או שתוקפם יפוג בקרוב</CardDescription>
              {monthlyAlertsMap.length > 0 && (() => {
                // כל התגיות נספרות מאותו חלון שהכותרת והגרף מציגים, ולכן הן מסתכמות אליו.
                const all = monthlyAlertsMap.flatMap(g => g.counts);
                const totalAlerts        = countAlerts(all, 'all', alertsType);
                const internalCount      = countAlerts(all, 'internal', alertsType);
                const externalCount      = countAlerts(all, 'external', alertsType);
                const subcontractorCount = countAlerts(all, 'subcontractor', alertsType);
                const internalPct = totalAlerts > 0 ? Math.round((internalCount / totalAlerts) * 100) : 0;
                const externalPct = totalAlerts > 0 ? Math.round((externalCount / totalAlerts) * 100) : 0;
                const subcontractorPct = totalAlerts > 0 ? Math.round((subcontractorCount / totalAlerts) * 100) : 0;
                const overdueCount  = countAlerts(all, alertsLocation, 'overdue');
                const upcomingCount = countAlerts(all, alertsLocation, 'upcoming');
                return (
                  <div className="flex items-center gap-2 text-xs flex-wrap" data-testid="alerts-location-split">
                    <button
                      className={`flex items-center gap-1 px-2 py-1 rounded-full border transition-colors ${alertsLocation === 'internal' ? 'bg-blue-100 border-blue-300 text-blue-700 font-semibold' : 'bg-muted/50 border-transparent text-muted-foreground hover:bg-muted'}`}
                      onClick={() => setAlertsLocation(alertsLocation === 'internal' ? 'all' : 'internal')}
                      data-testid="alerts-split-internal"
                    >
                      <span className="w-2 h-2 rounded-full bg-blue-500 flex-shrink-0" />
                      <span>פנים: {internalCount}</span>
                      <span className="opacity-60">({internalPct}%)</span>
                    </button>
                    <button
                      className={`flex items-center gap-1 px-2 py-1 rounded-full border transition-colors ${alertsLocation === 'external' ? 'bg-orange-100 border-orange-300 text-orange-700 font-semibold' : 'bg-muted/50 border-transparent text-muted-foreground hover:bg-muted'}`}
                      onClick={() => setAlertsLocation(alertsLocation === 'external' ? 'all' : 'external')}
                      data-testid="alerts-split-external"
                    >
                      <span className="w-2 h-2 rounded-full bg-orange-400 flex-shrink-0" />
                      <span>חוץ: {externalCount}</span>
                      <span className="opacity-60">({externalPct}%)</span>
                    </button>
                    <button
                      className={`flex items-center gap-1 px-2 py-1 rounded-full border transition-colors ${alertsLocation === 'subcontractor' ? 'bg-purple-100 border-purple-300 text-purple-700 font-semibold' : 'bg-muted/50 border-transparent text-muted-foreground hover:bg-muted'}`}
                      onClick={() => setAlertsLocation(alertsLocation === 'subcontractor' ? 'all' : 'subcontractor')}
                      data-testid="alerts-split-subcontractor"
                    >
                      <span className="w-2 h-2 rounded-full bg-purple-500 flex-shrink-0" />
                      <span>קבלנים: {subcontractorCount}</span>
                      <span className="opacity-60">({subcontractorPct}%)</span>
                    </button>
                    <button
                      className={`flex items-center gap-1 px-2 py-1 rounded-full border transition-colors ${alertsType === 'overdue' ? 'bg-red-100 border-red-300 text-red-700 font-semibold' : 'bg-muted/50 border-transparent text-muted-foreground hover:bg-muted'}`}
                      onClick={() => setAlertsType(alertsType === 'overdue' ? 'all' : 'overdue')}
                      data-testid="alerts-split-overdue"
                    >
                      <span className="w-2 h-2 rounded-full bg-red-500 flex-shrink-0" />
                      <span>באיחור: {overdueCount}</span>
                    </button>
                    <button
                      className={`flex items-center gap-1 px-2 py-1 rounded-full border transition-colors ${alertsType === 'upcoming' ? 'bg-amber-100 border-amber-300 text-amber-700 font-semibold' : 'bg-muted/50 border-transparent text-muted-foreground hover:bg-muted'}`}
                      onClick={() => setAlertsType(alertsType === 'upcoming' ? 'all' : 'upcoming')}
                      data-testid="alerts-split-upcoming"
                    >
                      <span className="w-2 h-2 rounded-full bg-amber-400 flex-shrink-0" />
                      <span>בקרוב: {upcomingCount}</span>
                    </button>
                  </div>
                );
              })()}
            </div>
          </CardHeader>
          <CardContent>
            {alertsView === 'month' ? (
              <>
                {calLoadChartData.length > 0 && (
                  <div className="mb-3" data-testid="cal-load-chart">
                    <div className="flex items-center gap-4 mb-1 justify-between">
                      <div className="flex items-center gap-1">
                        <TooltipProvider>
                          <Tooltip>
                            <TooltipTrigger asChild>
                              <Button
                                variant="ghost"
                                size="icon"
                                className="h-6 w-6"
                                disabled={isExporting}
                                onClick={() => handleExportChart('png')}
                                data-testid="export-chart-png"
                              >
                                {isExporting ? <Loader2 className="w-3 h-3 animate-spin" /> : <Download className="w-3 h-3" />}
                              </Button>
                            </TooltipTrigger>
                            <TooltipContent side="bottom">
                              <p>ייצוא כ-PNG</p>
                            </TooltipContent>
                          </Tooltip>
                        </TooltipProvider>
                        <TooltipProvider>
                          <Tooltip>
                            <TooltipTrigger asChild>
                              <Button
                                variant="ghost"
                                size="sm"
                                className="h-6 px-2 text-xs"
                                disabled={isExporting}
                                onClick={() => handleExportChart('pdf')}
                                data-testid="export-chart-pdf"
                              >
                                PDF
                              </Button>
                            </TooltipTrigger>
                            <TooltipContent side="bottom">
                              <p>ייצוא כ-PDF</p>
                            </TooltipContent>
                          </Tooltip>
                        </TooltipProvider>
                      </div>
                      <div className="flex items-center gap-4 text-xs text-muted-foreground">
                        <span className="flex items-center gap-1"><span className="inline-block w-3 h-3 rounded-sm bg-blue-500" />פנים</span>
                        <span className="flex items-center gap-1"><span className="inline-block w-3 h-3 rounded-sm bg-orange-400" />חוץ</span>
                      </div>
                    </div>
                    <div ref={calChartRef} className="bg-background p-1 rounded">
                    <ResponsiveContainer width="100%" height={120}>
                      <BarChart
                        data={calLoadChartData}
                        margin={{ top: 0, right: 4, left: -28, bottom: 0 }}
                        onClick={handleCalBarClick}
                        style={{ cursor: 'pointer' }}
                      >
                        <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="hsl(var(--border))" />
                        <XAxis dataKey="label" tick={{ fontSize: 10, fill: 'hsl(var(--muted-foreground))' }} tickLine={false} axisLine={false} />
                        <YAxis tick={{ fontSize: 10, fill: 'hsl(var(--muted-foreground))' }} tickLine={false} axisLine={false} allowDecimals={false} />
                        <RechartsTooltip
                          cursor={{ fill: 'hsl(var(--muted))', opacity: 0.5 }}
                          contentStyle={{ fontSize: 12, borderRadius: 8, border: '1px solid hsl(var(--border))' }}
                          formatter={(value: number, name: string) => [value, name === 'internal' ? 'פנים' : 'חוץ']}
                        />
                        <Bar dataKey="internal" stackId="loc" radius={[0, 0, 0, 0]} maxBarSize={32}>
                          {calLoadChartData.map((entry, index) => (
                            <Cell key={`internal-${index}`} fill={entry.isAboveAvg ? '#1d4ed8' : '#3b82f6'} />
                          ))}
                        </Bar>
                        <Bar dataKey="external" stackId="loc" radius={[3, 3, 0, 0]} maxBarSize={32}>
                          {calLoadChartData.map((entry, index) => (
                            <Cell key={`external-${index}`} fill={entry.isAboveAvg ? '#c2410c' : '#fb923c'} />
                          ))}
                        </Bar>
                        {calLoadAvg > 0 && (
                          <ReferenceLine
                            y={calLoadAvg}
                            stroke="#64748b"
                            strokeDasharray="4 3"
                            strokeWidth={1.5}
                            label={{ value: `ממוצע: ${Math.round(calLoadAvg)}`, position: 'insideTopRight', fontSize: 10, fill: '#64748b', dy: -4 }}
                          />
                        )}
                      </BarChart>
                    </ResponsiveContainer>
                    </div>
                  </div>
                )}
                <ScrollArea className="h-[380px]">
                {monthlyAlertsMap.length === 0 ? (
                  <div className="flex flex-col items-center justify-center h-[200px] text-muted-foreground">
                    <AlertTriangle className="w-12 h-12 mb-3 opacity-30" />
                    <p>אין התראות פעילות</p>
                  </div>
                ) : (
                  <div className="space-y-2 pl-1">
                    {monthlyAlertsMap.map((group) => {
                      const shownCount = countAlerts(group.counts, alertsLocation, alertsType);
                      if (shownCount === 0) return null;
                      const isOpen = expandedAlertMonths.has(group.key);
                      const devKey = `${group.key}|${alertsLocation}|${alertsType}`;
                      const devices = monthDevices[devKey];
                      const toggle = () => {
                        setExpandedAlertMonths(prev => {
                          const next = new Set(prev);
                          isOpen ? next.delete(group.key) : next.add(group.key);
                          return next;
                        });
                        if (!isOpen && !devices) loadMonthDevices(group.key, alertsLocation, alertsType);
                      };
                      const rowBg = group.isPast
                        ? 'bg-red-50 border-red-200 hover:bg-red-100/70'
                        : 'bg-amber-50 border-amber-200 hover:bg-amber-100/70';
                      const badgeBg = group.isPast ? 'bg-red-100 text-red-700' : 'bg-amber-100 text-amber-700';
                      const filteredError = countAlerts(group.counts, alertsLocation, 'overdue');
                      const filteredWarning = countAlerts(group.counts, alertsLocation, 'upcoming');
                      return (
                        <div
                          key={group.key}
                          className="rounded-lg border overflow-hidden"
                          ref={(el) => { if (el) monthGroupRefs.current.set(group.key, el); else monthGroupRefs.current.delete(group.key); }}
                        >
                          {/* Month header row */}
                          <button
                            className={`w-full flex items-center justify-between px-4 py-3 transition-colors ${rowBg}`}
                            onClick={toggle}
                          >
                            <div className="flex items-center gap-2">
                              <span className={`text-xs font-semibold px-2 py-0.5 rounded-full ${badgeBg}`}>
                                {shownCount.toLocaleString()}
                              </span>
                              {filteredError > 0 && (
                                <span className="text-xs text-red-600 font-medium">{filteredError} באיחור</span>
                              )}
                              {filteredWarning > 0 && (
                                <span className="text-xs text-amber-600 font-medium">{filteredWarning} בקרוב</span>
                              )}
                            </div>
                            <div className="flex items-center gap-2">
                              <span className="font-semibold text-sm">{group.monthLabel}</span>
                              <span className="text-muted-foreground text-sm">{isOpen ? '▲' : '▼'}</span>
                            </div>
                          </button>
                          {/* Expanded device list */}
                          {isOpen && (() => {
                            if (!devices || devices.loading) {
                              return <div className="px-4 py-4 text-xs text-muted-foreground text-center">טוען מכשירים…</div>;
                            }
                            const byCustomer = new Map<string, any[]>();
                            devices.rows.forEach(entry => {
                              if (!byCustomer.has(entry.customerId)) byCustomer.set(entry.customerId, []);
                              byCustomer.get(entry.customerId)!.push(entry);
                            });
                            return (
                              <div className="divide-y divide-border">
                                {devices.truncated && (
                                  <div className="px-4 py-1.5 text-[11px] text-amber-700 bg-amber-50">
                                    מוצגים {devices.rows.length.toLocaleString()} מתוך {devices.total.toLocaleString()} מכשירים
                                  </div>
                                )}
                                {Array.from(byCustomer.entries()).map(([custId, entries]) => (
                                  <div key={custId}>
                                    <div
                                      className="flex items-center justify-between px-4 py-1.5 bg-muted/40 cursor-pointer hover:bg-muted/60 transition-colors"
                                      onClick={() => window.location.href = `/dashboard?customer=${custId}`}
                                    >
                                      <span className="text-[10px] bg-muted px-1.5 py-0.5 rounded text-muted-foreground">{entries.length} מכשירים</span>
                                      <span className="text-xs font-semibold text-foreground">{entries[0].customerName}</span>
                                    </div>
                                    {entries.map((entry, idx) => (
                                      <div
                                        key={idx}
                                        className="flex items-center justify-between px-6 py-2 bg-background hover:bg-muted/40 transition-colors cursor-pointer text-sm"
                                        onClick={() => window.location.href = `/dashboard?customer=${entry.customerId}`}
                                      >
                                        <div className="flex items-center gap-2">
                                          <span className={`w-2 h-2 rounded-full flex-shrink-0 ${entry.type === 'error' ? 'bg-red-500' : 'bg-amber-400'}`} />
                                          <span className="text-xs text-muted-foreground font-mono">{entry.serialNo}</span>
                                        </div>
                                        <div className="text-right flex-1 mx-3 min-w-0">
                                          <p className="font-medium text-xs truncate">{entry.deviceName}</p>
                                        </div>
                                        <div className="text-left flex-shrink-0">
                                          <p className="text-xs font-mono text-muted-foreground">{entry.nextCalDate}</p>
                                        </div>
                                      </div>
                                    ))}
                                  </div>
                                ))}
                              </div>
                            );
                          })()}
                        </div>
                      );
                    })}
                  </div>
                )}
              </ScrollArea>
              </>
            ) : (
              <ScrollArea className="h-[380px]">
                {customersWithAlerts.length > 0 ? (
                  <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-3">
                    {customersWithAlerts.map((customer) => (
                      <div
                        key={customer.id}
                        className={`p-4 border rounded-lg transition-colors cursor-pointer ${alertsType === 'upcoming' ? 'bg-amber-50/50 border-amber-200 hover:bg-amber-100/50' : 'bg-red-50/50 border-red-200 hover:bg-red-100/50'}`}
                        onClick={() => window.location.href = `/dashboard?customer=${customer.id}`}
                        data-testid={`customer-alert-card-${customer.id}`}
                      >
                        <div className="flex items-center justify-between flex-row-reverse">
                          <div className="text-right">
                            <p className="font-medium text-sm">{customer.companyName}</p>
                            <p className="text-xs text-muted-foreground">{customer.hp}</p>
                          </div>
                          <div className={`px-2 py-1 rounded-full text-sm font-bold ${alertsType === 'upcoming' ? 'bg-amber-100 text-amber-700' : 'bg-red-100 text-red-700'}`}>
                            {customer.deviceInventory?.outForCalibration || 0}
                          </div>
                        </div>
                        <div className="mt-2 text-xs text-muted-foreground text-right">
                          {alertsType === 'upcoming' ? 'מכשירים בקרוב' : alertsType === 'overdue' ? 'מכשירים באיחור' : 'מכשירים עם התראה'}
                        </div>
                      </div>
                    ))}
                  </div>
                ) : (
                  <div className="flex flex-col items-center justify-center h-[200px] text-muted-foreground">
                    <AlertTriangle className="w-12 h-12 mb-3 opacity-30" />
                    <p>אין התראות פעילות</p>
                  </div>
                )}
              </ScrollArea>
            )}
          </CardContent>
        </Card>

        {/* Monthly Returns Chart + Table */}
        <Card className="text-right" dir="rtl">
          <CardHeader>
            <div className="flex items-start justify-between gap-4">
              <div>
                <CardTitle className="flex items-center gap-2">
                  תעודות החזרה לפי חודש
                  <span className="inline-flex items-center gap-1 text-xs bg-orange-50 border border-orange-200 text-orange-700 rounded-full px-2 py-0.5 font-medium">
                    <ReceiptText className="w-3 h-3" />
                    תעודות החזרה
                  </span>
                </CardTitle>
                <CardDescription>
                  סכום ומספר תעודות החזרה לפי חודש בשנת {selectedYear}
                  {selectedAgent !== 'all' ? ` — ${selectedAgent}` : ' — כל החברה'}
                </CardDescription>
              </div>
              <div className="flex items-center gap-2 text-xs text-muted-foreground">
                <span className="font-bold text-orange-600">₪{returnsChartData.reduce((s, m) => s + m.ערך, 0).toLocaleString()}</span>
                <Badge variant="secondary">{returnsChartData.reduce((s, m) => s + m.מספר, 0)} תעודות</Badge>
              </div>
            </div>
          </CardHeader>
          <CardContent>
            {/* Returns bar chart */}
            <div className="h-[260px] mb-6">
              <ResponsiveContainer width="100%" height="100%">
                <BarChart data={returnsChartData} margin={{ top: 10, right: 10, left: 10, bottom: 5 }}>
                  <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="hsl(var(--border))" />
                  <XAxis dataKey="name" stroke="hsl(var(--muted-foreground))" fontSize={11} />
                  <YAxis
                    stroke="hsl(var(--muted-foreground))"
                    fontSize={11}
                    tickFormatter={(v) => fmtILS(v)}
                    width={55}
                  />
                  <RechartsTooltip
                    cursor={{ fill: 'hsl(var(--muted)/0.4)' }}
                    formatter={(value: number, name: string) => [
                      name === 'ערך' ? `₪${value.toLocaleString()}` : `${value} תעודות`,
                      name === 'ערך' ? 'סכום' : 'מספר תעודות'
                    ]}
                    contentStyle={{ direction: 'rtl', textAlign: 'right', backgroundColor: 'white', border: '1px solid #e5e7eb', borderRadius: '8px', boxShadow: '0 4px 12px rgba(0,0,0,0.15)' }}
                    labelStyle={{ fontWeight: 'bold', color: '#1f2937' }}
                  />
                  <Bar dataKey="ערך" radius={[4, 4, 0, 0]} barSize={28}>
                    {returnsChartData.map((entry, index) => (
                      <Cell
                        key={`ret-cell-${index}`}
                        fill={entry.ערך === 0 ? '#e2e8f0' : '#f97316'}
                        opacity={entry.ערך === 0 ? 0.5 : 1}
                      />
                    ))}
                  </Bar>
                </BarChart>
              </ResponsiveContainer>
            </div>

            {/* Returns table */}
            <div className="border-t pt-5">
              <div className="flex items-center justify-between mb-3">
                <h3 className="font-semibold text-sm flex items-center gap-2">
                  <ReceiptText className="w-4 h-4 text-orange-500" />
                  פירוט חודשי — תעודות החזרה
                </h3>
                <div className="flex items-center gap-2 text-xs text-muted-foreground">
                  <span>סה"כ: <span className="font-bold text-orange-600">₪{returnsChartData.reduce((s, m) => s + m.ערך, 0).toLocaleString()}</span></span>
                  <span>·</span>
                  <Badge variant="secondary" className="text-xs">{returnsChartData.reduce((s, m) => s + m.מספר, 0)} תעודות</Badge>
                </div>
              </div>
              <div className="border rounded-lg overflow-hidden">
                <table className="w-full text-sm">
                  <thead className="bg-orange-50/60">
                    <tr>
                      <th className="text-right py-2 px-3 font-medium text-muted-foreground">חודש</th>
                      <th className="text-left py-2 px-3 font-medium text-muted-foreground">מספר תעודות</th>
                      <th className="text-left py-2 px-3 font-medium text-muted-foreground">סכום</th>
                      <th className="text-left py-2 px-3 font-medium text-muted-foreground">ממוצע לתעודה</th>
                    </tr>
                  </thead>
                  <tbody>
                    {returnsChartData.map((row, idx) => (
                      <tr key={idx} className={`${idx % 2 === 0 ? 'bg-background' : 'bg-muted/20'} ${row.מספר > 0 ? '' : 'opacity-40'}`}>
                        <td className="py-1.5 px-3 font-medium text-xs">{row.name}</td>
                        <td className="py-1.5 px-3 text-left text-xs">
                          {row.מספר > 0 ? (
                            <Badge variant="secondary" className="text-xs font-mono">{row.מספר}</Badge>
                          ) : '—'}
                        </td>
                        <td className="py-1.5 px-3 text-left font-mono text-xs text-orange-700">
                          {row.ערך > 0 ? `₪${row.ערך.toLocaleString()}` : '—'}
                        </td>
                        <td className="py-1.5 px-3 text-left font-mono text-xs text-muted-foreground">
                          {row.מספר > 0 ? `₪${Math.round(row.ערך / row.מספר).toLocaleString()}` : '—'}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                  <tfoot className="bg-orange-50 border-t-2 border-orange-200">
                    <tr>
                      <td className="py-2 px-3 font-bold text-sm">סה"כ</td>
                      <td className="py-2 px-3 text-left font-bold text-sm">
                        {returnsChartData.reduce((s, m) => s + m.מספר, 0)} תעודות
                      </td>
                      <td className="py-2 px-3 text-left font-bold font-mono text-sm text-orange-700">
                        ₪{returnsChartData.reduce((s, m) => s + m.ערך, 0).toLocaleString()}
                      </td>
                      <td className="py-2 px-3 text-left font-mono text-xs text-muted-foreground">
                        {(() => {
                          const totalCount = returnsChartData.reduce((s, m) => s + m.מספר, 0);
                          const totalVal = returnsChartData.reduce((s, m) => s + m.ערך, 0);
                          return totalCount > 0 ? `₪${Math.round(totalVal / totalCount).toLocaleString()}` : '—';
                        })()}
                      </td>
                    </tr>
                  </tfoot>
                </table>
              </div>
            </div>
          </CardContent>
        </Card>

        {/* Activity Drop Anomaly Alerts — removed (page is returns-only) */}
        {false && (
          <Card dir="rtl" className="border-orange-200 bg-gradient-to-br from-orange-50/60 to-amber-50/40">
            <CardHeader>
              <div className="flex items-center justify-between flex-wrap gap-3">
                <CardTitle className="flex items-center gap-2 text-orange-800">
                  <TrendingDown className="w-5 h-5 text-orange-600" />
                  התראות ירידה חריגה בפעילות
                  <Badge className="bg-orange-100 text-orange-700 border-orange-300 text-xs font-semibold ml-1">
                    {activityDropAlerts.length} לקוחות
                  </Badge>
                </CardTitle>
                {/* Threshold control */}
                <div className="flex items-center gap-3 bg-orange-50 border border-orange-200 rounded-lg px-3 py-1.5" dir="rtl">
                  <span className="text-xs text-muted-foreground whitespace-nowrap">סף ירידה מינימלי:</span>
                  <input
                    type="range"
                    min={10}
                    max={90}
                    step={5}
                    value={activityDropThreshold}
                    onChange={e => setActivityDropThreshold(Number(e.target.value))}
                    className="w-28 accent-orange-500 cursor-pointer"
                  />
                  <span className="text-sm font-bold text-orange-700 w-9 text-center">{activityDropThreshold}%</span>
                  <button
                    className="text-[10px] text-muted-foreground hover:text-orange-700 transition-colors underline underline-offset-2"
                    onClick={() => setActivityDropThreshold(40)}
                  >
                    איפוס
                  </button>
                </div>
              </div>
              <div className="flex items-center gap-2 mt-1 flex-wrap" dir="rtl">
                <input
                  type="text"
                  value={alertSearch}
                  onChange={e => setAlertSearch(e.target.value)}
                  placeholder="חיפוש לפי שם לקוח או מספר..."
                  className="flex-1 min-w-[160px] text-sm border border-orange-200 rounded-lg px-3 py-1.5 bg-white/70 focus:outline-none focus:ring-2 focus:ring-orange-300 placeholder:text-muted-foreground/60"
                  dir="rtl"
                />
                <Select value={activityDropAgentFilter} onValueChange={setActivityDropAgentFilter}>
                  <SelectTrigger className="w-36 h-8 text-xs border-orange-200 bg-white/70 focus:ring-orange-300" dir="rtl">
                    <SelectValue placeholder="כל הסוכנים" />
                  </SelectTrigger>
                  <SelectContent dir="rtl">
                    <SelectItem value="all">כל הסוכנים</SelectItem>
                    {uniqueAgents.map((a: string) => (
                      <SelectItem key={a} value={a}>{a}</SelectItem>
                    ))}
                  </SelectContent>
                </Select>
                {alertSearch && (
                  <button
                    onClick={() => setAlertSearch('')}
                    className="text-xs text-muted-foreground hover:text-orange-700 transition-colors px-2"
                  >✕</button>
                )}
              </div>
              <div className="flex items-center gap-2 mt-2 flex-wrap" dir="rtl">
                <button
                  className={`text-xs px-3 py-1 rounded-full border transition-colors ${!activityDropCustomRange ? 'bg-orange-100 border-orange-300 text-orange-700 font-semibold' : 'bg-white/60 border-orange-200 text-muted-foreground hover:bg-orange-50'}`}
                  onClick={() => setActivityDropCustomRange(false)}
                >
                  3 חודשים אחרונים
                </button>
                <button
                  className={`text-xs px-3 py-1 rounded-full border transition-colors ${activityDropCustomRange ? 'bg-orange-100 border-orange-300 text-orange-700 font-semibold' : 'bg-white/60 border-orange-200 text-muted-foreground hover:bg-orange-50'}`}
                  onClick={() => setActivityDropCustomRange(true)}
                >
                  טווח מותאם
                </button>
                {activityDropCustomRange && (
                  <>
                    <input
                      type="month"
                      value={activityDropFromDate}
                      onChange={e => setActivityDropFromDate(e.target.value)}
                      className="text-xs border border-orange-200 rounded px-2 py-1 bg-white/70 focus:outline-none focus:ring-1 focus:ring-orange-300"
                    />
                    <span className="text-xs text-muted-foreground">עד</span>
                    <input
                      type="month"
                      value={activityDropToDate}
                      onChange={e => setActivityDropToDate(e.target.value)}
                      className="text-xs border border-orange-200 rounded px-2 py-1 bg-white/70 focus:outline-none focus:ring-1 focus:ring-orange-300"
                    />
                  </>
                )}
              </div>
              <CardDescription>השוואת 3 החודשים האחרונים מול אותה תקופה בשנה שעברה — לקוחות עם הכנסות שנתיות מעל 50,000 ₪ בשנה הקודמת</CardDescription>
            </CardHeader>
            <CardContent>
              <ScrollArea className="h-[380px]">
                <div className="space-y-3">
                  {activityDropAlerts.filter((c: any) => {
                    if (!alertSearch.trim()) return true;
                    const q = alertSearch.trim().toLowerCase();
                    return (c.companyName?.toLowerCase().includes(q) || String(c.hp ?? '').includes(q));
                  }).map((c: any) => {
                    const severity = c.dropPct >= 90 ? 'critical' : c.dropPct >= 75 ? 'high' : 'medium';
                    const severityColors = {
                      critical: { card: 'border-red-300 bg-red-50/60', badge: 'bg-red-100 text-red-700 border-red-300', pct: 'text-red-700', bar: 'bg-red-500' },
                      high:     { card: 'border-orange-300 bg-orange-50/60', badge: 'bg-orange-100 text-orange-700 border-orange-300', pct: 'text-orange-700', bar: 'bg-orange-500' },
                      medium:   { card: 'border-amber-300 bg-amber-50/40', badge: 'bg-amber-100 text-amber-700 border-amber-300', pct: 'text-amber-700', bar: 'bg-amber-400' },
                    }[severity];
                    const lastMonthLabel = c.lastActiveMonth
                      ? new Date(c.lastActiveMonth + '-01').toLocaleDateString('he-IL', { month: 'long', year: 'numeric' })
                      : '—';
                    return (
                      <div
                        key={c.id}
                        className={`rounded-xl border p-4 cursor-pointer hover:shadow-md transition-all ${severityColors.card}`}
                        onClick={() => window.location.href = `/dashboard?customer=${c.id}`}
                      >
                        <div className="flex items-start justify-between gap-3">
                          {/* Drop % badge */}
                          <div className={`flex-shrink-0 text-center rounded-lg px-3 py-2 border ${severityColors.badge}`} style={{ minWidth: '72px' }}>
                            <p className={`text-2xl font-black leading-none ${severityColors.pct}`}>↓{c.dropPct}%</p>
                            <p className="text-[10px] font-medium mt-0.5 opacity-70">ירידה</p>
                          </div>

                          {/* Company info */}
                          <div className="flex-1 min-w-0">
                            <div className="flex items-baseline gap-2 min-w-0" dir="rtl">
                              <p className="font-bold text-sm truncate">{c.companyName}</p>
                              <span className="text-[10px] text-muted-foreground font-mono shrink-0" dir="ltr">{c.hp}</span>
                            </div>
                            {c.agentName && <p className="text-xs text-muted-foreground">{c.agentName}</p>}

                            {/* Revenue bar comparison — totals (×3) */}
                            <div className="mt-2 space-y-1" dir="rtl">
                              {(() => {
                                const maxVal = Math.max(c.splyTotalRevenue, c.recentTotalRevenue, 1);
                                const fmt = (v: number) => v >= 1000
                                  ? fmtILS(v)
                                  : `₪${v.toLocaleString()}`;
                                return (
                                  <>
                                    <div className="flex items-center gap-2">
                                      <span className="text-[10px] text-muted-foreground w-20 shrink-0 text-right leading-tight">{c.recent3Label}</span>
                                      <div className="flex-1 h-2 bg-gray-200 rounded-full overflow-hidden" dir="ltr">
                                        <div className={`h-full rounded-full ${severityColors.bar}`} style={{ width: `${Math.min((c.recentTotalRevenue / maxVal) * 100, 100)}%` }} />
                                      </div>
                                      <span className="text-[11px] font-semibold w-14 text-left">{fmt(c.recentTotalRevenue)}</span>
                                    </div>
                                    <div className="flex items-center gap-2">
                                      <span className="text-[10px] text-muted-foreground w-20 shrink-0 text-right leading-tight">{c.splyPeriodLabel}</span>
                                      <div className="flex-1 h-2 bg-gray-200 rounded-full overflow-hidden" dir="ltr">
                                        <div className="h-full rounded-full bg-blue-300" style={{ width: `${Math.min((c.splyTotalRevenue / maxVal) * 100, 100)}%` }} />
                                      </div>
                                      <span className="text-[11px] font-semibold w-14 text-left text-blue-600">{fmt(c.splyTotalRevenue)}</span>
                                    </div>
                                  </>
                                );
                              })()}
                            </div>
                          </div>
                        </div>
                      </div>
                    );
                  })}
                </div>
              </ScrollArea>
            </CardContent>
          </Card>
        )}
      </motion.div>

      {/* Return Document Detail Dialog */}
      <Dialog open={!!selectedDoc} onOpenChange={(open) => { if (!open) setSelectedDoc(null); }}>
        <DialogContent className="max-w-md" dir="rtl">
          <DialogHeader>
            <DialogTitle className="flex items-center gap-2 text-right">
              <ReceiptText className="w-5 h-5 text-blue-500" />
              פרטי תעודת החזרה
            </DialogTitle>
          </DialogHeader>
          {selectedDoc && (
            <div className="space-y-4 text-right">
              <div className="bg-blue-50 rounded-lg p-4 border border-blue-100 space-y-3" dir="rtl">
                <div className="flex justify-between items-center">
                  <span className="text-sm text-muted-foreground">לקוח</span>
                  <span className="font-bold text-sm">{selectedDoc.customerName}</span>
                </div>
                <div className="flex justify-between items-center">
                  <span className="text-sm text-muted-foreground">ח.פ.</span>
                  <span className="font-mono text-sm">{selectedDoc.customerHp}</span>
                </div>
                <div className="flex justify-between items-center">
                  <span className="text-sm text-muted-foreground">מספר תעודה</span>
                  <span className="font-mono font-semibold">{selectedDoc.docNumber}</span>
                </div>
                <div className="flex justify-between items-center">
                  <span className="text-sm text-muted-foreground">תאריך</span>
                  <span className="text-sm">{selectedDoc.openDate}</span>
                </div>
                <div className="flex justify-between items-center border-t border-blue-200 pt-3">
                  <span className="text-sm text-muted-foreground">סכום</span>
                  <span className="font-bold text-xl text-blue-600">₪{selectedDoc.totalPrice.toLocaleString()}</span>
                </div>
              </div>
              <Button
                className="w-full"
                onClick={() => { window.location.href = `/dashboard?customer=${selectedDoc.customerId}`; }}
              >
                עבור לכרטיס הלקוח
                <ArrowLeft className="w-4 h-4 mr-2" />
              </Button>
            </div>
          )}
        </DialogContent>
      </Dialog>
    </DashboardLayout>
  );
}
