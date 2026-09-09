import React, { useState, useMemo, useEffect } from 'react';
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { useToast } from "@/hooks/use-toast";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Badge } from "@/components/ui/badge";
import { ScrollArea } from "@/components/ui/scroll-area";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger, DialogFooter } from "@/components/ui/dialog";
import { Calendar } from "@/components/ui/calendar";
import DashboardLayout from "@/components/layout/DashboardLayout";
import { 
  Target, 
  TrendingUp, 
  TrendingDown,
  Calendar as CalendarIcon,
  Plus,
  Trash2,
  Loader2,
  CheckCircle2,
  AlertCircle,
  Clock,
  ArrowRight,
  UserPlus,
  Wrench,
  Coins,
  Users,
  ArrowUpRight,
  ArrowDownRight,
  ChevronLeft,
  ChevronRight,
  FileText
} from "lucide-react";
import { 
  BarChart, 
  Bar, 
  XAxis, 
  YAxis, 
  CartesianGrid, 
  Tooltip, 
  ResponsiveContainer,
  ReferenceLine,
  Cell,
  LineChart,
  Line,
  Area,
  AreaChart,
  ComposedChart,
  Legend
} from 'recharts';
import { motion } from "framer-motion";
import { format, startOfMonth, endOfMonth, eachDayOfInterval, isSameDay, differenceInBusinessDays, addDays, isBefore, isAfter, startOfYear, endOfYear } from 'date-fns';
import { he } from 'date-fns/locale';

const DEFAULT_GROWTH_RATE = 0.06;

interface HolidayInfo {
  date: Date;
  name: string;
}

const HEBREW_HOLIDAYS_2024: HolidayInfo[] = [
  { date: new Date(2024, 2, 24), name: "פורים" },
  { date: new Date(2024, 3, 23), name: "פסח - יום א'" },
  { date: new Date(2024, 3, 24), name: "פסח - יום ב'" },
  { date: new Date(2024, 3, 25), name: "חול המועד פסח" },
  { date: new Date(2024, 3, 26), name: "חול המועד פסח" },
  { date: new Date(2024, 3, 27), name: "חול המועד פסח" },
  { date: new Date(2024, 3, 28), name: "חול המועד פסח" },
  { date: new Date(2024, 3, 29), name: "שביעי של פסח" },
  { date: new Date(2024, 3, 30), name: "אחרון של פסח" },
  { date: new Date(2024, 4, 13), name: "יום הזיכרון" },
  { date: new Date(2024, 4, 14), name: "יום העצמאות" },
  { date: new Date(2024, 5, 12), name: "שבועות" },
  { date: new Date(2024, 9, 3), name: "ראש השנה - יום א'" },
  { date: new Date(2024, 9, 4), name: "ראש השנה - יום ב'" },
  { date: new Date(2024, 9, 12), name: "יום כיפור" },
  { date: new Date(2024, 9, 17), name: "סוכות - יום א'" },
  { date: new Date(2024, 9, 18), name: "סוכות - יום ב'" },
  { date: new Date(2024, 9, 19), name: "חול המועד סוכות" },
  { date: new Date(2024, 9, 20), name: "חול המועד סוכות" },
  { date: new Date(2024, 9, 21), name: "חול המועד סוכות" },
  { date: new Date(2024, 9, 22), name: "חול המועד סוכות" },
  { date: new Date(2024, 9, 23), name: "חול המועד סוכות" },
  { date: new Date(2024, 9, 24), name: "שמיני עצרת / שמחת תורה" },
];

const HEBREW_HOLIDAYS_2025: HolidayInfo[] = [
  { date: new Date(2025, 2, 14), name: "פורים" },
  { date: new Date(2025, 3, 13), name: "פסח - יום א'" },
  { date: new Date(2025, 3, 14), name: "פסח - יום ב'" },
  { date: new Date(2025, 3, 15), name: "חול המועד פסח" },
  { date: new Date(2025, 3, 16), name: "חול המועד פסח" },
  { date: new Date(2025, 3, 17), name: "חול המועד פסח" },
  { date: new Date(2025, 3, 18), name: "חול המועד פסח" },
  { date: new Date(2025, 3, 19), name: "שביעי של פסח" },
  { date: new Date(2025, 3, 20), name: "אחרון של פסח" },
  { date: new Date(2025, 3, 30), name: "יום הזיכרון" },
  { date: new Date(2025, 4, 1), name: "יום העצמאות" },
  { date: new Date(2025, 5, 2), name: "שבועות" },
  { date: new Date(2025, 8, 23), name: "ראש השנה - יום א'" },
  { date: new Date(2025, 8, 24), name: "ראש השנה - יום ב'" },
  { date: new Date(2025, 9, 2), name: "יום כיפור" },
  { date: new Date(2025, 9, 7), name: "סוכות - יום א'" },
  { date: new Date(2025, 9, 8), name: "סוכות - יום ב'" },
  { date: new Date(2025, 9, 9), name: "חול המועד סוכות" },
  { date: new Date(2025, 9, 10), name: "חול המועד סוכות" },
  { date: new Date(2025, 9, 11), name: "חול המועד סוכות" },
  { date: new Date(2025, 9, 12), name: "חול המועד סוכות" },
  { date: new Date(2025, 9, 13), name: "חול המועד סוכות" },
  { date: new Date(2025, 9, 14), name: "שמיני עצרת / שמחת תורה" },
];

const HEBREW_HOLIDAYS_2026: HolidayInfo[] = [
  { date: new Date(2026, 2, 3), name: "פורים" },
  { date: new Date(2026, 3, 2), name: "פסח - יום א'" },
  { date: new Date(2026, 3, 3), name: "פסח - יום ב'" },
  { date: new Date(2026, 3, 4), name: "חול המועד פסח" },
  { date: new Date(2026, 3, 5), name: "חול המועד פסח" },
  { date: new Date(2026, 3, 6), name: "חול המועד פסח" },
  { date: new Date(2026, 3, 7), name: "חול המועד פסח" },
  { date: new Date(2026, 3, 8), name: "שביעי של פסח" },
  { date: new Date(2026, 3, 9), name: "אחרון של פסח" },
  { date: new Date(2026, 3, 21), name: "יום הזיכרון" },
  { date: new Date(2026, 3, 22), name: "יום העצמאות" },
  { date: new Date(2026, 4, 22), name: "שבועות" },
  { date: new Date(2026, 8, 12), name: "ראש השנה - יום א'" },
  { date: new Date(2026, 8, 13), name: "ראש השנה - יום ב'" },
  { date: new Date(2026, 8, 21), name: "יום כיפור" },
  { date: new Date(2026, 8, 26), name: "סוכות - יום א'" },
  { date: new Date(2026, 8, 27), name: "סוכות - יום ב'" },
  { date: new Date(2026, 8, 28), name: "חול המועד סוכות" },
  { date: new Date(2026, 8, 29), name: "חול המועד סוכות" },
  { date: new Date(2026, 8, 30), name: "חול המועד סוכות" },
  { date: new Date(2026, 9, 1), name: "חול המועד סוכות" },
  { date: new Date(2026, 9, 2), name: "חול המועד סוכות" },
  { date: new Date(2026, 9, 3), name: "שמיני עצרת / שמחת תורה" },
];

const ALL_HEBREW_HOLIDAYS: HolidayInfo[] = [...HEBREW_HOLIDAYS_2024, ...HEBREW_HOLIDAYS_2025, ...HEBREW_HOLIDAYS_2026];

function isHebrewHoliday(date: Date): boolean {
  return ALL_HEBREW_HOLIDAYS.some(h => isSameDay(h.date, date));
}

function getHolidaysForYear(year: number): HolidayInfo[] {
  if (year === 2024) return HEBREW_HOLIDAYS_2024;
  if (year === 2025) return HEBREW_HOLIDAYS_2025;
  if (year === 2026) return HEBREW_HOLIDAYS_2026;
  return [];
}

interface CompanyDayOff {
  id: string;
  date: string;
  reason: string;
}

// Manually-set monthly revenue targets (₪) for 2026. Index 0 = January … 11 = December.
// These override the growth/daily-rate computation for 2026 (the annual target becomes their sum).
const MANUAL_MONTHLY_TARGETS_2026: number[] = [
  2956688, // ינואר
  2672056, // פברואר
  3162523, // מרץ
  1972449, // אפריל
  2830916, // מאי
  2627561, // יוני
  3023079, // יולי
  2972763, // אוגוסט
  2014610, // ספטמבר
  2672366, // אוקטובר
  2945973, // נובמבר
  3245720, // דצמבר
];

interface MonthlyTarget {
  month: string;
  monthName: string;
  workingDays: number;
  targetRevenue: number;
  actualRevenue: number;
  dailyTarget: number;
  progress: number;
  status: 'on_track' | 'behind' | 'ahead' | 'completed';
  daysElapsed: number;
  expectedByNow: number;
  monthlyReturns: number;
  previousYearRevenue: number;
  yoyChange: number;
}

const MONTH_NAMES = ['ינואר', 'פברואר', 'מרץ', 'אפריל', 'מאי', 'יוני', 'יולי', 'אוגוסט', 'ספטמבר', 'אוקטובר', 'נובמבר', 'דצמבר'];

/**
 * Determines if a customer is "new" during a given selected year.
 *
 * A customer is "new" in year X if:
 * Their activation month (first purchase ever, or first purchase after 24+ months of inactivity)
 * falls within year X itself.
 *
 * This ensures each customer is counted as "new" in exactly one year.
 */
function getNewCustomerActivation(
  monthlyRevenue: Array<{ month: string; revenue: number; count: number }>,
  selectedYear: number
): { isNew: boolean; activationMonth: string | null } {
  const activeMonths = (monthlyRevenue || [])
    .filter(m => (m.revenue || 0) > 0 || (m.count || 0) > 0)
    .map(m => m.month)
    .sort();

  if (activeMonths.length === 0) return { isNew: false, activationMonth: null };

  const selectedYearStart = `${selectedYear}-01`;
  const selectedYearEnd = `${selectedYear}-12`;

  for (let i = 0; i < activeMonths.length; i++) {
    const month = activeMonths[i];
    const [y, mo] = month.split('-').map(Number);

    // Calculate cutoff: 24 months before this month
    const cutoffDate = new Date(y, mo - 1);
    cutoffDate.setMonth(cutoffDate.getMonth() - 24);
    const cutoffStr = `${cutoffDate.getFullYear()}-${String(cutoffDate.getMonth() + 1).padStart(2, '0')}`;

    // Is there any prior active month within the 24-month window?
    const hadPriorActivity = i > 0 && activeMonths[i - 1] >= cutoffStr;
    if (hadPriorActivity) continue; // Not an activation — continuous activity

    // This is an activation month — is it within the selected year?
    if (month >= selectedYearStart && month <= selectedYearEnd) {
      return { isNew: true, activationMonth: month };
    }
  }

  return { isNew: false, activationMonth: null };
}

export default function CompanyTargets() {
  const [selectedYear, setSelectedYear] = useState<number>(new Date().getFullYear());
  // Reset custom working days when year changes
  const handleYearChange = (year: number) => {
    setSelectedYear(year);
    setCustomWorkingDays(Array(12).fill(null));
  };
  const [showAddDayOff, setShowAddDayOff] = useState(false);
  const [selectedDates, setSelectedDates] = useState<Date[]>([]);
  const [dayOffReason, setDayOffReason] = useState('');
  const [calendarYear, setCalendarYear] = useState<number>(selectedYear);
  const [calendarMonth, setCalendarMonth] = useState<Date>(new Date(selectedYear, 0));
  const [customGrowthRate, setCustomGrowthRate] = useState<number>(() => {
    try {
      const saved = localStorage.getItem('qcc_growth_rate');
      return saved !== null ? parseFloat(saved) : DEFAULT_GROWTH_RATE * 100;
    } catch { return DEFAULT_GROWTH_RATE * 100; }
  });
  const [targetMode, setTargetMode] = useState<'growth' | 'daily'>('growth');
  const [dailyRate, setDailyRate] = useState<number>(5000);
  const [monthlyDailyRates, setMonthlyDailyRates] = useState<number[]>(Array(12).fill(5000));
  const [customWorkingDays, setCustomWorkingDays] = useState<(number | null)[]>(Array(12).fill(null));
  const [showTargetSettings, setShowTargetSettings] = useState(false);
  const [showNewCustomersDialog, setShowNewCustomersDialog] = useState(false);
  const [newCustomerSearch, setNewCustomerSearch] = useState("");
  const [newCustomersDialogTab, setNewCustomersDialogTab] = useState<'summary' | 'detail'>('summary');
  const [drillDownCard, setDrillDownCard] = useState<'annual' | 'ytd' | 'working-days' | 'daily-avg' | null>(null);
  const [selectedFilterMonth, setSelectedFilterMonth] = useState<number | null>(null);
  const [selectedMonthDrillDown, setSelectedMonthDrillDown] = useState<string | null>(null);
  const [monthDrillDownSearch, setMonthDrillDownSearch] = useState('');
  const [selectedAgent, setSelectedAgent] = useState<string>('all');
  const [chartViewMode, setChartViewMode] = useState<'current' | '3year'>('current');
  const queryClient = useQueryClient();
  const { toast } = useToast();

  const growthRate = customGrowthRate / 100;

  // Load growth rate from server on mount
  const { data: growthRateSetting } = useQuery<{ rate: number }>({
    queryKey: ['/api/settings/growth-rate'],
    queryFn: async () => {
      const res = await fetch('/api/settings/growth-rate');
      if (!res.ok) throw new Error('Failed to load growth rate');
      return res.json();
    },
  });

  useEffect(() => {
    if (growthRateSetting?.rate !== undefined) {
      setCustomGrowthRate(growthRateSetting.rate);
      try { localStorage.setItem('qcc_growth_rate', String(growthRateSetting.rate)); } catch {}
    }
    if ((growthRateSetting as any)?.mode) {
      setTargetMode((growthRateSetting as any).mode);
    }
    if ((growthRateSetting as any)?.dailyRate !== undefined) {
      setDailyRate((growthRateSetting as any).dailyRate);
    }
    if ((growthRateSetting as any)?.monthlyDailyRates?.length === 12) {
      setMonthlyDailyRates((growthRateSetting as any).monthlyDailyRates);
    } else if ((growthRateSetting as any)?.dailyRate !== undefined) {
      setMonthlyDailyRates(Array(12).fill((growthRateSetting as any).dailyRate));
    }
  }, [growthRateSetting]);

  // Save growth rate to server
  const saveGrowthRateMutation = useMutation({
    mutationFn: async () => {
      const body: any = { rate: customGrowthRate, mode: targetMode };
      if (targetMode === 'daily') {
        body.dailyRate = dailyRate;
        body.monthlyDailyRates = monthlyDailyRates;
      }
      const res = await fetch('/api/settings/growth-rate', {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
      });
      if (!res.ok) throw new Error('Failed to save growth rate');
      return res.json();
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['/api/settings/growth-rate'] });
      try { localStorage.setItem('qcc_growth_rate', String(customGrowthRate)); } catch {}
      const desc = targetMode === 'daily'
        ? `תחשיב יומי: ₪${dailyRate.toLocaleString()} ליום`
        : `${customGrowthRate.toFixed(0)}% צמיחה שנתית`;
      toast({ title: 'יעד הצמיחה נשמר', description: desc });
      setShowTargetSettings(false);
    },
    onError: () => {
      toast({ title: 'שגיאה בשמירה', description: 'לא ניתן לשמור את יעד הצמיחה', variant: 'destructive' });
    },
  });

  const { data: financialsDataRaw } = useQuery<any>({
    queryKey: ['/api/customers/list'],
    queryFn: async () => {
      const response = await fetch('/api/customers/list');
      if (!response.ok) throw new Error('Failed to fetch');
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

  const { data: agentYearlyData } = useQuery<{ agentFinancials: Record<string, any[]> }>({
    queryKey: ['/api/agents/yearly-financials'],
    queryFn: async () => {
      const response = await fetch('/api/agents/yearly-financials');
      if (!response.ok) throw new Error('Failed to fetch agent financials');
      return response.json();
    }
  });

  // Monthly revenue per agent from server (accurate SQL aggregation)
  const { data: agentMonthlyData } = useQuery<{
    year: number;
    agentMonthly: Record<string, { month: string; revenue: number; count: number }[]>;
    companyMonthly: { month: string; revenue: number; count: number }[];
  }>({
    queryKey: ['/api/agents/monthly-revenue', selectedYear],
    queryFn: async () => {
      const response = await fetch(`/api/agents/monthly-revenue?year=${selectedYear}`);
      if (!response.ok) throw new Error('Failed to fetch agent monthly revenue');
      return response.json();
    }
  });

  // Fetch monthly revenue for previous 2 years for 3-year comparison
  const { data: agentMonthlyDataPrev1 } = useQuery<{
    year: number;
    companyMonthly: { month: string; revenue: number; count: number }[];
  }>({
    queryKey: ['/api/agents/monthly-revenue', selectedYear - 1],
    queryFn: async () => {
      const response = await fetch(`/api/agents/monthly-revenue?year=${selectedYear - 1}`);
      if (!response.ok) throw new Error('Failed to fetch prev year monthly revenue');
      return response.json();
    },
    enabled: chartViewMode === '3year'
  });

  const { data: agentMonthlyDataPrev2 } = useQuery<{
    year: number;
    companyMonthly: { month: string; revenue: number; count: number }[];
  }>({
    queryKey: ['/api/agents/monthly-revenue', selectedYear - 2],
    queryFn: async () => {
      const response = await fetch(`/api/agents/monthly-revenue?year=${selectedYear - 2}`);
      if (!response.ok) throw new Error('Failed to fetch prev 2 year monthly revenue');
      return response.json();
    },
    enabled: chartViewMode === '3year'
  });

  const agents = agentsData?.agents || [];

  // Filter data by selected agent - use server-computed yearlyFinancials for accuracy
  const financialsData = useMemo(() => {
    if (!financialsDataRaw) return null;
    if (selectedAgent === 'all') return financialsDataRaw;

    const filteredCustomers = financialsDataRaw.customers.filter(
      (c: any) => c.agentName === selectedAgent
    );

    // Use server-computed per-agent yearly financials (accurate SQL aggregation)
    const agentYearly = agentYearlyData?.agentFinancials?.[selectedAgent] || [];

    return {
      ...financialsDataRaw,
      customers: filteredCustomers,
      yearlyFinancials: agentYearly
    };
  }, [financialsDataRaw, selectedAgent, agentYearlyData]);

  const { data: daysOffData, isLoading: daysOffLoading } = useQuery<CompanyDayOff[]>({
    queryKey: ['/api/company/days-off', selectedYear],
    queryFn: async () => {
      const response = await fetch(`/api/company/days-off?year=${selectedYear}`);
      if (!response.ok) return [];
      return response.json();
    }
  });

  const addDayOffMutation = useMutation({
    mutationFn: async (data: { dates: string[]; reason: string }) => {
      await Promise.all(data.dates.map(date =>
        fetch('/api/company/days-off', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ date, reason: data.reason })
        })
      ));
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['/api/company/days-off'] });
      setShowAddDayOff(false);
      setSelectedDates([]);
      setDayOffReason('');
    }
  });

  const deleteDayOffMutation = useMutation({
    mutationFn: async (id: string) => {
      const response = await fetch(`/api/company/days-off/${id}`, { method: 'DELETE' });
      if (!response.ok) throw new Error('Failed to delete');
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['/api/company/days-off'] });
    }
  });

  const companyDaysOff = useMemo(() => {
    return (daysOffData || []).map(d => new Date(d.date));
  }, [daysOffData]);

  const isCompanyDayOff = (date: Date): boolean => {
    return companyDaysOff.some(d => isSameDay(d, date));
  };

  const isIsraelWeekend = (date: Date): boolean => {
    const day = date.getDay();
    return day === 5 || day === 6; // Friday (5) or Saturday (6) in Israel
  };

  const isNonWorkingDay = (date: Date): boolean => {
    return isIsraelWeekend(date) || isHebrewHoliday(date) || isCompanyDayOff(date);
  };

  const getWorkingDaysInMonth = (year: number, month: number): number => {
    if (customWorkingDays[month] !== null && customWorkingDays[month] !== undefined) {
      return customWorkingDays[month] as number;
    }
    const start = startOfMonth(new Date(year, month));
    const end = endOfMonth(new Date(year, month));
    const days = eachDayOfInterval({ start, end });
    return days.filter(d => !isNonWorkingDay(d)).length;
  };

  const getWorkingDaysElapsed = (year: number, month: number): number => {
    const start = startOfMonth(new Date(year, month));
    const today = new Date();
    const monthEnd = endOfMonth(new Date(year, month));
    
    if (isBefore(today, start)) return 0;
    
    const end = isAfter(today, monthEnd) ? monthEnd : today;
    const days = eachDayOfInterval({ start, end });
    return days.filter(d => !isNonWorkingDay(d)).length;
  };

  const previousYearRevenue = useMemo(() => {
    if (!financialsData?.yearlyFinancials) return 0;
    const prevYear = financialsData.yearlyFinancials.find((y: any) => y.year === selectedYear - 1);
    return prevYear?.revenue || 0;
  }, [financialsData, selectedYear]);

  const currentYearRevenue = useMemo(() => {
    if (!financialsData?.yearlyFinancials) return 0;
    const currYear = financialsData.yearlyFinancials.find((y: any) => y.year === selectedYear);
    return currYear?.revenue || 0;
  }, [financialsData, selectedYear]);

  // DB-persisted monthly targets (₪) for the selected year (server auto-seeds 2026 on first read).
  const { data: targetsData } = useQuery<{ year: number; monthly: number[] }>({
    queryKey: ["/api/targets", String(selectedYear)],
  });
  // Prefer the persisted values; fall back to the 2026 seed constant if the API returned nothing.
  const manualMonthlyTargets: number[] | null =
    targetsData?.monthly && targetsData.monthly.some(v => v > 0)
      ? targetsData.monthly
      : (selectedYear === 2026 ? MANUAL_MONTHLY_TARGETS_2026 : null);

  // In daily mode: annual target = dailyRate × total working days in year
  // (computed after getWorkingDaysInMonth is defined, so we use a placeholder here
  //  and override in monthlyTargets)
  const annualTargetFromGrowth = previousYearRevenue > 0
    ? previousYearRevenue * (1 + growthRate)
    : 1000000;

  // We'll compute annualTarget from daily mode inside monthlyTargets,
  // but we also need it outside — compute total working days eagerly
  const totalWorkingDaysYear = useMemo(
    () => Array.from({ length: 12 }, (_, i) => getWorkingDaysInMonth(selectedYear, i)).reduce((a, b) => a + b, 0),
    [selectedYear, daysOffData, customWorkingDays]
  );

  const annualTarget = manualMonthlyTargets
    ? manualMonthlyTargets.reduce((a, b) => a + b, 0)
    : targetMode === 'daily'
      ? Array.from({ length: 12 }, (_, i) => monthlyDailyRates[i] * getWorkingDaysInMonth(selectedYear, i)).reduce((a, b) => a + b, 0)
      : annualTargetFromGrowth;

  const newCustomers = useMemo(() => {
    if (!financialsData?.customers) return { count: 0, devices: 0, revenue: 0, customers: [] };

    const newCustomersList = financialsData.customers.filter((c: any) => {
      // Must have revenue in the selected year
      const hasActivityThisYear = c.financials?.some((f: any) => f.year === selectedYear && f.revenue > 0);
      if (!hasActivityThisYear) return false;

      const { isNew } = getNewCustomerActivation(c.monthlyRevenue, selectedYear);
      return isNew;
    });

    const totalDevices = newCustomersList.reduce((sum: number, c: any) =>
      sum + (c.deviceInventory?.totalDevices || 0), 0);

    const totalRevenue = newCustomersList.reduce((sum: number, c: any) => {
      const yearRevenue = c.financials?.find((f: any) => f.year === selectedYear)?.revenue || 0;
      return sum + yearRevenue;
    }, 0);

    // Calculate first 12 months revenue from the activation month
    const customersWithFirst12Months = newCustomersList.map((c: any) => {
      const { activationMonth } = getNewCustomerActivation(c.monthlyRevenue, selectedYear);
      let first12MonthsRevenue = 0;
      if (activationMonth) {
        const [ay, amo] = activationMonth.split('-').map(Number);
        const first12Months: string[] = [];
        for (let i = 0; i < 12; i++) {
          const d = new Date(ay, amo - 1 + i, 1);
          first12Months.push(`${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`);
        }
        first12MonthsRevenue = c.monthlyRevenue
          ?.filter((m: any) => first12Months.includes(m.month))
          .reduce((s: number, m: any) => s + (m.revenue || 0), 0) || 0;
      }
      return { ...c, first12MonthsRevenue, activationMonth };
    });

    return {
      count: newCustomersList.length,
      devices: totalDevices,
      revenue: totalRevenue,
      customers: customersWithFirst12Months
    };
  }, [financialsData, selectedYear]);

  const activeCustomers = useMemo(() => {
    if (!financialsData?.customers) return { 
      count: 0, 
      devices: 0, 
      currentYearRevenue: 0, 
      previousYearRevenue: 0,
      revenueChange: 0,
      revenueChangePercent: 0,
      customers: [] 
    };
    
    const activeCustomersList = financialsData.customers.filter((c: any) => {
      // Must have revenue in the selected year
      const hasActivityThisYear = c.financials?.some((f: any) => f.year === selectedYear && f.revenue > 0);
      if (!hasActivityThisYear) return false;

      return true;
    });
    
    const totalDevices = activeCustomersList.reduce((sum: number, c: any) => 
      sum + (c.deviceInventory?.totalDevices || 0), 0);
    
    const currentYearRevenue = activeCustomersList.reduce((sum: number, c: any) => {
      const yearRevenue = c.monthlyRevenue?.filter((m: any) => {
        const [y] = (m.month || '').split('-');
        return parseInt(y) === selectedYear;
      }).reduce((s: number, m: any) => s + (m.revenue || 0), 0) || 0;
      return sum + yearRevenue;
    }, 0);
    
    const previousYearRevenue = activeCustomersList.reduce((sum: number, c: any) => {
      const yearRevenue = c.monthlyRevenue?.filter((m: any) => {
        const [y] = (m.month || '').split('-');
        return parseInt(y) === selectedYear - 1;
      }).reduce((s: number, m: any) => s + (m.revenue || 0), 0) || 0;
      return sum + yearRevenue;
    }, 0);
    
    const revenueChange = currentYearRevenue - previousYearRevenue;
    const revenueChangePercent = previousYearRevenue > 0 
      ? ((currentYearRevenue - previousYearRevenue) / previousYearRevenue) * 100 
      : 0;
    
    return {
      count: activeCustomersList.length,
      devices: totalDevices,
      currentYearRevenue,
      previousYearRevenue,
      revenueChange,
      revenueChangePercent,
      customers: activeCustomersList.slice(0, 10)
    };
  }, [financialsData, selectedYear]);

  const monthlyTargets: MonthlyTarget[] = useMemo(() => {
    const totalWorkingDays = Array.from({ length: 12 }, (_, i) => getWorkingDaysInMonth(selectedYear, i)).reduce((a, b) => a + b, 0);
    const dailyTargetBase = targetMode === 'daily' ? 0 : annualTarget / totalWorkingDays;
    
    const today = new Date();
    const currentMonth = today.getMonth();
    const currentYear = today.getFullYear();

    // Use server-computed monthly revenue (accurate and fast)
    const monthKey = (m: number) => `${selectedYear}-${String(m + 1).padStart(2, '0')}`;
    const getMonthRevenue = (month: number): number => {
      const key = monthKey(month);
      if (selectedAgent === 'all') {
        // Company-wide monthly from server
        const entry = agentMonthlyData?.companyMonthly?.find(e => e.month === key);
        return entry?.revenue || 0;
      } else {
        // Agent-specific monthly from server
        const agentMonths = agentMonthlyData?.agentMonthly?.[selectedAgent] || [];
        const entry = agentMonths.find(e => e.month === key);
        return entry?.revenue || 0;
      }
    };

    return Array.from({ length: 12 }, (_, month) => {
      const workingDays = getWorkingDaysInMonth(selectedYear, month);
      const monthTarget = manualMonthlyTargets
        ? manualMonthlyTargets[month]
        : targetMode === 'daily'
          ? monthlyDailyRates[month] * workingDays
          : dailyTargetBase * workingDays;
      const dailyTarget = workingDays > 0 ? monthTarget / workingDays : 0;
      
      const monthlyData = getMonthRevenue(month);

      // Calculate monthly returns from returnDocuments
      const monthlyReturns = financialsData?.customers?.reduce((sum: number, c: any) => {
        const returns = (c.returnDocuments || []).filter((doc: any) => {
          if (!doc.openDate) return false;
          const parts = doc.openDate.split('/');
          if (parts.length !== 3) return false;
          const docYear = parseInt(parts[2]);
          const docMonth = parseInt(parts[1]);
          return docYear === selectedYear && docMonth === month + 1;
        });
        return sum + returns.reduce((s: number, doc: any) => s + (doc.value || 0), 0);
      }, 0) || 0;

      // Calculate previous month's returns (affects this month's workload)
      const prevMonthIdx = month === 0 ? 11 : month - 1;
      const prevMonthYear = month === 0 ? selectedYear - 1 : selectedYear;
      const prevMonthReturns = financialsData?.customers?.reduce((sum: number, c: any) => {
        const returns = (c.returnDocuments || []).filter((doc: any) => {
          if (!doc.openDate) return false;
          const parts = doc.openDate.split('/');
          if (parts.length !== 3) return false;
          const docYear = parseInt(parts[2]);
          const docMonth = parseInt(parts[1]);
          return docYear === prevMonthYear && docMonth === prevMonthIdx + 1;
        });
        return sum + returns.reduce((s: number, doc: any) => s + (doc.value || 0), 0);
      }, 0) || 0;

      // Get same month previous year data for comparison
      const previousYearMonthData = financialsData?.customers?.reduce((sum: number, c: any) => {
        const monthlyRev = c.monthlyRevenue?.find((m: any) => {
          const [y, m_] = (m.month || '').split('-');
          return parseInt(y) === selectedYear - 1 && parseInt(m_) === month + 1;
        });
        return sum + (monthlyRev?.revenue || 0);
      }, 0) || 0;

      const daysElapsed = getWorkingDaysElapsed(selectedYear, month);
      const expectedByNow = dailyTarget * daysElapsed;
      const progress = monthTarget > 0 ? (monthlyData / monthTarget) * 100 : 0;
      
      // Calculate year-over-year comparison (same day of month)
      const yoyChange = previousYearMonthData > 0 
        ? ((monthlyData - previousYearMonthData) / previousYearMonthData) * 100 
        : 0;
      
      let status: 'on_track' | 'behind' | 'ahead' | 'completed' = 'on_track';
      if (selectedYear < currentYear || (selectedYear === currentYear && month < currentMonth)) {
        status = progress >= 100 ? 'completed' : 'behind';
      } else if (selectedYear === currentYear && month === currentMonth) {
        const expectedProgress = (daysElapsed / workingDays) * 100;
        if (progress >= expectedProgress + 5) status = 'ahead';
        else if (progress < expectedProgress - 5) status = 'behind';
      }

      return {
        month: `${selectedYear}-${String(month + 1).padStart(2, '0')}`,
        monthName: MONTH_NAMES[month],
        workingDays,
        targetRevenue: monthTarget,
        actualRevenue: monthlyData,
        dailyTarget,
        progress,
        status,
        daysElapsed,
        expectedByNow,
        monthlyReturns,
        prevMonthReturns,
        previousYearRevenue: previousYearMonthData,
        yoyChange
      };
    });
  }, [selectedYear, annualTarget, financialsData, companyDaysOff, agentMonthlyData, selectedAgent, monthlyDailyRates, targetMode, customWorkingDays, manualMonthlyTargets]);

  // Calculate previous month's returns without matching invoices
  const previousMonthReturns = useMemo(() => {
    if (!financialsData?.customers) return { documents: [], totalValue: 0, count: 0 };
    
    const now = new Date();
    const prevMonth = now.getMonth() === 0 ? 12 : now.getMonth();
    const prevYear = now.getMonth() === 0 ? now.getFullYear() - 1 : now.getFullYear();
    
    const allReturns: Array<{
      customerName: string;
      customerHp: string;
      docNumber: string;
      openDate: string;
      value: number;
      status: string;
    }> = [];
    
    financialsData.customers.forEach((c: any) => {
      const customerReturns = (c.returnDocuments || []).filter((doc: any) => {
        if (!doc.openDate) return false;
        const parts = doc.openDate.split('/');
        if (parts.length !== 3) return false;
        const docYear = parseInt(parts[2]);
        const docMonth = parseInt(parts[1]);
        return docYear === prevYear && docMonth === prevMonth;
      });
      
      customerReturns.forEach((doc: any) => {
        allReturns.push({
          customerName: c.companyName || c.hp,
          customerHp: c.hp,
          docNumber: doc.documentNumber || '',
          openDate: doc.openDate || '',
          value: doc.value || 0,
          status: doc.status || ''
        });
      });
    });
    
    // Sort by value descending
    allReturns.sort((a, b) => b.value - a.value);
    
    return {
      documents: allReturns,
      totalValue: allReturns.reduce((sum, r) => sum + r.value, 0),
      count: allReturns.length,
      monthName: MONTH_NAMES[prevMonth - 1],
      year: prevYear
    };
  }, [financialsData]);

  // ytdActual: sum from monthly breakdown when available, otherwise fall back to yearlyFinancials
  const monthlyYtd = monthlyTargets.reduce((sum, m) => sum + m.actualRevenue, 0);
  const ytdActual = monthlyYtd > 0 ? monthlyYtd : currentYearRevenue;

  const today = new Date();
  const todayWorkingDaysElapsed = monthlyTargets.slice(0, today.getMonth() + 1).reduce((sum, m) => sum + m.daysElapsed, 0);
  const totalWorkingDaysYearFromMonths = monthlyTargets.reduce((sum, m) => sum + m.workingDays, 0);
  const expectedProgressByToday = (todayWorkingDaysElapsed / totalWorkingDaysYear) * 100;

  // ytdTarget = יעד יומי ממוצע × ימי עבודה שעברו מתחילת השנה
  const ytdTarget = totalWorkingDaysYear > 0 ? (annualTarget / totalWorkingDaysYear) * todayWorkingDaysElapsed : 0;
  // ytdProgress = כמה אחוז מהיעד המצטבר הושג בפועל
  const ytdProgress = ytdTarget > 0 ? (ytdActual / ytdTarget) * 100 : 0;

  const chartData = monthlyTargets.map(m => ({
    name: m.monthName,
    יעד: Math.round(m.targetRevenue),
    בפועל: Math.round(m.actualRevenue),
    progress: m.progress
  }));

  // 3-year comparison chart data
  const chartData3Year = useMemo(() => {
    const getMonthRevenueForYear = (year: number, month: number): number => {
      const key = `${year}-${String(month + 1).padStart(2, '0')}`;
      if (year === selectedYear) {
        const entry = agentMonthlyData?.companyMonthly?.find(e => e.month === key);
        return entry?.revenue || 0;
      } else if (year === selectedYear - 1) {
        const entry = agentMonthlyDataPrev1?.companyMonthly?.find(e => e.month === key);
        return entry?.revenue || 0;
      } else if (year === selectedYear - 2) {
        const entry = agentMonthlyDataPrev2?.companyMonthly?.find(e => e.month === key);
        return entry?.revenue || 0;
      }
      return 0;
    };

    return Array.from({ length: 12 }, (_, month) => ({
      name: MONTH_NAMES[month],
      [selectedYear]: Math.round(getMonthRevenueForYear(selectedYear, month)),
      [selectedYear - 1]: Math.round(getMonthRevenueForYear(selectedYear - 1, month)),
      [selectedYear - 2]: Math.round(getMonthRevenueForYear(selectedYear - 2, month)),
    }));
  }, [selectedYear, agentMonthlyData, agentMonthlyDataPrev1, agentMonthlyDataPrev2]);

  // Customer breakdown for selected filter month
  const monthCustomerBreakdown = useMemo(() => {
    if (selectedFilterMonth === null || !financialsData?.customers) return [];
    const monthKey = `${selectedYear}-${String(selectedFilterMonth + 1).padStart(2, '0')}`;
    return financialsData.customers
      .map((c: any) => {
        const entry = c.monthlyRevenue?.find((m: any) => m.month === monthKey);
        return {
          id: c.customerId || c.id,
          name: c.companyName || c.name,
          revenue: entry?.revenue || 0,
          count: entry?.count || 0,
        };
      })
      .filter((c: any) => c.revenue > 0)
      .sort((a: any, b: any) => b.revenue - a.revenue);
  }, [selectedFilterMonth, selectedYear, financialsData]);

  const monthDrillDownBreakdown = useMemo(() => {
    if (!selectedMonthDrillDown || !financialsData?.customers) return [];
    return financialsData.customers
      .map((c: any) => {
        const entry = c.monthlyRevenue?.find((m: any) => m.month === selectedMonthDrillDown);
        return {
          id: c.customerId || c.id,
          name: c.companyName || c.name,
          revenue: entry?.revenue || 0,
          count: entry?.count || 0,
        };
      })
      .filter((c: any) => c.revenue > 0)
      .sort((a: any, b: any) => b.revenue - a.revenue);
  }, [selectedMonthDrillDown, financialsData]);

  const statusColors = {
    'on_track': 'bg-blue-100 text-blue-700 border-blue-200',
    'behind': 'bg-red-100 text-red-700 border-red-200',
    'ahead': 'bg-emerald-100 text-emerald-700 border-emerald-200',
    'completed': 'bg-emerald-100 text-emerald-700 border-emerald-200'
  };

  const statusLabels = {
    'on_track': 'במסלול',
    'behind': 'מאחור',
    'ahead': 'מקדים',
    'completed': 'הושלם'
  };

  return (
    <DashboardLayout>
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        className="space-y-6"
      >
        <div className="flex items-center justify-between" dir="rtl">
          <div className="text-right">
            <h1 className="text-3xl font-bold text-foreground flex items-center gap-2">
              <Target className="w-8 h-8 text-primary" />
              יעדי חברה {selectedYear}
            </h1>
            <p className="text-muted-foreground">מעקב אחר יעד צמיחה שנתי של {customGrowthRate.toFixed(0)}%</p>
            <div className="flex items-center gap-2 mt-1">
              <span className="inline-flex items-center gap-1 text-xs bg-blue-50 border border-blue-200 text-blue-700 rounded-full px-2.5 py-0.5 font-medium">
                <FileText className="w-3 h-3" />
                מבוסס על חשבוניות
              </span>
            </div>
          </div>
          <div className="flex gap-2">
            <Select value={selectedAgent} onValueChange={setSelectedAgent}>
              <SelectTrigger className="w-40" data-testid="select-agent">
                <SelectValue placeholder="סוכן" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="all" data-testid="select-agent-all">כל הסוכנים</SelectItem>
                {agents.map(agent => (
                  <SelectItem key={agent} value={agent} data-testid={`select-agent-${agent}`}>{agent}</SelectItem>
                ))}
              </SelectContent>
            </Select>
            <Select value={selectedYear.toString()} onValueChange={(v) => handleYearChange(parseInt(v))}>
              <SelectTrigger className="w-32" data-testid="select-year">
                <SelectValue placeholder="שנה" />
              </SelectTrigger>
              <SelectContent>
                {[2024, 2025, 2026].map(year => (
                  <SelectItem key={year} value={year.toString()} data-testid={`select-year-${year}`}>{year}</SelectItem>
                ))}
              </SelectContent>
            </Select>
            <Dialog open={showAddDayOff} onOpenChange={(open) => { setShowAddDayOff(open); if (open) { setCalendarYear(selectedYear); setCalendarMonth(new Date(selectedYear, 0)); } if (!open) { setSelectedDates([]); setDayOffReason(''); } }}>
              <DialogTrigger asChild>
                <Button variant="outline" className="gap-2" data-testid="button-add-day-off">
                  <Plus className="w-4 h-4" />
                  הוסף יום חופש
                </Button>
              </DialogTrigger>
              <DialogContent className="text-right max-w-sm" dir="rtl">
                <DialogHeader>
                  <DialogTitle>הוספת ימי חופש לחברה</DialogTitle>
                </DialogHeader>
                <div className="space-y-3 py-2">
                  {/* Quick presets */}
                  <div className="space-y-1">
                    <p className="text-xs font-medium text-muted-foreground">הוספה מהירה:</p>
                    <div className="flex flex-wrap gap-1.5">
                      {[
                        { label: 'חול המועד פסח', dates: getHolidaysForYear(selectedYear).filter(h => h.name === 'חול המועד פסח').map(h => h.date) },
                        { label: 'חול המועד סוכות', dates: getHolidaysForYear(selectedYear).filter(h => h.name === 'חול המועד סוכות').map(h => h.date) },
                      ].map(preset => (
                        preset.dates.length > 0 && (
                          <button
                            key={preset.label}
                            onClick={() => {
                              const alreadyOff = (daysOffData || []).map(d => format(new Date(d.date), 'yyyy-MM-dd'));
                              const toAdd = preset.dates.filter(d => !alreadyOff.includes(format(d, 'yyyy-MM-dd')));
                              setSelectedDates(prev => {
                                const existing = prev.map(d => format(d, 'yyyy-MM-dd'));
                                const newDates = toAdd.filter(d => !existing.includes(format(d, 'yyyy-MM-dd')));
                                return [...prev, ...newDates];
                              });
                              if (!dayOffReason) setDayOffReason(preset.label);
                            }}
                            className="text-xs px-2 py-1 rounded border border-amber-300 bg-amber-50 text-amber-700 hover:bg-amber-100 transition-colors"
                          >
                            + {preset.label} ({preset.dates.length} ימים)
                          </button>
                        )
                      ))}
                      <button
                        onClick={() => setSelectedDates([])}
                        className="text-xs px-2 py-1 rounded border border-gray-200 bg-gray-50 text-gray-500 hover:bg-gray-100 transition-colors"
                      >
                        נקה הכל
                      </button>
                    </div>
                  </div>

                  {/* Calendar */}
                  <div className="flex flex-col items-center gap-1">
                    {/* Year navigation */}
                    <div className="flex items-center gap-3 w-full justify-center pb-1">
                      <button
                        onClick={() => { const y = calendarYear - 1; setCalendarYear(y); setCalendarMonth(new Date(y, calendarMonth.getMonth())); }}
                        className="p-1 rounded hover:bg-muted transition-colors text-muted-foreground hover:text-foreground"
                        title="שנה קודמת"
                      >
                        <ChevronRight className="w-4 h-4" />
                      </button>
                      <span className="text-sm font-semibold min-w-[3rem] text-center">{calendarYear}</span>
                      <button
                        onClick={() => { const y = calendarYear + 1; setCalendarYear(y); setCalendarMonth(new Date(y, calendarMonth.getMonth())); }}
                        className="p-1 rounded hover:bg-muted transition-colors text-muted-foreground hover:text-foreground"
                        title="שנה הבאה"
                      >
                        <ChevronLeft className="w-4 h-4" />
                      </button>
                    </div>
                    <Calendar
                      mode="multiple"
                      selected={selectedDates}
                      onSelect={(dates) => setSelectedDates(dates || [])}
                      locale={he}
                      className="rounded-md border"
                      month={calendarMonth}
                      onMonthChange={setCalendarMonth}
                      fromDate={new Date(calendarYear, 0, 1)}
                      toDate={new Date(calendarYear, 11, 31)}
                      modifiers={{
                        holiday: getHolidaysForYear(calendarYear).map(h => h.date),
                        existingOff: (daysOffData || []).map(d => new Date(d.date)),
                      }}
                      modifiersClassNames={{
                        holiday: 'bg-amber-100 text-amber-800 font-medium',
                        existingOff: 'bg-blue-100 text-blue-800 font-medium',
                      }}
                    />
                  </div>

                  {/* Legend */}
                  <div className="flex gap-3 text-xs text-muted-foreground justify-center">
                    <span className="flex items-center gap-1"><span className="w-3 h-3 rounded bg-amber-100 border border-amber-300 inline-block" />חג</span>
                    <span className="flex items-center gap-1"><span className="w-3 h-3 rounded bg-blue-100 border border-blue-300 inline-block" />כבר מסומן</span>
                    <span className="flex items-center gap-1"><span className="w-3 h-3 rounded bg-primary inline-block" />נבחר</span>
                  </div>

                  {/* Selected count */}
                  {selectedDates.length > 0 && (
                    <div className="bg-muted/50 rounded-lg p-2 text-sm text-center">
                      <span className="font-medium text-primary">{selectedDates.length}</span> ימים נבחרו
                      <div className="text-xs text-muted-foreground mt-1 flex flex-wrap gap-1 justify-center">
                        {selectedDates.sort((a, b) => a.getTime() - b.getTime()).map(d => (
                          <span key={d.toISOString()} className="bg-primary/10 text-primary rounded px-1">{format(d, 'dd/MM')}</span>
                        ))}
                      </div>
                    </div>
                  )}

                  <Input
                    placeholder="סיבה (לדוגמה: כנס שנתי)"
                    value={dayOffReason}
                    onChange={(e) => setDayOffReason(e.target.value)}
                    dir="rtl"
                  />
                </div>
                <DialogFooter>
                  <Button
                    onClick={() => {
                      if (selectedDates.length > 0) {
                        addDayOffMutation.mutate({
                          dates: selectedDates.map(d => format(d, 'yyyy-MM-dd')),
                          reason: dayOffReason || 'יום חופש'
                        });
                      }
                    }}
                    disabled={selectedDates.length === 0 || addDayOffMutation.isPending}
                  >
                    {addDayOffMutation.isPending
                      ? <Loader2 className="w-4 h-4 animate-spin" />
                      : `הוסף${selectedDates.length > 1 ? ` (${selectedDates.length} ימים)` : ''}`}
                  </Button>
                </DialogFooter>
              </DialogContent>
            </Dialog>
            <Dialog open={showTargetSettings} onOpenChange={setShowTargetSettings}>
              <DialogTrigger asChild>
                <Button variant="outline" className="gap-2" data-testid="button-target-settings">
                  <Target className="w-4 h-4" />
                  הגדר יעד
                </Button>
              </DialogTrigger>
              <DialogContent className="text-right max-w-lg" dir="rtl">
                <DialogHeader>
                  <DialogTitle>הגדרת יעד צמיחה</DialogTitle>
                </DialogHeader>
                <div className="space-y-4 py-4">
                  {/* Mode toggle */}
                  <div className="flex rounded-lg border overflow-hidden text-sm">
                    <button
                      className={`flex-1 py-2 px-3 transition-colors ${targetMode === 'growth' ? 'bg-primary text-primary-foreground font-medium' : 'bg-background text-muted-foreground hover:bg-muted'}`}
                      onClick={() => setTargetMode('growth')}
                    >
                      אחוז צמיחה
                    </button>
                    <button
                      className={`flex-1 py-2 px-3 transition-colors ${targetMode === 'daily' ? 'bg-primary text-primary-foreground font-medium' : 'bg-background text-muted-foreground hover:bg-muted'}`}
                      onClick={() => setTargetMode('daily')}
                    >
                      תחשיב יומי
                    </button>
                  </div>

                  {targetMode === 'growth' ? (
                    <div className="space-y-2">
                      <label className="text-sm font-medium">אחוז צמיחה שנתי</label>
                      <div className="flex items-center gap-2">
                        <Input
                          type="number"
                          min="0"
                          max="100"
                          step="0.5"
                          value={customGrowthRate}
                          onChange={(e) => setCustomGrowthRate(parseFloat(e.target.value) || 0)}
                          className="w-24 text-center"
                          data-testid="input-growth-rate"
                        />
                        <span className="text-muted-foreground">%</span>
                      </div>
                      <p className="text-xs text-muted-foreground">ברירת מחדל: {DEFAULT_GROWTH_RATE * 100}%</p>
                    </div>
                  ) : (
                    <div className="space-y-3">
                      <div className="space-y-1">
                        <label className="text-sm font-medium">קביעת תחשיב לכל החודשים</label>
                        <div className="flex items-center gap-2">
                          <span className="text-muted-foreground text-sm">₪</span>
                          <Input
                            type="number"
                            min="0"
                            step="100"
                            value={dailyRate}
                            onChange={(e) => {
                              const v = parseFloat(e.target.value) || 0;
                              setDailyRate(v);
                              setMonthlyDailyRates(Array(12).fill(v));
                            }}
                            className="w-32 text-center"
                            data-testid="input-daily-rate"
                            placeholder="לכל החודשים"
                          />
                          <span className="text-xs text-muted-foreground">ליום (לכולם)</span>
                        </div>
                        <p className="text-xs text-muted-foreground">שנה ערך כאן לאיפוס כל החודשים, או ערוך כל חודש בנפרד למטה</p>
                      </div>
                      <div className="border rounded-lg overflow-hidden">
                        <div className="bg-muted/40 px-3 py-1.5 text-xs font-medium text-muted-foreground border-b flex justify-between">
                          <span>חודש (ימי עבודה)</span>
                          <span>₪ ליום → יעד חודשי</span>
                        </div>
                        <div className="max-h-[260px] overflow-y-auto">
                          {Array.from({ length: 12 }, (_, i) => {
                            const wd = getWorkingDaysInMonth(selectedYear, i);
                            const monthName = new Date(selectedYear, i).toLocaleString('he-IL', { month: 'long' });
                            const rate = monthlyDailyRates[i];
                            const target = rate * wd;
                            return (
                              <div key={i} className="flex items-center justify-between gap-2 px-3 py-2 border-b last:border-0 hover:bg-muted/20">
                                <span className="text-sm font-medium w-28 shrink-0">{monthName} <span className="text-muted-foreground text-xs">({wd})</span></span>
                                <div className="flex items-center gap-1">
                                  <span className="text-xs text-muted-foreground">₪</span>
                                  <Input
                                    type="number"
                                    min="0"
                                    step="100"
                                    value={rate}
                                    onChange={(e) => {
                                      const v = parseFloat(e.target.value) || 0;
                                      setMonthlyDailyRates(prev => {
                                        const next = [...prev];
                                        next[i] = v;
                                        return next;
                                      });
                                    }}
                                    className="w-24 text-center h-7 text-sm"
                                  />
                                </div>
                                <span className="text-xs font-medium text-primary w-24 text-left">₪{target.toLocaleString(undefined, { maximumFractionDigits: 0 })}</span>
                              </div>
                            );
                          })}
                        </div>
                      </div>
                    </div>
                  )}

                  <div className="bg-muted/50 p-3 rounded-lg space-y-1 text-sm">
                    {targetMode === 'growth' && (
                      <div className="flex justify-between">
                        <span>הכנסות {selectedYear - 1}:</span>
                        <span className="font-medium">₪{previousYearRevenue.toLocaleString(undefined, { maximumFractionDigits: 0 })}</span>
                      </div>
                    )}
                    {targetMode === 'daily' && (
                      <div className="flex justify-between">
                        <span>ימי עבודה בשנה:</span>
                        <span className="font-medium">{totalWorkingDaysYear} ימים</span>
                      </div>
                    )}
                    <div className="flex justify-between text-primary font-medium">
                      <span>יעד {selectedYear}:</span>
                      <span>₪{annualTarget.toLocaleString(undefined, { maximumFractionDigits: 0 })}</span>
                    </div>
                  </div>
                </div>
                <DialogFooter>
                  <Button
                    variant="outline"
                    onClick={() => {
                      setTargetMode('growth');
                      setCustomGrowthRate(DEFAULT_GROWTH_RATE * 100);
                    }}
                  >
                    איפוס לברירת מחדל
                  </Button>
                  <Button
                    onClick={() => saveGrowthRateMutation.mutate()}
                    disabled={saveGrowthRateMutation.isPending}
                    data-testid="button-save-growth-rate"
                  >
                    {saveGrowthRateMutation.isPending ? <Loader2 className="w-4 h-4 animate-spin ml-2" /> : null}
                    שמור
                  </Button>
                </DialogFooter>
              </DialogContent>
            </Dialog>
          </div>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4" dir="rtl">
          <Card
            className="bg-gradient-to-br from-primary/10 to-primary/5 border-primary/20 cursor-pointer hover:shadow-md hover:border-primary/40 transition-all"
            data-testid="card-annual-target"
            onClick={() => setDrillDownCard('annual')}
          >
            <CardContent className="pt-6">
              <div className="flex items-center justify-between">
                <div className="text-right">
                  <p className="text-sm font-medium text-muted-foreground">יעד שנתי</p>
                  <h3 className="text-2xl font-bold text-primary" data-testid="text-annual-target">₪{annualTarget.toLocaleString(undefined, { maximumFractionDigits: 0 })}</h3>
                  <p className="text-xs text-muted-foreground">
                    {targetMode === 'daily'
                      ? `תחשיב יומי לפי חודש × ${totalWorkingDaysYear} ימים`
                      : `+${customGrowthRate.toFixed(0)}% מ-${selectedYear - 1}`}
                  </p>
                </div>
                <Target className="w-10 h-10 text-primary/50" />
              </div>
            </CardContent>
          </Card>

          <Card
            className={`bg-gradient-to-br cursor-pointer hover:shadow-md transition-all ${ytdActual >= ytdTarget ? 'from-emerald-50 to-emerald-100/50 border-emerald-200 hover:border-emerald-400' : 'from-amber-50 to-amber-100/50 border-amber-200 hover:border-amber-400'}`}
            onClick={() => setDrillDownCard('ytd')}
          >
            <CardContent className="pt-6">
              <div className="flex items-center justify-between">
                <div className="text-right">
                  <p className="text-sm font-medium text-muted-foreground">ביצוע מצטבר</p>
                  <h3 className={`text-2xl font-bold ${ytdActual >= ytdTarget ? 'text-emerald-600' : 'text-amber-600'}`}>
                    ₪{ytdActual.toLocaleString(undefined, { maximumFractionDigits: 0 })}
                  </h3>
                  <p className="text-xs text-muted-foreground">{ytdProgress.toFixed(1)}% מהיעד המצטבר</p>
                </div>
                {ytdActual >= ytdTarget ? (
                  <TrendingUp className="w-10 h-10 text-emerald-500/50" />
                ) : (
                  <TrendingDown className="w-10 h-10 text-amber-500/50" />
                )}
              </div>
            </CardContent>
          </Card>

          <Card
            className="bg-gradient-to-br from-blue-50 to-blue-100/50 border-blue-200 cursor-pointer hover:shadow-md hover:border-blue-400 transition-all"
            onClick={() => setDrillDownCard('working-days')}
          >
            <CardContent className="pt-6">
              <div className="flex items-center justify-between">
                <div className="text-right">
                  <p className="text-sm font-medium text-muted-foreground">ימי עבודה בשנה</p>
                  <h3 className="text-2xl font-bold text-blue-600">{totalWorkingDaysYear}</h3>
                  <p className="text-xs text-muted-foreground">{todayWorkingDaysElapsed} עברו עד היום</p>
                </div>
                <CalendarIcon className="w-10 h-10 text-blue-500/50" />
              </div>
            </CardContent>
          </Card>

          <Card
            className="bg-gradient-to-br from-purple-50 to-purple-100/50 border-purple-200 cursor-pointer hover:shadow-md hover:border-purple-400 transition-all"
            onClick={() => setDrillDownCard('daily-avg')}
          >
            <CardContent className="pt-6">
              <div className="flex items-center justify-between">
                <div className="text-right">
                  <p className="text-sm font-medium text-muted-foreground">יעד יומי ממוצע</p>
                  <h3 className="text-2xl font-bold text-purple-600">
                    ₪{(annualTarget / totalWorkingDaysYear).toLocaleString(undefined, { maximumFractionDigits: 0 })}
                  </h3>
                  <p className="text-xs text-muted-foreground">לפי חלוקה שווה</p>
                </div>
                <Clock className="w-10 h-10 text-purple-500/50" />
              </div>
            </CardContent>
          </Card>
        </div>

        {/* Unified Customer Summary Card */}
        <Card className="bg-gradient-to-br from-indigo-50 to-purple-50/50 border-indigo-200 p-1" data-testid="card-customers-summary">
          <CardContent className="p-0">
            <div className="grid grid-cols-2 gap-2 text-right" dir="rtl">
              <div className="bg-white/60 rounded-lg p-0 px-1 border border-indigo-100 leading-tight">
                <div className="flex items-center gap-2 justify-start">
                  <Users className="w-4 h-4 text-indigo-600" />
                  <span className="text-sm text-muted-foreground">סה"כ לקוחות</span>
                </div>
                <p className="text-5xl font-bold text-indigo-700 leading-none" data-testid="text-total-customers-count">
                  {newCustomers.customers.length + activeCustomers.count}
                </p>
                <p className="text-sm text-indigo-500 leading-tight">
                  {newCustomers.customers.length} חדשים + {activeCustomers.count} פעילים
                </p>
              </div>
              <div className="bg-white/60 rounded-lg p-0 px-1 border border-indigo-100 leading-tight">
                <div className="flex items-center gap-2 justify-start">
                  <Coins className="w-4 h-4 text-indigo-600" />
                  <span className="text-sm text-muted-foreground">סה"כ הכנסות</span>
                </div>
                <p className="text-5xl font-bold text-indigo-700 leading-none" data-testid="text-total-revenue">
                  ₪{(newCustomers.revenue + activeCustomers.currentYearRevenue).toLocaleString(undefined, { maximumFractionDigits: 0 })}
                </p>
                <p className="text-sm text-indigo-500 leading-tight">
                  ₪{newCustomers.revenue.toLocaleString(undefined, { maximumFractionDigits: 0 })} + ₪{activeCustomers.currentYearRevenue.toLocaleString(undefined, { maximumFractionDigits: 0 })}
                </p>
              </div>
              <div className="bg-white/60 rounded-lg p-0 px-1 border border-indigo-100 leading-tight">
                <div className="flex items-center gap-2 justify-start">
                  <Wrench className="w-4 h-4 text-indigo-600" />
                  <span className="text-sm text-muted-foreground">סה"כ כלים</span>
                </div>
                <p className="text-5xl font-bold text-indigo-700 leading-none" data-testid="text-total-devices">
                  {activeCustomers.devices.toLocaleString()}
                </p>
                <p className="text-sm text-indigo-500 leading-tight">
                  {newCustomers.devices.toLocaleString()} חדשים + {(activeCustomers.devices - newCustomers.devices).toLocaleString()} פעילים
                </p>
              </div>
              <div className="bg-white/60 rounded-lg p-0 px-1 border border-indigo-100 leading-tight">
                <div className="flex items-center gap-2 justify-start">
                  <TrendingUp className="w-4 h-4 text-indigo-600" />
                  <span className="text-sm text-muted-foreground">שינוי לעומת {selectedYear - 1}</span>
                </div>
                <p className="text-5xl font-bold text-indigo-700 leading-none">
                  {activeCustomers.revenueChangePercent >= 0 ? '+' : ''}{activeCustomers.revenueChangePercent.toFixed(1)}%
                </p>
                <p className={`text-sm ${activeCustomers.revenueChange >= 0 ? 'text-emerald-600' : 'text-red-600'} leading-tight`}>
                  {activeCustomers.revenueChange >= 0 ? '+' : ''}₪{activeCustomers.revenueChange.toLocaleString(undefined, { maximumFractionDigits: 0 })}
                </p>
              </div>
            </div>
            {newCustomers.customers.length > 0 && (
              <div className="mt-4 pt-4 border-t border-indigo-100">
                <div className="flex items-center justify-between mb-2" dir="rtl">
                  <p className="text-sm font-medium text-muted-foreground">לקוחות חדשים (הכנסות 12 חודשים ראשונים):</p>
                  <Badge variant="secondary" className="bg-indigo-100 text-indigo-700 border-indigo-200">{newCustomers.customers.length} לקוחות</Badge>
                </div>
                <ScrollArea className="h-[180px] rounded-lg border border-indigo-100">
                  <table className="w-full text-sm" dir="rtl">
                    <thead className="sticky top-0 bg-indigo-50/90 backdrop-blur-sm">
                      <tr className="border-b border-indigo-200">
                        <th className="text-right py-2 px-3 font-medium text-indigo-700">#</th>
                        <th className="text-right py-2 px-3 font-medium text-indigo-700">שם לקוח</th>
                        <th className="text-right py-2 px-3 font-medium text-indigo-700">הכנסות 12 חודשים ראשונים</th>
                        <th className="text-right py-2 px-3 font-medium text-indigo-700">כלים</th>
                      </tr>
                    </thead>
                    <tbody>
                      {newCustomers.customers.map((c: any, idx: number) => (
                        <tr
                          key={c.id}
                          className={`border-b border-indigo-50 hover:bg-indigo-50/60 transition-colors cursor-pointer ${idx % 2 === 0 ? 'bg-white' : 'bg-indigo-50/20'}`}
                          onClick={() => window.location.href = `/dashboard?customer=${c.id}`}
                        >
                          <td className="py-2 px-3 text-muted-foreground text-xs">{idx + 1}</td>
                          <td className="py-2 px-3 font-medium text-sm">{c.companyName}</td>
                          <td className="py-2 px-3">
                            <span className="font-bold text-indigo-700">₪{(c.first12MonthsRevenue || 0).toLocaleString(undefined, { maximumFractionDigits: 0 })}</span>
                          </td>
                          <td className="py-2 px-3 text-muted-foreground text-sm">{(c.deviceCount || 0).toLocaleString()}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </ScrollArea>
              </div>
            )}
          </CardContent>
        </Card>

        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          <Card className="lg:col-span-2 text-right">
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                השוואת יעד מול ביצוע חודשי
                <span className="inline-flex items-center gap-1 text-xs bg-blue-50 border border-blue-200 text-blue-700 rounded-full px-2.5 py-0.5 font-medium">
                  <FileText className="w-3 h-3" />
                  חשבוניות
                </span>
              </CardTitle>
              <CardDescription>יעד חודשי מחושב לפי מספר ימי עבודה</CardDescription>
              <div className="flex items-center gap-4 mt-3 pt-3 border-t flex-wrap" dir="rtl">
                <span className="text-sm font-medium text-muted-foreground">מקרא צבעים:</span>
                <div className="flex items-center gap-1.5">
                  <div className="w-4 h-4 rounded bg-[#10b981]"></div>
                  <span className="text-sm">הושלם (מעל 100%)</span>
                </div>
                <div className="flex items-center gap-1.5">
                  <div className="w-4 h-4 rounded bg-[#3b82f6]"></div>
                  <span className="text-sm">קרוב ליעד (80%-100%)</span>
                </div>
                <div className="flex items-center gap-1.5">
                  <div className="w-4 h-4 rounded bg-[#f59e0b]"></div>
                  <span className="text-sm">מאחור (מתחת ל-80%)</span>
                </div>
                <div className="flex items-center gap-1.5">
                  <div className="w-4 h-4 rounded bg-[#94a3b8]"></div>
                  <span className="text-sm">יעד חודשי</span>
                </div>
              </div>
            </CardHeader>
            <CardContent className="h-[350px]">
              <ResponsiveContainer width="100%" height="100%">
                <ComposedChart data={chartData} margin={{ top: 20, right: 20, left: 20, bottom: 5 }}>
                  <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="hsl(var(--border))" />
                  <XAxis dataKey="name" stroke="hsl(var(--muted-foreground))" fontSize={12} />
                  <YAxis stroke="hsl(var(--muted-foreground))" fontSize={12} tickFormatter={(v) => `₪${(v/1000).toFixed(0)}k`} />
                  <Tooltip 
                    formatter={(value: number, name: string) => [`₪${value.toLocaleString()}`, name]}
                    contentStyle={{ 
                      direction: 'rtl', 
                      textAlign: 'right',
                      backgroundColor: 'white',
                      border: '1px solid #e5e7eb',
                      borderRadius: '8px',
                      boxShadow: '0 4px 12px rgba(0,0,0,0.15)'
                    }}
                    labelStyle={{ fontWeight: 'bold', color: '#1f2937' }}
                    itemStyle={{ color: '#374151' }}
                  />
                  <Bar dataKey="יעד" fill="#94a3b8" radius={[4, 4, 0, 0]} barSize={30} />
                  <Bar dataKey="בפועל" radius={[4, 4, 0, 0]} barSize={30}>
                    {chartData.map((entry, index) => (
                      <Cell 
                        key={`cell-${index}`} 
                        fill={entry.progress >= 100 ? '#10b981' : entry.progress >= 80 ? '#3b82f6' : '#f59e0b'} 
                      />
                    ))}
                  </Bar>
                </ComposedChart>
              </ResponsiveContainer>
            </CardContent>
          </Card>

        </div>

        {/* Monthly Revenue Chart with drill-down */}
        <Card className="text-right" dir="rtl">
          <CardHeader>
            <div className="flex items-start justify-between gap-4">
              <div>
                <CardTitle className="flex items-center gap-2">
                  הכנסות לפי חודש
                  <span className="inline-flex items-center gap-1 text-xs bg-blue-50 border border-blue-200 text-blue-700 rounded-full px-2.5 py-0.5 font-medium">
                    <FileText className="w-3 h-3" />
                    חשבוניות
                  </span>
                </CardTitle>
                <CardDescription>לחץ על עמודה לפירוט לקוחות | לחץ שוב לביטול סינון</CardDescription>
              </div>
              <div className="flex items-center gap-2 flex-shrink-0">
                {/* View mode toggle */}
                <div className="flex rounded-lg border overflow-hidden text-xs">
                  <button
                    className={`px-3 py-1.5 transition-colors ${chartViewMode === 'current' ? 'bg-primary text-primary-foreground' : 'bg-background hover:bg-muted'}`}
                    onClick={() => setChartViewMode('current')}
                  >
                    שנה נוכחית
                  </button>
                  <button
                    className={`px-3 py-1.5 transition-colors ${chartViewMode === '3year' ? 'bg-primary text-primary-foreground' : 'bg-background hover:bg-muted'}`}
                    onClick={() => setChartViewMode('3year')}
                  >
                    השוואה 3 שנים
                  </button>
                </div>
                <Select
                  value={selectedFilterMonth === null ? 'all' : String(selectedFilterMonth)}
                  onValueChange={(v) => setSelectedFilterMonth(v === 'all' ? null : parseInt(v))}
                >
                  <SelectTrigger className="w-36 text-sm h-8">
                    <SelectValue placeholder="כל החודשים" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="all">כל החודשים</SelectItem>
                    {MONTH_NAMES.map((name, idx) => (
                      <SelectItem key={idx} value={String(idx)}>{name}</SelectItem>
                    ))}
                  </SelectContent>
                </Select>
                {selectedFilterMonth !== null && (
                  <Button variant="ghost" size="sm" className="h-8 px-2 text-xs" onClick={() => setSelectedFilterMonth(null)}>
                    ✕ נקה
                  </Button>
                )}
              </div>
            </div>
          </CardHeader>
          <CardContent>
            <div className={`transition-all ${selectedFilterMonth !== null ? 'grid grid-cols-1 lg:grid-cols-2 gap-6' : ''}`}>
              {/* Chart */}
              <div className="h-[300px]">
                <ResponsiveContainer width="100%" height="100%">
                  {chartViewMode === '3year' ? (
                    <BarChart
                      data={chartData3Year}
                      margin={{ top: 10, right: 10, left: 10, bottom: 5 }}
                    >
                      <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="hsl(var(--border))" />
                      <XAxis dataKey="name" stroke="hsl(var(--muted-foreground))" fontSize={11} />
                      <YAxis stroke="hsl(var(--muted-foreground))" fontSize={11} tickFormatter={(v) => `₪${(v/1000).toFixed(0)}k`} width={55} />
                      <Tooltip
                        formatter={(value: number, name: string) => [`₪${value.toLocaleString()}`, name]}
                        contentStyle={{ direction: 'rtl', textAlign: 'right', backgroundColor: 'white', border: '1px solid #e5e7eb', borderRadius: '8px', boxShadow: '0 4px 12px rgba(0,0,0,0.15)' }}
                        labelStyle={{ fontWeight: 'bold', color: '#1f2937' }}
                      />
                      <Legend wrapperStyle={{ fontSize: '11px' }} />
                      <Bar dataKey={selectedYear - 2} fill="#94a3b8" radius={[2, 2, 0, 0]} barSize={14} name={`${selectedYear - 2}`} />
                      <Bar dataKey={selectedYear - 1} fill="#64748b" radius={[2, 2, 0, 0]} barSize={14} name={`${selectedYear - 1}`} />
                      <Bar dataKey={selectedYear} fill="#3b82f6" radius={[2, 2, 0, 0]} barSize={14} name={`${selectedYear}`} />
                    </BarChart>
                  ) : (
                    <ComposedChart
                      data={chartData}
                      margin={{ top: 10, right: 10, left: 10, bottom: 5 }}
                      onClick={(data) => {
                        if (data?.activeTooltipIndex !== undefined) {
                          const idx = data.activeTooltipIndex;
                          setSelectedFilterMonth(prev => prev === idx ? null : idx);
                        }
                      }}
                      style={{ cursor: 'pointer' }}
                    >
                      <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="hsl(var(--border))" />
                      <XAxis dataKey="name" stroke="hsl(var(--muted-foreground))" fontSize={11} />
                      <YAxis stroke="hsl(var(--muted-foreground))" fontSize={11} tickFormatter={(v) => `₪${(v/1000).toFixed(0)}k`} width={55} />
                      <Tooltip
                        formatter={(value: number, name: string) => [`₪${value.toLocaleString()}`, name]}
                        contentStyle={{ direction: 'rtl', textAlign: 'right', backgroundColor: 'white', border: '1px solid #e5e7eb', borderRadius: '8px', boxShadow: '0 4px 12px rgba(0,0,0,0.15)' }}
                        labelStyle={{ fontWeight: 'bold', color: '#1f2937' }}
                      />
                      <Bar dataKey="בפועל" radius={[4, 4, 0, 0]} barSize={28}>
                        {chartData.map((entry, index) => (
                          <Cell
                            key={`cell-${index}`}
                            fill={
                              selectedFilterMonth === index
                                ? '#6366f1'
                                : entry.בפועל === 0
                                ? '#e2e8f0'
                                : entry.progress >= 100
                                ? '#10b981'
                                : entry.progress >= 80
                                ? '#3b82f6'
                                : '#f59e0b'
                            }
                            opacity={selectedFilterMonth !== null && selectedFilterMonth !== index ? 0.4 : 1}
                          />
                        ))}
                      </Bar>
                      <Line
                        type="monotone"
                        dataKey="יעד"
                        stroke="#94a3b8"
                        strokeWidth={2}
                        strokeDasharray="5 5"
                        dot={false}
                      />
                      {selectedFilterMonth !== null && (
                        <ReferenceLine
                          x={MONTH_NAMES[selectedFilterMonth]}
                          stroke="#6366f1"
                          strokeWidth={2}
                          strokeDasharray="4 4"
                        />
                      )}
                    </ComposedChart>
                  )}
                </ResponsiveContainer>
              </div>

              {/* Month drill-down panel */}
              {selectedFilterMonth !== null && (
                <div className="flex flex-col">
                  <div className="flex items-center justify-between mb-3">
                    <h3 className="font-semibold text-base">
                      {MONTH_NAMES[selectedFilterMonth]} {selectedYear} — פירוט לקוחות
                    </h3>
                    <div className="text-sm text-muted-foreground">
                      {monthCustomerBreakdown.length} לקוחות פעילים
                    </div>
                  </div>
                  {/* Summary row */}
                  <div className="grid grid-cols-3 gap-2 mb-3">
                    <div className="bg-primary/5 rounded-lg p-2 text-center">
                      <p className="text-xs text-muted-foreground">סה"כ הכנסות</p>
                      <p className="font-bold text-primary text-sm">₪{monthlyTargets[selectedFilterMonth]?.actualRevenue.toLocaleString(undefined, { maximumFractionDigits: 0 })}</p>
                    </div>
                    <div className="bg-muted/40 rounded-lg p-2 text-center">
                      <p className="text-xs text-muted-foreground">יעד חודשי</p>
                      <p className="font-bold text-sm">₪{monthlyTargets[selectedFilterMonth]?.targetRevenue.toLocaleString(undefined, { maximumFractionDigits: 0 })}</p>
                    </div>
                    <div className={`rounded-lg p-2 text-center ${(monthlyTargets[selectedFilterMonth]?.progress || 0) >= 100 ? 'bg-emerald-50' : 'bg-amber-50'}`}>
                      <p className="text-xs text-muted-foreground">ביצוע</p>
                      <p className={`font-bold text-sm ${(monthlyTargets[selectedFilterMonth]?.progress || 0) >= 100 ? 'text-emerald-600' : 'text-amber-600'}`}>
                        {(monthlyTargets[selectedFilterMonth]?.progress || 0).toFixed(1)}%
                      </p>
                    </div>
                  </div>
                  {/* Customer list */}
                  <ScrollArea className="flex-1 h-[200px] border rounded-lg">
                    {monthCustomerBreakdown.length === 0 ? (
                      <div className="flex items-center justify-center h-full text-muted-foreground text-sm py-8">
                        אין נתוני הכנסות לחודש זה
                      </div>
                    ) : (
                      <table className="w-full text-sm">
                        <thead className="sticky top-0 bg-muted/80 backdrop-blur-sm">
                          <tr>
                            <th className="text-right py-2 px-3 font-medium text-muted-foreground">#</th>
                            <th className="text-right py-2 px-3 font-medium text-muted-foreground">לקוח</th>
                            <th className="text-left py-2 px-3 font-medium text-muted-foreground">הכנסה</th>
                            <th className="text-left py-2 px-3 font-medium text-muted-foreground">%</th>
                          </tr>
                        </thead>
                        <tbody>
                          {monthCustomerBreakdown.map((c: any, idx: number) => {
                            const totalMonth = monthlyTargets[selectedFilterMonth]?.actualRevenue || 1;
                            const pct = (c.revenue / totalMonth) * 100;
                            return (
                              <tr key={c.id} className={idx % 2 === 0 ? 'bg-background' : 'bg-muted/20'}>
                                <td className="py-1.5 px-3 text-muted-foreground text-xs">{idx + 1}</td>
                                <td className="py-1.5 px-3 font-medium text-xs">{c.name}</td>
                                <td className="py-1.5 px-3 text-left font-mono text-xs">₪{c.revenue.toLocaleString(undefined, { maximumFractionDigits: 0 })}</td>
                                <td className="py-1.5 px-3 text-left">
                                  <div className="flex items-center gap-1.5">
                                    <div className="h-1.5 rounded-full bg-primary/20 w-12 overflow-hidden">
                                      <div className="h-full bg-primary rounded-full" style={{ width: `${Math.min(pct, 100)}%` }} />
                                    </div>
                                    <span className="text-xs text-muted-foreground">{pct.toFixed(0)}%</span>
                                  </div>
                                </td>
                              </tr>
                            );
                          })}
                        </tbody>
                      </table>
                    )}
                  </ScrollArea>
                </div>
              )}
            </div>
          </CardContent>
        </Card>

        <Card className="text-right">
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              פירוט יעדים חודשיים
              <span className="inline-flex items-center gap-1 text-xs bg-blue-50 border border-blue-200 text-blue-700 rounded-full px-2.5 py-0.5 font-medium">
                <FileText className="w-3 h-3" />
                חשבוניות
              </span>
            </CardTitle>
            <CardDescription>יעד יומי ומצב התקדמות לכל חודש</CardDescription>
          </CardHeader>
          <CardContent>
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4" dir="rtl">
              {monthlyTargets.map((month, idx) => {
                const isCurrent = new Date().getFullYear() === selectedYear && new Date().getMonth() === parseInt(month.month.split('-')[1]) - 1;
                return (
                  <div
                    key={month.month}
                    className={`p-4 rounded-xl border-2 transition-all cursor-pointer ${
                      isCurrent ? 'border-primary bg-primary/5 shadow-lg' : 'border-border hover:border-primary/30'
                    }`}
                    onClick={() => {
                      setSelectedMonthDrillDown(month.month);
                      setMonthDrillDownSearch('');
                    }}
                  >
                    <div className="flex items-center justify-between mb-3">
                      <span className="font-bold text-lg">{month.monthName}</span>
                      <Badge className={statusColors[month.status]}>
                        {statusLabels[month.status]}
                      </Badge>
                    </div>
                    
                    <div className="space-y-2 text-sm">
                      <div className="flex justify-between items-center">
                        <span className="text-muted-foreground">ימי עבודה:</span>
                        <div className="flex items-center gap-2">
                          {customWorkingDays[idx] !== null ? (
                            <Badge variant="outline" className="text-amber-600 border-amber-300 bg-amber-50">
                              מותאם ידני
                            </Badge>
                          ) : null}
                          <input
                            type="number"
                            min={1}
                            max={31}
                            value={customWorkingDays[idx] !== null ? (customWorkingDays[idx] as number) : month.workingDays}
                            onChange={(e) => {
                              const val = parseInt(e.target.value);
                              if (isNaN(val) || val < 1) {
                                setCustomWorkingDays(prev => {
                                  const next = [...prev];
                                  next[idx] = null;
                                  return next;
                                });
                              } else {
                                setCustomWorkingDays(prev => {
                                  const next = [...prev];
                                  next[idx] = val;
                                  return next;
                                });
                              }
                            }}
                            className="w-14 text-center text-sm font-medium border rounded px-1 py-0.5 focus:outline-none focus:ring-1 focus:ring-primary"
                          />
                        </div>
                      </div>
                      <div className="flex justify-between">
                        <span className="text-muted-foreground">יעד חודשי:</span>
                        <span className="font-medium">₪{month.targetRevenue.toLocaleString(undefined, { maximumFractionDigits: 0 })}</span>
                      </div>
                      <div className="flex justify-between">
                        <span className="text-muted-foreground">יעד יומי:</span>
                        <span className="font-medium text-primary">₪{month.dailyTarget.toLocaleString(undefined, { maximumFractionDigits: 0 })}</span>
                      </div>
                      <div className="flex justify-between">
                        <span className="text-muted-foreground">בפועל:</span>
                        <span className={`font-bold ${month.actualRevenue >= month.targetRevenue ? 'text-emerald-600' : 'text-foreground'}`}>
                          ₪{month.actualRevenue.toLocaleString(undefined, { maximumFractionDigits: 0 })}
                        </span>
                      </div>
                      {month.monthlyReturns > 0 && (
                        <div className="flex justify-between">
                          <span className="text-muted-foreground">החזרות:</span>
                          <div className="flex items-center gap-1">
                            <span className="font-medium text-red-500">
                              -₪{month.monthlyReturns.toLocaleString(undefined, { maximumFractionDigits: 0 })}
                            </span>
                            <span className="text-xs text-red-400">
                              ({month.targetRevenue > 0 ? ((month.monthlyReturns / month.targetRevenue) * 100).toFixed(1) : 0}%)
                            </span>
                          </div>
                        </div>
                      )}
                      {month.previousYearRevenue > 0 && (
                        <div className="flex justify-between border-t pt-1 mt-1">
                          <span className="text-muted-foreground text-xs">{selectedYear - 1}:</span>
                          <div className="flex items-center gap-1">
                            <span className="text-xs">₪{month.previousYearRevenue.toLocaleString(undefined, { maximumFractionDigits: 0 })}</span>
                            <span className={`text-xs font-bold ${month.yoyChange >= 0 ? 'text-emerald-600' : 'text-red-600'}`}>
                              ({month.yoyChange >= 0 ? '+' : ''}{month.yoyChange.toFixed(0)}%)
                            </span>
                          </div>
                        </div>
                      )}
                    </div>

                    <div className="mt-3">
                      <div className="flex justify-between text-xs mb-1">
                        <span>התקדמות</span>
                        <span>{month.progress.toFixed(1)}%</span>
                      </div>
                      <div className="h-2 bg-muted rounded-full overflow-hidden">
                        <div 
                          className={`h-full transition-all ${
                            month.progress >= 100 ? 'bg-emerald-500' : 
                            month.progress >= 80 ? 'bg-blue-500' : 
                            month.progress >= 50 ? 'bg-amber-500' : 'bg-red-500'
                          }`}
                          style={{ width: `${Math.min(month.progress, 100)}%` }}
                        />
                      </div>
                    </div>

                    {isCurrent && month.daysElapsed > 0 && (
                      <div className="mt-3 pt-3 border-t text-xs">
                        <div className="flex justify-between text-muted-foreground">
                          <span>צפי עד היום:</span>
                          <span>₪{month.expectedByNow.toLocaleString(undefined, { maximumFractionDigits: 0 })}</span>
                        </div>
                        <div className="flex justify-between">
                          <span className="text-muted-foreground">פער:</span>
                          <span className={month.actualRevenue >= month.expectedByNow ? 'text-emerald-600' : 'text-red-600'}>
                            {month.actualRevenue >= month.expectedByNow ? '+' : ''}
                            ₪{(month.actualRevenue - month.expectedByNow).toLocaleString(undefined, { maximumFractionDigits: 0 })}
                          </span>
                        </div>
                      </div>
                    )}
                  </div>
                );
              })}
            </div>
          </CardContent>
        </Card>
      </motion.div>

      {/* Month Drill-Down Dialog */}
      {(() => {
        const drillMonth = selectedMonthDrillDown;
        const drillMonthIdx = drillMonth ? parseInt(drillMonth.split('-')[1]) - 1 : -1;
        const drillMonthData = drillMonth ? monthlyTargets.find(m => m.month === drillMonth) : null;
        const totalRevenue = drillMonthData?.actualRevenue || 0;
        const filtered = monthDrillDownBreakdown.filter((c: any) =>
          !monthDrillDownSearch || c.name?.toLowerCase().includes(monthDrillDownSearch.toLowerCase())
        );
        return (
          <Dialog open={selectedMonthDrillDown !== null} onOpenChange={(open) => {
            if (!open) { setSelectedMonthDrillDown(null); setMonthDrillDownSearch(''); }
          }}>
            <DialogContent className="max-w-2xl max-h-[85vh] overflow-hidden" dir="rtl">
              <DialogHeader>
                <DialogTitle className="flex items-center gap-2 text-right">
                  <span>{drillMonthData?.monthName} {selectedYear}</span>
                  {drillMonthData && (
                    <Badge className={statusColors[drillMonthData.status]}>{statusLabels[drillMonthData.status]}</Badge>
                  )}
                </DialogTitle>
              </DialogHeader>

              {/* Summary row */}
              {drillMonthData && (
                <div className="grid grid-cols-3 gap-3 px-1">
                  <div className="bg-primary/5 border border-primary/20 rounded-lg p-3 text-center">
                    <p className="text-xs text-muted-foreground mb-1">בפועל</p>
                    <p className="font-bold text-primary">₪{totalRevenue.toLocaleString(undefined, { maximumFractionDigits: 0 })}</p>
                  </div>
                  <div className="bg-muted/40 rounded-lg p-3 text-center">
                    <p className="text-xs text-muted-foreground mb-1">יעד</p>
                    <p className="font-bold">₪{drillMonthData.targetRevenue.toLocaleString(undefined, { maximumFractionDigits: 0 })}</p>
                  </div>
                  <div className={`rounded-lg p-3 text-center ${drillMonthData.progress >= 100 ? 'bg-emerald-50 border border-emerald-200' : 'bg-amber-50 border border-amber-200'}`}>
                    <p className="text-xs text-muted-foreground mb-1">ביצוע</p>
                    <p className={`font-bold ${drillMonthData.progress >= 100 ? 'text-emerald-600' : 'text-amber-600'}`}>
                      {drillMonthData.progress.toFixed(1)}%
                    </p>
                  </div>
                </div>
              )}

              <div className="px-1">
                <Input
                  placeholder="חפש לקוח..."
                  value={monthDrillDownSearch}
                  onChange={(e) => setMonthDrillDownSearch(e.target.value)}
                  className="text-right"
                />
              </div>

              <ScrollArea className="h-[50vh]">
                {filtered.length === 0 ? (
                  <div className="text-center py-10 text-muted-foreground">
                    <p>אין נתוני הכנסות לחודש זה</p>
                  </div>
                ) : (
                  <table className="w-full text-sm">
                    <thead className="sticky top-0 bg-background border-b">
                      <tr>
                        <th className="text-right py-2 px-3 font-medium text-muted-foreground w-8">#</th>
                        <th className="text-right py-2 px-3 font-medium text-muted-foreground">לקוח</th>
                        <th className="text-right py-2 px-3 font-medium text-muted-foreground">חשבוניות</th>
                        <th className="text-right py-2 px-3 font-medium text-muted-foreground">הכנסה</th>
                        <th className="text-right py-2 px-3 font-medium text-muted-foreground w-24">% מהחודש</th>
                      </tr>
                    </thead>
                    <tbody>
                      {filtered.map((c: any, idx: number) => {
                        const pct = totalRevenue > 0 ? (c.revenue / totalRevenue) * 100 : 0;
                        return (
                          <tr key={c.id} className={idx % 2 === 0 ? 'bg-background' : 'bg-muted/20'}>
                            <td className="py-2 px-3 text-muted-foreground text-xs">{idx + 1}</td>
                            <td className="py-2 px-3 font-medium">{c.name}</td>
                            <td className="py-2 px-3 text-center text-muted-foreground text-xs">{c.count}</td>
                            <td className="py-2 px-3 font-bold text-primary">₪{c.revenue.toLocaleString(undefined, { maximumFractionDigits: 0 })}</td>
                            <td className="py-2 px-3">
                              <div className="flex items-center gap-1.5">
                                <div className="h-1.5 rounded-full bg-muted w-14 overflow-hidden">
                                  <div className="h-full bg-primary rounded-full" style={{ width: `${Math.min(pct, 100)}%` }} />
                                </div>
                                <span className="text-xs text-muted-foreground">{pct.toFixed(1)}%</span>
                              </div>
                            </td>
                          </tr>
                        );
                      })}
                    </tbody>
                    <tfoot className="sticky bottom-0 bg-muted/80 border-t font-bold">
                      <tr>
                        <td colSpan={2} className="py-2 px-3">{filtered.length} לקוחות</td>
                        <td className="py-2 px-3 text-center text-xs">
                          {filtered.reduce((s: number, c: any) => s + c.count, 0)}
                        </td>
                        <td className="py-2 px-3 text-primary">
                          ₪{filtered.reduce((s: number, c: any) => s + c.revenue, 0).toLocaleString(undefined, { maximumFractionDigits: 0 })}
                        </td>
                        <td />
                      </tr>
                    </tfoot>
                  </table>
                )}
              </ScrollArea>
            </DialogContent>
          </Dialog>
        );
      })()}

      {/* New Customers Detail Dialog */}
      <Dialog open={showNewCustomersDialog} onOpenChange={(open) => {
        setShowNewCustomersDialog(open);
        if (!open) { setNewCustomerSearch(""); setNewCustomersDialogTab('summary'); }
      }}>
        <DialogContent className="max-w-5xl max-h-[85vh] overflow-hidden" dir="rtl">
          <DialogHeader>
            <DialogTitle className="flex items-center gap-2">
              <UserPlus className="w-5 h-5 text-teal-600" />
              לקוחות חדשים {selectedYear} — {newCustomers.count} לקוחות | {newCustomers.devices.toLocaleString()} כלים | ₪{newCustomers.revenue.toLocaleString(undefined, { maximumFractionDigits: 0 })} הכנסות
            </DialogTitle>
          </DialogHeader>

          {/* Tabs */}
          <div className="flex gap-2 px-1 pb-1 border-b">
            <button
              onClick={() => setNewCustomersDialogTab('summary')}
              className={`px-4 py-1.5 text-sm rounded-t font-medium transition-colors ${newCustomersDialogTab === 'summary' ? 'bg-teal-100 text-teal-800 border border-teal-300 border-b-white' : 'text-muted-foreground hover:text-foreground'}`}
              data-testid="tab-new-customers-summary"
            >
              סיכום לקוחות
            </button>
            <button
              onClick={() => setNewCustomersDialogTab('detail')}
              className={`px-4 py-1.5 text-sm rounded-t font-medium transition-colors ${newCustomersDialogTab === 'detail' ? 'bg-teal-100 text-teal-800 border border-teal-300 border-b-white' : 'text-muted-foreground hover:text-foreground'}`}
              data-testid="tab-new-customers-detail"
            >
              פירוט חשבוניות
            </button>
          </div>

          {/* Search */}
          <div className="px-1 pb-2">
            <Input
              placeholder="חפש לקוח..."
              value={newCustomerSearch}
              onChange={(e) => setNewCustomerSearch(e.target.value)}
              className="text-right"
              data-testid="input-new-customer-search"
            />
          </div>

          {newCustomersDialogTab === 'summary' ? (
            /* ---- SUMMARY TABLE ---- */
            <ScrollArea className="h-[55vh]">
              <table className="w-full text-sm" dir="rtl">
                <thead className="sticky top-0 bg-muted/90 backdrop-blur-sm">
                  <tr className="border-b">
                    <th className="text-right py-2 px-3 font-medium text-muted-foreground">#</th>
                    <th className="text-right py-2 px-3 font-medium text-muted-foreground">לקוח</th>
                    <th className="text-right py-2 px-3 font-medium text-muted-foreground">ח.פ.</th>
                    <th className="text-right py-2 px-3 font-medium text-muted-foreground">רכישה ראשונה</th>
                    <th className="text-center py-2 px-3 font-medium text-muted-foreground">כלים</th>
                    <th className="text-left py-2 px-3 font-medium text-muted-foreground">הכנסות {selectedYear}</th>
                    <th className="text-left py-2 px-3 font-medium text-muted-foreground">12 חודשים ראשונים</th>
                  </tr>
                </thead>
                <tbody>
                  {newCustomers.customers
                    .filter((c: any) =>
                      !newCustomerSearch ||
                      c.companyName?.toLowerCase().includes(newCustomerSearch.toLowerCase()) ||
                      c.hp?.includes(newCustomerSearch)
                    )
                    .sort((a: any, b: any) => {
                      const ra = a.financials?.find((f: any) => f.year === selectedYear)?.revenue || 0;
                      const rb = b.financials?.find((f: any) => f.year === selectedYear)?.revenue || 0;
                      return rb - ra;
                    })
                    .map((c: any, idx: number) => {
                      const yearRevenue = c.financials?.find((f: any) => f.year === selectedYear)?.revenue || 0;
                      const devices = c.deviceInventory?.totalDevices || 0;
                      const [ay, amo] = (c.activationMonth || '').split('-');
                      const firstPurchaseParts = c.customerScore?.metrics?.firstPurchase?.split('/');
                      const firstPurchaseYear = firstPurchaseParts ? parseInt(firstPurchaseParts[2]) : null;
                      const isReactivated = ay && firstPurchaseYear && firstPurchaseYear < parseInt(ay);
                      const activationLabel = c.activationMonth
                        ? `${MONTH_NAMES[parseInt(amo) - 1]} ${ay}`
                        : (c.customerScore?.metrics?.firstPurchase || '—');
                      return (
                        <tr
                          key={c.id}
                          className={`border-b ${idx % 2 === 0 ? 'bg-background' : 'bg-muted/20'} hover:bg-teal-50/40 cursor-pointer`}
                          onClick={() => { setNewCustomersDialogTab('detail'); }}
                          data-testid={`row-new-customer-${c.id}`}
                        >
                          <td className="py-2 px-3 text-muted-foreground text-xs">{idx + 1}</td>
                          <td className="py-2 px-3 font-medium">
                            {c.companyName}
                            {isReactivated && <Badge variant="outline" className="mr-2 text-[10px] py-0 h-4 bg-blue-50 text-blue-700 border-blue-200">מחוזר</Badge>}
                          </td>
                          <td className="py-2 px-3 text-muted-foreground text-xs font-mono">{c.hp}</td>
                          <td className="py-2 px-3 text-muted-foreground text-xs">{activationLabel}</td>
                          <td className="py-2 px-3 text-center font-medium">{devices > 0 ? devices.toLocaleString() : '—'}</td>
                          <td className="py-2 px-3 font-bold text-teal-700">₪{yearRevenue.toLocaleString(undefined, { maximumFractionDigits: 0 })}</td>
                          <td className="py-2 px-3 text-muted-foreground">₪{(c.first12MonthsRevenue || 0).toLocaleString(undefined, { maximumFractionDigits: 0 })}</td>
                        </tr>
                      );
                    })}
                </tbody>
                <tfoot className="sticky bottom-0 bg-teal-100/80 border-t-2 border-teal-300 font-bold">
                  <tr>
                    <td colSpan={2} className="py-2 px-3">
                      {newCustomers.customers.filter((c: any) =>
                        !newCustomerSearch ||
                        c.companyName?.toLowerCase().includes(newCustomerSearch.toLowerCase()) ||
                        c.hp?.includes(newCustomerSearch)
                      ).length} לקוחות
                    </td>
                    <td colSpan={2} />
                    <td className="py-2 px-3 text-center text-teal-800">
                      {newCustomers.customers
                        .filter((c: any) =>
                          !newCustomerSearch ||
                          c.companyName?.toLowerCase().includes(newCustomerSearch.toLowerCase()) ||
                          c.hp?.includes(newCustomerSearch)
                        )
                        .reduce((s: number, c: any) => s + (c.deviceInventory?.totalDevices || 0), 0)
                        .toLocaleString()}
                    </td>
                    <td className="py-2 px-3 text-teal-800">
                      ₪{newCustomers.customers
                        .filter((c: any) =>
                          !newCustomerSearch ||
                          c.companyName?.toLowerCase().includes(newCustomerSearch.toLowerCase()) ||
                          c.hp?.includes(newCustomerSearch)
                        )
                        .reduce((s: number, c: any) => s + (c.financials?.find((f: any) => f.year === selectedYear)?.revenue || 0), 0)
                        .toLocaleString(undefined, { maximumFractionDigits: 0 })}
                    </td>
                    <td className="py-2 px-3 text-teal-800">
                      ₪{newCustomers.customers
                        .filter((c: any) =>
                          !newCustomerSearch ||
                          c.companyName?.toLowerCase().includes(newCustomerSearch.toLowerCase()) ||
                          c.hp?.includes(newCustomerSearch)
                        )
                        .reduce((s: number, c: any) => s + (c.first12MonthsRevenue || 0), 0)
                        .toLocaleString(undefined, { maximumFractionDigits: 0 })}
                    </td>
                  </tr>
                </tfoot>
              </table>
            </ScrollArea>
          ) : (
            /* ---- DETAIL (invoices per customer) ---- */
            <ScrollArea className="h-[55vh]">
              <div className="space-y-4 p-1">
                {newCustomers.customers.length === 0 ? (
                  <div className="text-center py-8 text-muted-foreground">
                    <UserPlus className="w-12 h-12 mx-auto mb-3 opacity-30" />
                    <p>אין לקוחות חדשים בשנה זו</p>
                  </div>
                ) : (
                  newCustomers.customers
                    .filter((customer: any) =>
                      !newCustomerSearch ||
                      customer.companyName?.toLowerCase().includes(newCustomerSearch.toLowerCase()) ||
                      customer.hp?.includes(newCustomerSearch)
                    )
                    .sort((a: any, b: any) => {
                      const ra = a.financials?.find((f: any) => f.year === selectedYear)?.revenue || 0;
                      const rb = b.financials?.find((f: any) => f.year === selectedYear)?.revenue || 0;
                      return rb - ra;
                    })
                    .map((customer: any) => {
                      const yearInvoices = customer.invoices?.filter((inv: any) => inv.year === selectedYear) || [];
                      const yearRevenue = yearInvoices.reduce((sum: number, inv: any) => sum + (inv.netPrice || 0), 0);
                      const devices = customer.deviceInventory?.totalDevices || 0;
                      return (
                        <Card key={customer.id} className="border-teal-200 bg-teal-50/30">
                          <CardHeader className="pb-2" dir="rtl">
                            <div className="flex items-center justify-between flex-row-reverse">
                              <CardTitle className="text-base text-right">{customer.companyName}</CardTitle>
                              <div className="flex items-center gap-2">
                                {devices > 0 && (
                                  <Badge variant="outline" className="bg-white text-teal-700 border-teal-200 text-xs">
                                    <Wrench className="w-3 h-3 ml-1" />{devices} כלים
                                  </Badge>
                                )}
                                <Badge variant="outline" className="bg-teal-100 text-teal-700 border-teal-300 text-xs">{customer.hp}</Badge>
                              </div>
                            </div>
                            <CardDescription className="flex items-center gap-4 flex-wrap flex-row-reverse text-right text-xs">
                              {customer.activationMonth && (() => {
                                const [ay, amo] = customer.activationMonth.split('-');
                                const firstPurchaseParts = customer.customerScore?.metrics?.firstPurchase?.split('/');
                                const firstPurchaseYear = firstPurchaseParts ? parseInt(firstPurchaseParts[2]) : null;
                                const isReactivated = firstPurchaseYear && firstPurchaseYear < parseInt(ay);
                                return (
                                  <span>
                                    {isReactivated ? 'חזרה:' : 'רכישה ראשונה:'}{' '}
                                    {MONTH_NAMES[parseInt(amo) - 1]} {ay}
                                    {isReactivated && <Badge variant="outline" className="mr-1 text-[10px] py-0 h-4 bg-blue-50 text-blue-700 border-blue-200">מחוזר</Badge>}
                                  </span>
                                );
                              })()}
                              {!customer.activationMonth && <span>רכישה ראשונה: {customer.customerScore?.metrics?.firstPurchase || '-'}</span>}
                              <span className="font-bold text-teal-700">סה"כ {selectedYear}: ₪{yearRevenue.toLocaleString(undefined, { maximumFractionDigits: 0 })}</span>
                            </CardDescription>
                          </CardHeader>
                          <CardContent className="pt-0">
                            {yearInvoices.length === 0 ? (
                              <p className="text-sm text-muted-foreground">אין חשבוניות בשנה זו</p>
                            ) : (
                              <div className="overflow-x-auto" dir="rtl">
                                <table className="w-full text-sm">
                                  <thead>
                                    <tr className="border-b bg-muted/30">
                                      <th className="text-right py-1.5 px-3">מס' חשבונית</th>
                                      <th className="text-right py-1.5 px-3">תאריך</th>
                                      <th className="text-right py-1.5 px-3">סכום נטו</th>
                                      <th className="text-right py-1.5 px-3">מע"מ</th>
                                      <th className="text-right py-1.5 px-3">סה"כ</th>
                                    </tr>
                                  </thead>
                                  <tbody>
                                    {yearInvoices.map((inv: any, idx: number) => (
                                      <tr key={idx} className="border-b border-dashed hover:bg-white/50">
                                        <td className="py-1.5 px-3 font-medium text-right">{inv.invoiceNumber}</td>
                                        <td className="py-1.5 px-3 text-right text-muted-foreground">{inv.date}</td>
                                        <td className="py-1.5 px-3 text-right">₪{(inv.netPrice || 0).toLocaleString(undefined, { maximumFractionDigits: 0 })}</td>
                                        <td className="py-1.5 px-3 text-right text-muted-foreground">₪{(inv.vat || 0).toLocaleString(undefined, { maximumFractionDigits: 0 })}</td>
                                        <td className="py-1.5 px-3 font-bold text-right">₪{(inv.totalPrice || 0).toLocaleString(undefined, { maximumFractionDigits: 0 })}</td>
                                      </tr>
                                    ))}
                                  </tbody>
                                  <tfoot>
                                    <tr className="bg-teal-100/60 font-bold text-sm">
                                      <td colSpan={2} className="py-1.5 px-3 text-right">סה"כ ({yearInvoices.length} חשבוניות)</td>
                                      <td className="py-1.5 px-3 text-right">₪{yearRevenue.toLocaleString(undefined, { maximumFractionDigits: 0 })}</td>
                                      <td className="py-1.5 px-3 text-right">₪{yearInvoices.reduce((s: number, inv: any) => s + (inv.vat || 0), 0).toLocaleString(undefined, { maximumFractionDigits: 0 })}</td>
                                      <td className="py-1.5 px-3 text-right">₪{yearInvoices.reduce((s: number, inv: any) => s + (inv.totalPrice || 0), 0).toLocaleString(undefined, { maximumFractionDigits: 0 })}</td>
                                    </tr>
                                  </tfoot>
                                </table>
                              </div>
                            )}
                          </CardContent>
                        </Card>
                      );
                    })
                )}
              </div>
            </ScrollArea>
          )}

          <DialogFooter dir="rtl">
            <div className="flex items-center justify-between w-full flex-row-reverse">
              <div className="text-sm text-muted-foreground text-right">
                סה"כ {newCustomers.customers.length} לקוחות חדשים | {newCustomers.devices.toLocaleString()} כלים | ₪{newCustomers.revenue.toLocaleString(undefined, { maximumFractionDigits: 0 })} הכנסות
              </div>
              <Button variant="outline" onClick={() => setShowNewCustomersDialog(false)}>
                סגור
              </Button>
            </div>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Drill-down dialog for summary cards */}
      <Dialog open={drillDownCard !== null} onOpenChange={(open) => { if (!open) setDrillDownCard(null); }}>
        <DialogContent className="max-w-md" dir="rtl">
          <DialogHeader>
            <DialogTitle className="text-right">
              {drillDownCard === 'annual' && 'איך מחושב היעד השנתי?'}
              {drillDownCard === 'ytd' && 'איך מחושב הביצוע המצטבר?'}
              {drillDownCard === 'working-days' && 'איך מחושבים ימי העבודה?'}
              {drillDownCard === 'daily-avg' && 'איך מחושב היעד היומי הממוצע?'}
            </DialogTitle>
          </DialogHeader>

          <ScrollArea className="max-h-[60vh]">
            <div className="space-y-4 text-right pb-2">

              {/* Annual Target Drill-down */}
              {drillDownCard === 'annual' && (
                <div className="space-y-3">
                  <div className="bg-primary/5 border border-primary/20 rounded-lg p-3 text-sm space-y-2">
                    <p className="font-semibold text-primary">שיטת חישוב: {targetMode === 'daily' ? 'תחשיב יומי' : 'אחוז צמיחה'}</p>
                    {targetMode === 'growth' ? (
                      <>
                        <div className="font-mono text-xs bg-white border rounded p-2 space-y-1">
                          <div className="flex justify-between"><span>הכנסות {selectedYear - 1}:</span><span className="font-bold">₪{previousYearRevenue.toLocaleString(undefined, { maximumFractionDigits: 0 })}</span></div>
                          <div className="flex justify-between"><span>× צמיחה ({customGrowthRate.toFixed(0)}%):</span><span className="font-bold">× {(1 + customGrowthRate / 100).toFixed(2)}</span></div>
                          <div className="border-t pt-1 flex justify-between text-primary font-bold"><span>= יעד {selectedYear}:</span><span>₪{annualTarget.toLocaleString(undefined, { maximumFractionDigits: 0 })}</span></div>
                        </div>
                        <p className="text-xs text-muted-foreground">הנוסחה: הכנסות שנה קודמת × (1 + {customGrowthRate.toFixed(0)}%)</p>
                      </>
                    ) : (
                      <>
                        <div className="font-mono text-xs bg-white border rounded p-2 space-y-1">
                          <div className="flex justify-between"><span>תחשיב יומי:</span><span className="font-bold">לפי חודש</span></div>
                          <div className="flex justify-between"><span>ימי עבודה בשנה:</span><span className="font-bold">{totalWorkingDaysYear} ימים</span></div>
                          <div className="border-t pt-1 flex justify-between text-primary font-bold"><span>= יעד {selectedYear}:</span><span>₪{annualTarget.toLocaleString(undefined, { maximumFractionDigits: 0 })}</span></div>
                        </div>
                        <p className="text-xs text-muted-foreground">הנוסחה: סכום (תחשיב יומי × ימי עבודה) לכל חודש</p>
                        <div className="mt-2 space-y-1">
                          <p className="text-xs font-medium text-muted-foreground border-b pb-1">יעד לפי חודשים:</p>
                          {Array.from({ length: 12 }, (_, i) => {
                            const wd = getWorkingDaysInMonth(selectedYear, i);
                            const rate = monthlyDailyRates[i];
                            return (
                              <div key={i} className="flex justify-between text-xs">
                                <span>{new Date(selectedYear, i).toLocaleString('he-IL', { month: 'long' })} ({wd} ימים × ₪{rate.toLocaleString()})</span>
                                <span className="font-medium">₪{(rate * wd).toLocaleString(undefined, { maximumFractionDigits: 0 })}</span>
                              </div>
                            );
                          })}
                        </div>
                      </>
                    )}
                  </div>
                </div>
              )}

              {/* YTD Drill-down */}
              {drillDownCard === 'ytd' && (
                <div className="space-y-3">
                  <div className="bg-emerald-50 border border-emerald-200 rounded-lg p-3 text-sm space-y-1">
                    <p className="font-semibold text-emerald-700">סכום הכנסות חודשיות ממקור הנתונים</p>
                    <p className="text-xs text-muted-foreground">כל חודש = סכום חשבוניות שהוצאו לכלל הלקוחות</p>
                  </div>
                  <div className="space-y-1">
                    {monthlyTargets.map((m, idx) => {
                      const isFuture = m.actualRevenue === 0 && idx > today.getMonth();
                      const isCurrentMonth = idx === today.getMonth() && selectedYear === today.getFullYear();
                      return (
                        <div key={m.month} className={`flex justify-between items-center text-sm px-2 py-1.5 rounded ${isFuture ? 'opacity-40' : 'bg-muted/30'}`}>
                          <div className="flex items-center gap-2">
                            <span className={`font-medium ${isCurrentMonth ? 'text-primary' : ''}`}>{m.monthName}</span>
                            {isCurrentMonth && <Badge variant="outline" className="text-[10px] py-0 h-4">נוכחי</Badge>}
                          </div>
                          <div className="text-left flex items-center gap-3">
                            <span className="text-xs text-muted-foreground">{m.progress.toFixed(0)}% מיעד</span>
                            <span className={`font-bold ${m.actualRevenue >= m.targetRevenue ? 'text-emerald-600' : m.actualRevenue > 0 ? 'text-amber-600' : 'text-muted-foreground'}`}>
                              ₪{m.actualRevenue.toLocaleString(undefined, { maximumFractionDigits: 0 })}
                            </span>
                          </div>
                        </div>
                      );
                    })}
                  </div>
                  <div className="border-t pt-2 flex justify-between font-bold text-sm">
                    <span>סה"כ מצטבר:</span>
                    <span className="text-emerald-600">₪{ytdActual.toLocaleString(undefined, { maximumFractionDigits: 0 })}</span>
                  </div>
                  <div className="flex justify-between text-sm text-muted-foreground">
                    <span>יעד מצטבר עד היום:</span>
                    <span>₪{ytdTarget.toLocaleString(undefined, { maximumFractionDigits: 0 })}</span>
                  </div>
                  <div className={`flex justify-between text-sm font-semibold ${ytdProgress >= 100 ? 'text-emerald-600' : 'text-amber-600'}`}>
                    <span>ביצוע לעומת יעד:</span>
                    <span>{ytdProgress.toFixed(1)}%</span>
                  </div>
                </div>
              )}

              {/* Working Days Drill-down */}
              {drillDownCard === 'working-days' && (
                <div className="space-y-3">
                  <div className="bg-blue-50 border border-blue-200 rounded-lg p-3 text-sm space-y-1">
                    <p className="font-semibold text-blue-700">ימי עבודה = ימי שבוע (א׳-ה׳) פחות חגים ופחות ימי חופש חברה</p>
                    <div className="font-mono text-xs bg-white border rounded p-2 space-y-1 mt-2">
                      <div className="flex justify-between"><span>ימי לוח בשנה:</span><span>365</span></div>
                      <div className="flex justify-between"><span>פחות שישי-שבת:</span><span className="text-red-500">−{365 - totalWorkingDaysYear - getHolidaysForYear(selectedYear).length - (daysOffData || []).length}</span></div>
                      <div className="flex justify-between"><span>פחות חגים ({getHolidaysForYear(selectedYear).length}):</span><span className="text-red-500">−{getHolidaysForYear(selectedYear).length}</span></div>
                      <div className="flex justify-between"><span>פחות ימי חופש חברה ({(daysOffData || []).length}):</span><span className="text-red-500">−{(daysOffData || []).length}</span></div>
                      <div className="border-t pt-1 flex justify-between text-blue-700 font-bold"><span>= ימי עבודה:</span><span>{totalWorkingDaysYear}</span></div>
                    </div>
                  </div>
                  <div className="space-y-1">
                    <p className="text-xs font-medium text-muted-foreground border-b pb-1">פירוט לפי חודש:</p>
                    {Array.from({ length: 12 }, (_, i) => {
                      const wd = getWorkingDaysInMonth(selectedYear, i);
                      const monthDate = new Date(selectedYear, i);
                      const daysInMonth = endOfMonth(monthDate).getDate();
                      const weekendDays = daysInMonth - wd - getHolidaysForYear(selectedYear).filter(h => h.date.getMonth() === i).length;
                      const isCurrentMonth = i === today.getMonth() && selectedYear === today.getFullYear();
                      const elapsedThisMonth = monthlyTargets[i]?.daysElapsed || 0;
                      return (
                        <div key={i} className={`flex justify-between items-center text-sm px-2 py-1.5 rounded ${isCurrentMonth ? 'bg-blue-50 border border-blue-200' : 'bg-muted/20'}`}>
                          <span className={`font-medium ${isCurrentMonth ? 'text-blue-700' : ''}`}>
                            {monthDate.toLocaleString('he-IL', { month: 'long' })}
                            {isCurrentMonth && <span className="text-xs text-blue-500 mr-1">({elapsedThisMonth} עברו)</span>}
                          </span>
                          <span className="font-bold text-blue-600">{wd} ימים</span>
                        </div>
                      );
                    })}
                  </div>
                  <div className="border-t pt-2 flex justify-between font-bold text-sm text-blue-700">
                    <span>סה"כ:</span><span>{totalWorkingDaysYear} ימי עבודה</span>
                  </div>
                  <div className="text-xs text-muted-foreground">עברו עד היום: {todayWorkingDaysElapsed} ימים ({((todayWorkingDaysElapsed / totalWorkingDaysYear) * 100).toFixed(1)}% מהשנה)</div>
                </div>
              )}

              {/* Daily Average Drill-down */}
              {drillDownCard === 'daily-avg' && (
                <div className="space-y-3">
                  <div className="bg-purple-50 border border-purple-200 rounded-lg p-3 text-sm space-y-2">
                    <p className="font-semibold text-purple-700">יעד יומי = יעד שנתי ÷ ימי עבודה בשנה</p>
                    <div className="font-mono text-xs bg-white border rounded p-2 space-y-1">
                      <div className="flex justify-between"><span>יעד שנתי:</span><span className="font-bold">₪{annualTarget.toLocaleString(undefined, { maximumFractionDigits: 0 })}</span></div>
                      <div className="flex justify-between"><span>÷ ימי עבודה:</span><span className="font-bold">÷ {totalWorkingDaysYear}</span></div>
                      <div className="border-t pt-1 flex justify-between text-purple-700 font-bold"><span>= יעד יומי:</span><span>₪{(annualTarget / totalWorkingDaysYear).toLocaleString(undefined, { maximumFractionDigits: 0 })}</span></div>
                    </div>
                  </div>
                  <div className="space-y-1">
                    <p className="text-xs font-medium text-muted-foreground border-b pb-1">יעד חודשי לפי ימי עבודה בפועל:</p>
                    {monthlyTargets.map((m, idx) => {
                      const isCurrentMonth = idx === today.getMonth() && selectedYear === today.getFullYear();
                      const isFuture = idx > today.getMonth() && selectedYear === today.getFullYear();
                      return (
                        <div key={m.month} className={`flex justify-between items-center text-sm px-2 py-1.5 rounded ${isCurrentMonth ? 'bg-purple-50 border border-purple-200' : isFuture ? 'opacity-50 bg-muted/10' : 'bg-muted/20'}`}>
                          <span className={`font-medium ${isCurrentMonth ? 'text-purple-700' : ''}`}>
                            {m.monthName}
                            <span className="text-xs text-muted-foreground mr-1">({m.workingDays} ימים)</span>
                          </span>
                          <span className="font-bold text-purple-600">₪{m.targetRevenue.toLocaleString(undefined, { maximumFractionDigits: 0 })}</span>
                        </div>
                      );
                    })}
                  </div>
                  <div className="border-t pt-2 flex justify-between font-bold text-sm text-purple-700">
                    <span>סה"כ שנתי:</span><span>₪{annualTarget.toLocaleString(undefined, { maximumFractionDigits: 0 })}</span>
                  </div>
                </div>
              )}

            </div>
          </ScrollArea>
        </DialogContent>
      </Dialog>
    </DashboardLayout>
  );
}
