import React, { useState, useMemo } from 'react';
import { useQuery } from "@tanstack/react-query";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import DashboardLayout from "@/components/layout/DashboardLayout";
import {
  BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, Legend,
  LineChart, Line, LabelList
} from 'recharts';
import {
  Layers, TrendingUp, TrendingDown, Users, Phone, DollarSign,
  Loader2, AlertTriangle, Filter, ChevronDown, ChevronUp, GitCompare,
  Package, RefreshCw
} from "lucide-react";
import { motion } from "framer-motion";

const MONTH_NAMES: Record<string, string> = {
  '01': 'ינואר', '02': 'פברואר', '03': 'מרץ', '04': 'אפריל',
  '05': 'מאי', '06': 'יוני', '07': 'יולי', '08': 'אוגוסט',
  '09': 'ספטמבר', '10': 'אוקטובר', '11': 'נובמבר', '12': 'דצמבר',
};

interface SummaryRow { dept_code: string; dept_name: string; year: string; revenue: string | number; customer_count: string | number; call_count: string | number; }
interface AgentRow { dept_code: string; dept_name: string; agent_name: string; year: string; revenue: string | number; customer_count: string | number; }
interface CalibratorRow { dept_code: string; dept_name: string; calibrator_name: string; year: string; call_count: string | number; }
interface OverviewData { summary: SummaryRow[]; byAgent: AgentRow[]; byCalibrator: CalibratorRow[]; }

const YEARS = ['2024', '2025', '2026'];
const YEAR_COLORS: Record<string, string> = {
  '2024': '#6366f1',
  '2025': '#10b981',
  '2026': '#f59e0b',
};

function fmt(n: number) {
  if (!n) return '–';
  if (Math.abs(n) >= 1_000_000) return `₪${(n / 1_000_000).toFixed(1)}M`;
  if (Math.abs(n) >= 1_000) return `₪${(n / 1_000).toFixed(0)}K`;
  return `₪${n.toFixed(0)}`;
}
function fmtPct(v: number) {
  if (!isFinite(v) || isNaN(v)) return '–';
  const sign = v > 0 ? '+' : '';
  return `${sign}${v.toFixed(1)}%`;
}
function pctChange(curr: number, prev: number) {
  if (!prev) return NaN;
  return ((curr - prev) / prev) * 100;
}

function PctBadge({ curr, prev }: { curr: number; prev: number }) {
  const pct = pctChange(curr, prev);
  if (isNaN(pct)) return <span className="text-gray-400 text-xs">–</span>;
  const positive = pct >= 0;
  return (
    <span className={`inline-flex items-center gap-0.5 text-xs font-medium ${positive ? 'text-emerald-600' : 'text-red-500'}`}>
      {positive ? <TrendingUp size={11} /> : <TrendingDown size={11} />}
      {fmtPct(pct)}
    </span>
  );
}

interface Calibrator {
  userId: string;
  fullName: string;
  agentCode: string | null;
  calibrationCount: number;
}

interface CalibratorDeptStat {
  id: string;
  doerId: string;
  deptCode: string;
  deptName: string | null;
  year: string;
  customerCount: number;
  callCount: number;
  revenue: number;
  syncedAt: string;
}

export default function DepartmentsPage() {
  const [activeTab, setActiveTab] = useState<'overview' | 'compare' | 'financial' | 'operational'>('overview');
  const [selectedCalibrators, setSelectedCalibrators] = useState<Set<string>>(new Set());
  const [calibSearch, setCalibSearch] = useState('');
  const [showCalibFilter, setShowCalibFilter] = useState(false);
  const [selectedYears, setSelectedYears] = useState<Set<string>>(new Set(YEARS));
  const [selectedDepts, setSelectedDepts] = useState<Set<string>>(new Set());
  const [deptSearch, setDeptSearch] = useState('');
  const [showDeptFilter, setShowDeptFilter] = useState(false);
  const [sortBy, setSortBy] = useState<'revenue' | 'calls' | 'dept'>('revenue');
  const [expandedDepts, setExpandedDepts] = useState<Set<string>>(new Set());
  const [locationFilter, setLocationFilter] = useState<'all' | 'internal' | 'external'>('all');
  const activeChart = sortBy === 'calls' ? 'calls' : 'revenue';

  // Overview tab date filter
  const [ovDateFrom, setOvDateFrom] = useState('');
  const [ovDateTo, setOvDateTo] = useState('');
  const [ovApplied, setOvApplied] = useState({ dateFrom: '', dateTo: '' });

  // Comparison state
  const [cmpAYear, setCmpAYear] = useState('2025');
  const [cmpAMonth, setCmpAMonth] = useState('');
  const [cmpBYear, setCmpBYear] = useState('2024');
  const [cmpBMonth, setCmpBMonth] = useState('');

  // Financial breakdown tab state
  const [finDateFrom, setFinDateFrom] = useState('');
  const [finDateTo, setFinDateTo] = useState('');
  const [finApplied, setFinApplied] = useState({ dateFrom: '', dateTo: '' });

  // Operational breakdown tab state
  const [opDateFrom, setOpDateFrom] = useState('');
  const [opDateTo, setOpDateTo] = useState('');
  const [opApplied, setOpApplied] = useState({ dateFrom: '', dateTo: '' });

  // Overview stats from financial + operational query tables
  const { data: overviewData, isLoading, error } = useQuery<OverviewData>({
    queryKey: ['/api/departments/overview-stats', ovApplied.dateFrom, ovApplied.dateTo],
    queryFn: () => fetch(`/api/departments/overview-stats?dateFrom=${encodeURIComponent(ovApplied.dateFrom)}&dateTo=${encodeURIComponent(ovApplied.dateTo)}`).then(r => r.json()),
    refetchOnWindowFocus: false,
    enabled: activeTab === 'overview',
  });

  const summaryRows     = overviewData?.summary      ?? [];
  const byAgentRows     = overviewData?.byAgent       ?? [];
  const byCalibratorRows = overviewData?.byCalibrator ?? [];

  const { data: calibratorsData = [] } = useQuery<Calibrator[]>({
    queryKey: ['/api/calibrators'],
    refetchOnWindowFocus: false,
  });

  type MonthlyRow = { month: string; revenue: number; count: number };
  type MonthlyResp = { companyMonthly: MonthlyRow[]; agentMonthly: Record<string, MonthlyRow[]> };
  type MonthlyCallStat = { yearMonth: string; callCount: number };

  // Monthly service call stats — used only by the Compare tab
  const { data: monthlyCallStatsData } = useQuery<MonthlyCallStat[]>({
    queryKey: ['/api/monthly-call-stats'],
    queryFn: () => fetch('/api/monthly-call-stats').then(r => r.json()),
    refetchOnWindowFocus: false,
    enabled: activeTab === 'compare',
  });

  const getCallCount = (year: string, month: string): number => {
    if (!monthlyCallStatsData) return 0;
    if (month) {
      const row = monthlyCallStatsData.find(r => r.yearMonth === `${year}-${month}`);
      return row?.callCount ?? 0;
    }
    return monthlyCallStatsData
      .filter(r => r.yearMonth.startsWith(`${year}-`))
      .reduce((s, r) => s + r.callCount, 0);
  };

  // Financial dept breakdown (lazy — only fetches when tab is active)
  const { data: finBreakdownRaw = [] } = useQuery<any[]>({
    queryKey: ['/api/departments/financial-breakdown', finApplied.dateFrom, finApplied.dateTo],
    queryFn: () => fetch(`/api/departments/financial-breakdown?dateFrom=${encodeURIComponent(finApplied.dateFrom)}&dateTo=${encodeURIComponent(finApplied.dateTo)}`).then(r => r.json()),
    refetchOnWindowFocus: false,
    enabled: activeTab === 'financial',
  });

  // Operational dept breakdown
  const { data: opBreakdownRaw = [] } = useQuery<any[]>({
    queryKey: ['/api/departments/operational-breakdown', opApplied.dateFrom, opApplied.dateTo],
    queryFn: () => fetch(`/api/departments/operational-breakdown?dateFrom=${encodeURIComponent(opApplied.dateFrom)}&dateTo=${encodeURIComponent(opApplied.dateTo)}`).then(r => r.json()),
    refetchOnWindowFocus: false,
    enabled: activeTab === 'operational',
  });

  // Monthly revenue for comparison
  const { data: monthlyA } = useQuery<MonthlyResp>({
    queryKey: ['/api/agents/monthly-revenue', cmpAYear],
    queryFn: () => fetch(`/api/agents/monthly-revenue?year=${cmpAYear}`).then(r => r.json()),
    refetchOnWindowFocus: false,
  });
  const { data: monthlyB } = useQuery<MonthlyResp>({
    queryKey: ['/api/agents/monthly-revenue', cmpBYear],
    queryFn: () => fetch(`/api/agents/monthly-revenue?year=${cmpBYear}`).then(r => r.json()),
    refetchOnWindowFocus: false,
    enabled: cmpBYear !== cmpAYear,
  });

  // Build comparison data
  const compareData = useMemo(() => {
    const monthsA = monthlyA?.companyMonthly ?? [];
    const monthsB = (cmpBYear === cmpAYear ? monthlyA?.companyMonthly : monthlyB?.companyMonthly) ?? [];
    const agentsA = monthlyA?.agentMonthly ?? {};
    const agentsB = (cmpBYear === cmpAYear ? monthlyA?.agentMonthly : monthlyB?.agentMonthly) ?? {};

    // Build per-agent breakdown for a given period
    const agentBreakdown = (
      agentData: Record<string, MonthlyRow[]>,
      year: string, month: string
    ) => Object.entries(agentData).map(([agent, rows]) => {
      const rel = month
        ? rows.filter(r => r.month === `${year}-${month}`)
        : rows;
      return {
        agent,
        revenue: rel.reduce((s, r) => s + r.revenue, 0),
        count: rel.reduce((s, r) => s + r.count, 0),
      };
    }).filter(r => r.revenue > 0 || r.count > 0)
      .sort((a, b) => b.revenue - a.revenue);

    if (cmpAMonth && cmpBMonth) {
      const a = monthsA.find(m => m.month === `${cmpAYear}-${cmpAMonth}`);
      const b = monthsB.find(m => m.month === `${cmpBYear}-${cmpBMonth}`);
      return {
        mode: 'month' as const,
        labelA: `${MONTH_NAMES[cmpAMonth]} ${cmpAYear}`,
        labelB: `${MONTH_NAMES[cmpBMonth]} ${cmpBYear}`,
        revenueA: a?.revenue ?? 0, revenueB: b?.revenue ?? 0,
        callsA: getCallCount(cmpAYear, cmpAMonth),
        callsB: getCallCount(cmpBYear, cmpBMonth),
        chart: [],
        agentBreakdownA: agentBreakdown(agentsA, cmpAYear, cmpAMonth),
        agentBreakdownB: agentBreakdown(agentsB, cmpBYear, cmpBMonth),
      };
    }

    if (cmpAMonth || cmpBMonth) {
      const mA = cmpAMonth ? monthsA.find(m => m.month === `${cmpAYear}-${cmpAMonth}`) : null;
      const mB = cmpBMonth ? monthsB.find(m => m.month === `${cmpBYear}-${cmpBMonth}`) : null;
      const totalA = mA ? mA.revenue : monthsA.reduce((s, m) => s + m.revenue, 0);
      const totalB = mB ? mB.revenue : monthsB.reduce((s, m) => s + m.revenue, 0);
      return {
        mode: 'single' as const,
        labelA: cmpAMonth ? `${MONTH_NAMES[cmpAMonth]} ${cmpAYear}` : `שנת ${cmpAYear}`,
        labelB: cmpBMonth ? `${MONTH_NAMES[cmpBMonth]} ${cmpBYear}` : `שנת ${cmpBYear}`,
        revenueA: totalA, revenueB: totalB,
        callsA: getCallCount(cmpAYear, cmpAMonth),
        callsB: getCallCount(cmpBYear, cmpBMonth),
        chart: [],
        agentBreakdownA: agentBreakdown(agentsA, cmpAYear, cmpAMonth),
        agentBreakdownB: agentBreakdown(agentsB, cmpBYear, cmpBMonth),
      };
    }

    // Year vs year
    const allMonths = Array.from({ length: 12 }, (_, i) => String(i + 1).padStart(2, '0'));
    const chart = allMonths.map(m => {
      const a = monthsA.find(x => x.month === `${cmpAYear}-${m}`);
      const b = monthsB.find(x => x.month === `${cmpBYear}-${m}`);
      return {
        month: MONTH_NAMES[m],
        [`הכנסה ${cmpAYear}`]: a?.revenue ?? 0,
        [`הכנסה ${cmpBYear}`]: b?.revenue ?? 0,
        [`קריאות ${cmpAYear}`]: getCallCount(cmpAYear, m),
        [`קריאות ${cmpBYear}`]: getCallCount(cmpBYear, m),
      };
    }).filter(r => Number(r[`הכנסה ${cmpAYear}`]) > 0 || Number(r[`הכנסה ${cmpBYear}`]) > 0);

    const totalA = monthsA.reduce((s, m) => s + m.revenue, 0);
    const totalB = monthsB.reduce((s, m) => s + m.revenue, 0);
    return {
      mode: 'year' as const,
      labelA: `שנת ${cmpAYear}`,
      labelB: `שנת ${cmpBYear}`,
      revenueA: totalA, revenueB: totalB,
      callsA: getCallCount(cmpAYear, ''),
      callsB: getCallCount(cmpBYear, ''),
      chart,
      agentBreakdownA: agentBreakdown(agentsA, cmpAYear, ''),
      agentBreakdownB: agentBreakdown(agentsB, cmpBYear, ''),
    };
  }, [monthlyA, monthlyB, monthlyCallStatsData, cmpAYear, cmpAMonth, cmpBYear, cmpBMonth]);

  // only calibrators with a name, sorted
  const calibrators = useMemo(() => {
    return calibratorsData
      .filter(c => c.fullName && c.fullName.trim().length > 0)
      .sort((a, b) => a.fullName!.localeCompare(b.fullName!, 'he'));
  }, [calibratorsData]);

  // Whether we are filtering by calibrators
  const calibratorFilterActive = selectedCalibrators.size > 0;

  // Map userId → calibrator fullName (for matching against byCalibrator rows)
  const selectedCalibratorNames = useMemo(() => {
    const names = new Set<string>();
    calibratorsData.forEach(c => {
      if (selectedCalibrators.has(c.userId) && c.fullName) names.add(c.fullName);
    });
    return names;
  }, [selectedCalibrators, calibratorsData]);

  const allDepts = useMemo(() => {
    const map = new Map<string, string>();
    summaryRows.forEach(r => { if (r.dept_code) map.set(r.dept_code, r.dept_name || r.dept_code); });
    byCalibratorRows.forEach(r => { if (r.dept_code && !map.has(r.dept_code)) map.set(r.dept_code, r.dept_name || r.dept_code); });
    return Array.from(map.entries()).sort((a, b) => a[0].localeCompare(b[0]));
  }, [summaryRows, byCalibratorRows]);

  // Location filter helper
  const matchesLocation = (deptCode: string) => {
    if (locationFilter === 'all') return true;
    const last = deptCode?.slice(-1) ?? '';
    if (locationFilter === 'external') return ['7', '8'].includes(last);
    if (locationFilter === 'internal') return ['0', '1'].includes(last);
    return true;
  };

  const matchesDeptYear = (r: { year: string; dept_code: string }) => {
    if (!selectedYears.has(r.year)) return false;
    if (selectedDepts.size > 0 && !selectedDepts.has(r.dept_code)) return false;
    if (!matchesLocation(r.dept_code)) return false;
    return true;
  };

  // Per-dept-per-year map: revenue from financial, calls from operational
  const deptYearMap = useMemo(() => {
    const map = new Map<string, { deptCode: string; deptName: string; byYear: Record<string, { revenue: number; calls: number; customers: number }> }>();

    summaryRows.filter(matchesDeptYear).forEach(r => {
      if (!map.has(r.dept_code)) map.set(r.dept_code, { deptCode: r.dept_code, deptName: r.dept_name || r.dept_code, byYear: {} });
      const entry = map.get(r.dept_code)!;
      if (!entry.byYear[r.year]) entry.byYear[r.year] = { revenue: 0, calls: 0, customers: 0 };
      entry.byYear[r.year].revenue += Number(r.revenue) || 0;
      entry.byYear[r.year].customers += Number(r.customer_count) || 0;
    });

    byCalibratorRows.filter(r => {
      if (!matchesDeptYear(r)) return false;
      if (calibratorFilterActive && !selectedCalibratorNames.has(r.calibrator_name)) return false;
      return true;
    }).forEach(r => {
      if (!map.has(r.dept_code)) map.set(r.dept_code, { deptCode: r.dept_code, deptName: r.dept_name || r.dept_code, byYear: {} });
      const entry = map.get(r.dept_code)!;
      if (!entry.byYear[r.year]) entry.byYear[r.year] = { revenue: 0, calls: 0, customers: 0 };
      entry.byYear[r.year].calls += Number(r.call_count) || 0;
    });

    return map;
  }, [summaryRows, byCalibratorRows, selectedYears, selectedDepts, locationFilter, calibratorFilterActive, selectedCalibratorNames]);

  const visibleYears = YEARS.filter(y => selectedYears.has(y));
  const effectiveSortYear = visibleYears[0] || '2025';

  const depts = useMemo(() => {
    const arr = Array.from(deptYearMap.values());
    return arr.sort((a, b) => {
      if (sortBy === 'dept') return a.deptCode.localeCompare(b.deptCode);
      const aVal = a.byYear[effectiveSortYear]?.[sortBy === 'revenue' ? 'revenue' : 'calls'] ?? 0;
      const bVal = b.byYear[effectiveSortYear]?.[sortBy === 'revenue' ? 'revenue' : 'calls'] ?? 0;
      return bVal - aVal;
    });
  }, [deptYearMap, sortBy, effectiveSortYear]);

  // Year totals from deptYearMap
  const yearTotals = useMemo(() => {
    const totals: Record<string, { revenue: number; calls: number; customers: number }> = {};
    YEARS.forEach(y => { totals[y] = { revenue: 0, calls: 0, customers: 0 }; });
    deptYearMap.forEach(dept => {
      Object.entries(dept.byYear).forEach(([y, v]) => {
        if (totals[y]) { totals[y].revenue += v.revenue; totals[y].calls += v.calls; totals[y].customers += v.customers; }
      });
    });
    return totals;
  }, [deptYearMap]);

  // Agent breakdown per dept (from byAgentRows — revenue only)
  const agentsByDept = useMemo(() => {
    const map = new Map<string, { agentName: string; byYear: Record<string, { revenue: number }> }[]>();
    byAgentRows.forEach(r => {
      if (!selectedYears.has(r.year)) return;
      if (selectedDepts.size > 0 && !selectedDepts.has(r.dept_code)) return;
      if (!matchesLocation(r.dept_code)) return;
      if (!map.has(r.dept_code)) map.set(r.dept_code, []);
      const list = map.get(r.dept_code)!;
      let agent = list.find(a => a.agentName === r.agent_name);
      if (!agent) { agent = { agentName: r.agent_name || '(ללא סוכן)', byYear: {} }; list.push(agent); }
      if (!agent.byYear[r.year]) agent.byYear[r.year] = { revenue: 0 };
      agent.byYear[r.year].revenue += Number(r.revenue) || 0;
    });
    map.forEach(list => list.sort((a, b) => {
      const aRev = Object.values(a.byYear).reduce((s, v) => s + v.revenue, 0);
      const bRev = Object.values(b.byYear).reduce((s, v) => s + v.revenue, 0);
      return bRev - aRev;
    }));
    return map;
  }, [byAgentRows, selectedYears, selectedDepts, locationFilter]);

  // Calibrator call totals per userId — for the dropdown display
  const doerCallTotals = useMemo(() => {
    const totals: Record<string, number> = {};
    byCalibratorRows.forEach(r => {
      const matched = calibratorsData.find(c => c.fullName === r.calibrator_name);
      if (matched) totals[matched.userId] = (totals[matched.userId] || 0) + (Number(r.call_count) || 0);
    });
    return totals;
  }, [byCalibratorRows, calibratorsData]);

  const toggleCalibrator = (uid: string) => {
    setSelectedCalibrators(prev => {
      const next = new Set(prev);
      if (next.has(uid)) next.delete(uid); else next.add(uid);
      return next;
    });
  };
  const toggleYear = (y: string) => {
    setSelectedYears(prev => {
      const next = new Set(prev);
      if (next.has(y)) { if (next.size > 1) next.delete(y); } else next.add(y);
      return next;
    });
  };
  const toggleDeptFilter = (code: string) => {
    setSelectedDepts(prev => {
      const next = new Set(prev);
      if (next.has(code)) next.delete(code); else next.add(code);
      return next;
    });
  };
  const toggleDept = (code: string) => {
    setExpandedDepts(prev => {
      const next = new Set(prev);
      if (next.has(code)) next.delete(code); else next.add(code);
      return next;
    });
  };

  const hasData = summaryRows.length > 0 || byCalibratorRows.length > 0;

  return (
    <DashboardLayout>
      <div className="p-6 space-y-6" dir="rtl">
        {/* Header */}
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="p-2 bg-indigo-100 rounded-lg">
              <Layers className="h-6 w-6 text-indigo-600" />
            </div>
            <div>
              <h1 className="text-2xl font-bold text-gray-900">ביצוע מחלקות</h1>
              <p className="text-sm text-gray-500">השוואה בין שנים · {depts.length} מחלקות</p>
            </div>
          </div>
          {hasData && (
            <Badge variant="outline" className="text-xs">
              {(summaryRows.length + byCalibratorRows.length).toLocaleString()} שורות נתונים
            </Badge>
          )}
        </div>

        {/* Tabs */}
        <div className="flex gap-2 border-b border-gray-200">
          <button
            onClick={() => setActiveTab('overview')}
            data-testid="tab-overview"
            className={`flex items-center gap-1.5 px-4 py-2 text-sm font-medium border-b-2 transition-colors ${activeTab === 'overview' ? 'border-indigo-600 text-indigo-600' : 'border-transparent text-gray-500 hover:text-gray-700'}`}
          >
            <Layers size={15} /> סקירה כללית
          </button>
          <button
            onClick={() => setActiveTab('compare')}
            data-testid="tab-compare"
            className={`flex items-center gap-1.5 px-4 py-2 text-sm font-medium border-b-2 transition-colors ${activeTab === 'compare' ? 'border-indigo-600 text-indigo-600' : 'border-transparent text-gray-500 hover:text-gray-700'}`}
          >
            <GitCompare size={15} /> השוואת תקופות
          </button>
          <button
            onClick={() => setActiveTab('financial')}
            data-testid="tab-financial"
            className={`flex items-center gap-1.5 px-4 py-2 text-sm font-medium border-b-2 transition-colors ${activeTab === 'financial' ? 'border-emerald-600 text-emerald-600' : 'border-transparent text-gray-500 hover:text-gray-700'}`}
          >
            <DollarSign size={15} /> כספי מפורט
          </button>
          <button
            onClick={() => setActiveTab('operational')}
            data-testid="tab-operational"
            className={`flex items-center gap-1.5 px-4 py-2 text-sm font-medium border-b-2 transition-colors ${activeTab === 'operational' ? 'border-blue-600 text-blue-600' : 'border-transparent text-gray-500 hover:text-gray-700'}`}
          >
            <Package size={15} /> קליטות מפורט
          </button>
        </div>

        {activeTab === 'compare' && (
          <CompareTab
            cmpAYear={cmpAYear} setCmpAYear={setCmpAYear}
            cmpAMonth={cmpAMonth} setCmpAMonth={setCmpAMonth}
            cmpBYear={cmpBYear} setCmpBYear={setCmpBYear}
            cmpBMonth={cmpBMonth} setCmpBMonth={setCmpBMonth}
            compareData={compareData}
            fmt={fmt}
            monthlyCallStatsData={monthlyCallStatsData}
          />
        )}

        {activeTab === 'financial' && (
          <FinancialDeptTab
            rows={finBreakdownRaw}
            dateFrom={finDateFrom} setDateFrom={setFinDateFrom}
            dateTo={finDateTo} setDateTo={setFinDateTo}
            onApply={() => setFinApplied({ dateFrom: finDateFrom, dateTo: finDateTo })}
          />
        )}

        {activeTab === 'operational' && (
          <OperationalDeptTab
            rows={opBreakdownRaw}
            dateFrom={opDateFrom} setDateFrom={setOpDateFrom}
            dateTo={opDateTo} setDateTo={setOpDateTo}
            onApply={() => setOpApplied({ dateFrom: opDateFrom, dateTo: opDateTo })}
          />
        )}

        {activeTab === 'overview' && (
        <React.Fragment>

        {/* Date range filter */}
        <Card>
          <CardContent className="pt-3 pb-3">
            <div className="flex flex-wrap gap-3 items-end" dir="rtl">
              <div>
                <label className="text-xs text-gray-500 block mb-1">מתאריך</label>
                <input type="date" value={ovDateFrom} onChange={e => setOvDateFrom(e.target.value)}
                  className="border border-gray-200 rounded-lg px-3 py-1.5 text-sm focus:outline-none focus:border-indigo-400"
                  data-testid="ov-date-from" />
              </div>
              <div>
                <label className="text-xs text-gray-500 block mb-1">עד תאריך</label>
                <input type="date" value={ovDateTo} onChange={e => setOvDateTo(e.target.value)}
                  className="border border-gray-200 rounded-lg px-3 py-1.5 text-sm focus:outline-none focus:border-indigo-400"
                  data-testid="ov-date-to" />
              </div>
              <button onClick={() => setOvApplied({ dateFrom: ovDateFrom, dateTo: ovDateTo })}
                data-testid="ov-apply"
                className="flex items-center gap-1.5 px-4 py-1.5 bg-indigo-600 text-white text-sm font-medium rounded-lg hover:bg-indigo-700 transition-colors">
                <RefreshCw size={14} /> החל טווח
              </button>
              {(ovApplied.dateFrom || ovApplied.dateTo) && (
                <button onClick={() => { setOvDateFrom(''); setOvDateTo(''); setOvApplied({ dateFrom: '', dateTo: '' }); }}
                  className="px-3 py-1.5 text-sm text-gray-500 border border-gray-200 rounded-lg hover:bg-gray-50">
                  נקה טווח
                </button>
              )}
              {(ovApplied.dateFrom || ovApplied.dateTo) && (
                <span className="text-xs text-indigo-600 bg-indigo-50 px-2 py-1 rounded-lg border border-indigo-200">
                  מסונן: {ovApplied.dateFrom || '—'} עד {ovApplied.dateTo || '—'}
                </span>
              )}
            </div>
          </CardContent>
        </Card>

        {/* Filters */}
        <Card>
          <CardContent className="pt-4 pb-3">
            <div className="flex flex-wrap gap-4 items-start">
              {/* Year filter */}
              <div>
                <p className="text-xs font-medium text-gray-500 mb-1.5">שנה</p>
                <div className="flex gap-1.5">
                  {YEARS.map(y => (
                    <button key={y} onClick={() => toggleYear(y)}
                      data-testid={`filter-year-${y}`}
                      className={`px-3 py-1 rounded-full text-sm font-medium transition-all border ${selectedYears.has(y)
                        ? 'text-white border-transparent'
                        : 'bg-white text-gray-500 border-gray-200'}`}
                      style={selectedYears.has(y) ? { backgroundColor: YEAR_COLORS[y], borderColor: YEAR_COLORS[y] } : {}}>
                      {y}
                    </button>
                  ))}
                </div>
              </div>

              {/* Calibrator filter */}
              {calibratorsData.length > 0 && (
                <div className="relative">
                  <p className="text-xs font-medium text-gray-500 mb-1.5">
                    <Users size={11} className="inline ml-1" />כייל
                    {selectedCalibrators.size > 0 && (
                      <button onClick={() => setSelectedCalibrators(new Set())} className="mr-2 text-indigo-600 hover:underline">
                        נקה ({selectedCalibrators.size})
                      </button>
                    )}
                  </p>
                  <button
                    onClick={() => setShowCalibFilter(v => !v)}
                    data-testid="btn-calib-filter"
                    className={`flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-medium border transition-all ${selectedCalibrators.size > 0 ? 'bg-indigo-600 text-white border-indigo-600' : 'bg-white text-gray-600 border-gray-200 hover:border-indigo-300'}`}
                  >
                    <Filter size={11} />
                    {selectedCalibrators.size > 0 ? `${selectedCalibrators.size} כיילים נבחרו` : 'כל הכיילים'}
                    <ChevronDown size={11} className={`transition-transform ${showCalibFilter ? 'rotate-180' : ''}`} />
                  </button>

                  {showCalibFilter && (
                    <div className="absolute top-full mt-1 right-0 z-50 bg-white border border-gray-200 rounded-xl shadow-lg w-72 p-3">
                      <input
                        autoFocus
                        type="text"
                        placeholder="חפש כייל..."
                        value={calibSearch}
                        onChange={e => setCalibSearch(e.target.value)}
                        className="w-full text-sm border border-gray-200 rounded-lg px-3 py-1.5 mb-2 text-right outline-none focus:border-indigo-400"
                        data-testid="input-calib-search"
                      />
                      <div className="flex justify-between mb-2">
                        <button onClick={() => setSelectedCalibrators(new Set(calibratorsData.map(c => c.userId)))} className="text-xs text-indigo-600 hover:underline">בחר הכל</button>
                        <button onClick={() => setSelectedCalibrators(new Set())} className="text-xs text-gray-500 hover:underline">נקה הכל</button>
                      </div>
                      <div className="max-h-56 overflow-y-auto space-y-0.5">
                        {calibratorsData
                          .filter(c => !!c.fullName && (!calibSearch || c.fullName.includes(calibSearch)))
                          .sort((a, b) => (doerCallTotals[b.userId] || 0) - (doerCallTotals[a.userId] || 0))
                          .map(c => (
                            <button
                              key={c.userId}
                              onClick={() => toggleCalibrator(c.userId)}
                              data-testid={`filter-calib-${c.userId}`}
                              className={`w-full flex justify-between items-center px-2.5 py-1.5 rounded-lg text-xs transition-colors ${selectedCalibrators.has(c.userId) ? 'bg-indigo-50 text-indigo-700 font-medium' : 'hover:bg-gray-50 text-gray-700'}`}
                            >
                              <span>{c.fullName}</span>
                              <span className="text-gray-400 font-mono mr-2">{(doerCallTotals[c.userId] || 0).toLocaleString()} קר'</span>
                            </button>
                          ))}
                      </div>
                      <button
                        onClick={() => setShowCalibFilter(false)}
                        className="mt-2 w-full text-xs text-center py-1.5 bg-gray-100 hover:bg-gray-200 rounded-lg text-gray-600 transition-colors"
                      >
                        סגור
                      </button>
                    </div>
                  )}
                </div>
              )}

              {/* Department filter */}
              {allDepts.length > 0 && (
                <div className="relative">
                  <p className="text-xs font-medium text-gray-500 mb-1.5">
                    <Layers size={11} className="inline ml-1" />מחלקה
                    {selectedDepts.size > 0 && (
                      <button onClick={() => setSelectedDepts(new Set())} className="mr-2 text-indigo-600 hover:underline">
                        נקה ({selectedDepts.size})
                      </button>
                    )}
                  </p>
                  <button
                    onClick={() => setShowDeptFilter(v => !v)}
                    data-testid="btn-dept-filter"
                    className={`flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-medium border transition-all ${selectedDepts.size > 0 ? 'bg-indigo-600 text-white border-indigo-600' : 'bg-white text-gray-600 border-gray-200 hover:border-indigo-300'}`}
                  >
                    <Filter size={11} />
                    {selectedDepts.size > 0 ? `${selectedDepts.size} מחלקות נבחרו` : 'כל המחלקות'}
                    <ChevronDown size={11} className={`transition-transform ${showDeptFilter ? 'rotate-180' : ''}`} />
                  </button>

                  {showDeptFilter && (
                    <div className="absolute top-full mt-1 right-0 z-50 bg-white border border-gray-200 rounded-xl shadow-lg w-72 p-3">
                      <input
                        autoFocus
                        type="text"
                        placeholder="חפש מחלקה..."
                        value={deptSearch}
                        onChange={e => setDeptSearch(e.target.value)}
                        className="w-full text-sm border border-gray-200 rounded-lg px-3 py-1.5 mb-2 text-right outline-none focus:border-indigo-400"
                        data-testid="input-dept-search"
                      />
                      <div className="flex justify-between mb-2">
                        <button onClick={() => setSelectedDepts(new Set(allDepts.map(([c]) => c)))} className="text-xs text-indigo-600 hover:underline">בחר הכל</button>
                        <button onClick={() => setSelectedDepts(new Set())} className="text-xs text-gray-500 hover:underline">נקה הכל</button>
                      </div>
                      <div className="max-h-56 overflow-y-auto space-y-0.5">
                        {allDepts
                          .filter(([code, name]) => !deptSearch || name.includes(deptSearch) || code.includes(deptSearch))
                          .map(([code, name]) => (
                            <button
                              key={code}
                              onClick={() => toggleDeptFilter(code)}
                              data-testid={`filter-dept-${code}`}
                              className={`w-full flex items-center justify-between px-2.5 py-1.5 rounded-lg text-xs text-right transition-colors ${selectedDepts.has(code) ? 'bg-indigo-50 text-indigo-700 font-medium' : 'hover:bg-gray-50 text-gray-700'}`}
                            >
                              <span>{name || code}</span>
                              <span className="text-gray-400 font-mono">{code}</span>
                            </button>
                          ))}
                      </div>
                      <button
                        onClick={() => setShowDeptFilter(false)}
                        className="mt-2 w-full text-xs text-center py-1.5 bg-gray-100 hover:bg-gray-200 rounded-lg text-gray-600 transition-colors"
                      >
                        סגור
                      </button>
                    </div>
                  )}
                </div>
              )}

              {/* Location filter */}
              <div>
                <p className="text-xs font-medium text-gray-500 mb-1.5">מיקום</p>
                <div className="flex gap-1.5">
                  {([
                    { k: 'all', l: 'הכל' },
                    { k: 'internal', l: 'פנים' },
                    { k: 'external', l: 'חוץ' },
                  ] as const).map(({ k, l }) => (
                    <button key={k}
                      onClick={() => setLocationFilter(k)}
                      data-testid={`location-filter-${k}`}
                      className={`px-3 py-1 rounded-full text-xs font-medium border transition-all ${locationFilter === k
                        ? 'bg-gray-800 text-white border-gray-800'
                        : 'bg-white text-gray-500 border-gray-200 hover:border-gray-400'}`}>
                      {l}
                    </button>
                  ))}
                </div>
              </div>

              {/* Sort */}
              <div className="mr-auto">
                <p className="text-xs font-medium text-gray-500 mb-1.5">מיון לפי</p>
                <div className="flex gap-1.5">
                  {[{ k: 'revenue', l: 'הכנסה' }, { k: 'calls', l: 'קריאות' }, { k: 'dept', l: 'מחלקה' }].map(({ k, l }) => (
                    <button key={k}
                      onClick={() => setSortBy(k as any)}
                      data-testid={`sort-${k}`}
                      className={`px-3 py-1 rounded-full text-xs font-medium border transition-all ${sortBy === k
                        ? 'bg-gray-800 text-white border-gray-800'
                        : 'bg-white text-gray-500 border-gray-200'}`}>
                      {l}
                    </button>
                  ))}
                </div>
              </div>
            </div>
          </CardContent>
        </Card>

        {/* Banner: calibrator mode active */}
        {calibratorFilterActive && (
          <div className="flex items-center gap-2 px-4 py-2.5 bg-indigo-50 border border-indigo-200 rounded-xl text-sm text-indigo-700">
            <Users size={15} className="shrink-0" />
            <span>
              מציג עבודה בפועל לפי כייל — הכנסה וקריאות משויכות למי שביצע את הכיול
              {Array.from(selectedCalibrators).map(uid => {
                const c = calibratorsData.find(x => x.userId === uid);
                return c ? <strong key={uid} className="mx-1">{c.fullName}</strong> : null;
              })}
            </span>
            {byCalibratorRows.length === 0 && (
              <span className="mr-auto text-xs text-indigo-500 bg-indigo-100 px-2 py-1 rounded-lg">
                יש לסנכרן שאילתא תפעולית עם --operational-query
              </span>
            )}
          </div>
        )}

        {isLoading ? (
          <div className="flex justify-center items-center h-48">
            <Loader2 className="h-8 w-8 animate-spin text-indigo-500" />
          </div>
        ) : error ? (
          <div className="flex items-center gap-2 text-red-500 p-4">
            <AlertTriangle size={18} />
            <span>שגיאה בטעינת נתונים</span>
          </div>
        ) : !hasData ? (
          <Card>
            <CardContent className="pt-10 pb-10 text-center text-gray-500">
              <Layers className="h-12 w-12 mx-auto mb-3 text-gray-300" />
              <p className="font-medium mb-1">אין נתוני מחלקות עדיין</p>
              <p className="text-sm">יש להריץ סינכרון מחלקות מהמחשב המקומי:</p>
              <code className="block mt-2 bg-gray-100 rounded px-3 py-2 text-xs text-gray-700 max-w-md mx-auto">
                py sync-customer-data.py --departments
              </code>
            </CardContent>
          </Card>
        ) : (
          <>
            {/* Year Summary Cards */}
            <div className="grid grid-cols-3 gap-4">
              {visibleYears.map((y, i) => {
                const prev = visibleYears[i - 1];
                const t = yearTotals[y];
                const tp = prev ? yearTotals[prev] : null;
                return (
                  <motion.div key={y} initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: i * 0.08 }}>
                    <Card className="border-t-4" style={{ borderTopColor: YEAR_COLORS[y] }}>
                      <CardHeader className="pb-2 pt-4">
                        <CardTitle className="text-base font-bold" style={{ color: YEAR_COLORS[y] }}>{y}</CardTitle>
                      </CardHeader>
                      <CardContent className="space-y-3 pb-4">
                        <div>
                          <div className="flex items-center gap-1 text-gray-500 text-xs mb-0.5">
                            <DollarSign size={11} /> הכנסה כוללת
                          </div>
                          <div className="text-xl font-bold text-gray-900">{fmt(t.revenue)}</div>
                          {tp && <PctBadge curr={t.revenue} prev={tp.revenue} />}
                        </div>
                        <div className="grid grid-cols-2 gap-2 pt-1 border-t border-gray-100">
                          <div>
                            <div className="flex items-center gap-1 text-gray-500 text-xs mb-0.5">
                              <Phone size={11} /> קריאות
                            </div>
                            <div className="text-lg font-semibold">{t.calls.toLocaleString()}</div>
                            {tp && <PctBadge curr={t.calls} prev={tp.calls} />}
                          </div>
                          <div>
                            <div className="flex items-center gap-1 text-gray-500 text-xs mb-0.5">
                              <Users size={11} /> לקוחות
                            </div>
                            <div className="text-lg font-semibold">{(yearTotals[y]?.customers ?? 0).toLocaleString()}</div>
                          </div>
                        </div>
                      </CardContent>
                    </Card>
                  </motion.div>
                );
              })}
            </div>

            {/* Department Table */}
            <Card>
              <CardHeader className="pb-2">
                <CardTitle className="text-base">פירוט לפי מחלקה</CardTitle>
              </CardHeader>
              <CardContent className="p-0">
                <div className="overflow-x-auto">
                  <table className="w-full text-sm">
                    <thead>
                      <tr className="border-b bg-gray-50">
                        <th className="text-right px-4 py-2.5 font-medium text-gray-600 w-6"></th>
                        <th className="text-right px-4 py-2.5 font-medium text-gray-600 min-w-[160px]">מחלקה</th>
                        {visibleYears.map(y => (
                          <React.Fragment key={y}>
                            <th className="text-center px-3 py-2.5 font-medium" style={{ color: YEAR_COLORS[y] }}>
                              הכנסה {y}
                            </th>
                            <th className="text-center px-3 py-2.5 font-medium" style={{ color: YEAR_COLORS[y] }}>
                              קריאות {y}
                            </th>
                          </React.Fragment>
                        ))}
                        {visibleYears.length >= 2 && (
                          <>
                            <th className="text-center px-3 py-2.5 font-medium text-gray-500">% הכנסה</th>
                            <th className="text-center px-3 py-2.5 font-medium text-gray-500">% קריאות</th>
                          </>
                        )}
                      </tr>
                    </thead>
                    <tbody>
                      {depts.map((dept, idx) => {
                        const lastY = visibleYears[visibleYears.length - 1];
                        const prevY = visibleYears[visibleYears.length - 2];
                        const expanded = expandedDepts.has(dept.deptCode);
                        const agentList = agentsByDept.get(dept.deptCode) || [];
                        return (
                          <React.Fragment key={dept.deptCode}>
                            <motion.tr
                              initial={{ opacity: 0 }} animate={{ opacity: 1 }} transition={{ delay: idx * 0.02 }}
                              className={`border-b hover:bg-gray-50 cursor-pointer ${idx % 2 === 0 ? 'bg-white' : 'bg-gray-50/50'}`}
                              onClick={() => toggleDept(dept.deptCode)}
                              data-testid={`dept-row-${dept.deptCode}`}
                            >
                              <td className="px-4 py-2.5 text-gray-400">
                                {agentList.length > 0 ? (expanded ? <ChevronUp size={14} /> : <ChevronDown size={14} />) : null}
                              </td>
                              <td className="px-4 py-2.5">
                                <div className="font-medium text-gray-900">{dept.deptName}</div>
                                <div className="text-xs text-gray-400">{dept.deptCode}</div>
                              </td>
                              {visibleYears.map(y => (
                                <React.Fragment key={y}>
                                  <td className="px-3 py-2.5 text-center font-mono font-medium">
                                    {fmt(dept.byYear[y]?.revenue ?? 0)}
                                  </td>
                                  <td className="px-3 py-2.5 text-center">
                                    {(dept.byYear[y]?.calls ?? 0).toLocaleString()}
                                  </td>
                                </React.Fragment>
                              ))}
                              {visibleYears.length >= 2 && (
                                <>
                                  <td className="px-3 py-2.5 text-center">
                                    <PctBadge
                                      curr={dept.byYear[lastY]?.revenue ?? 0}
                                      prev={dept.byYear[prevY]?.revenue ?? 0}
                                    />
                                  </td>
                                  <td className="px-3 py-2.5 text-center">
                                    <PctBadge
                                      curr={dept.byYear[lastY]?.calls ?? 0}
                                      prev={dept.byYear[prevY]?.calls ?? 0}
                                    />
                                  </td>
                                </>
                              )}
                            </motion.tr>

                            {/* Agent revenue breakdown */}
                            {expanded && agentList.map(agent => (
                              <tr key={agent.agentName} className="border-b bg-indigo-50/40 text-xs">
                                <td></td>
                                <td className="px-4 py-2 pr-8 text-gray-600">
                                  <span className="text-gray-400 ml-1">↳</span>
                                  {agent.agentName}
                                </td>
                                {visibleYears.map(y => (
                                  <React.Fragment key={y}>
                                    <td className="px-3 py-2 text-center text-gray-600 font-mono">
                                      {fmt(agent.byYear[y]?.revenue ?? 0)}
                                    </td>
                                    <td className="px-3 py-2 text-center text-gray-400">—</td>
                                  </React.Fragment>
                                ))}
                                {visibleYears.length >= 2 && <><td></td><td></td></>}
                              </tr>
                            ))}
                          </React.Fragment>
                        );
                      })}
                    </tbody>

                    {/* Totals row */}
                    <tfoot>
                      <tr className="border-t-2 border-gray-300 bg-gray-100 font-bold">
                        <td></td>
                        <td className="px-4 py-3 text-gray-800">סה"כ</td>
                        {visibleYears.map(y => {
                          const t = yearTotals[y];
                          return (
                            <React.Fragment key={y}>
                              <td className="px-3 py-3 text-center font-mono" style={{ color: YEAR_COLORS[y] }}>
                                {fmt(t.revenue)}
                              </td>
                              <td className="px-3 py-3 text-center" style={{ color: YEAR_COLORS[y] }}>
                                {t.calls.toLocaleString()}
                              </td>
                            </React.Fragment>
                          );
                        })}
                        {visibleYears.length >= 2 && (
                          <>
                            <td className="px-3 py-3 text-center">
                              <PctBadge
                                curr={yearTotals[visibleYears[visibleYears.length - 1]]?.revenue}
                                prev={yearTotals[visibleYears[visibleYears.length - 2]]?.revenue}
                              />
                            </td>
                            <td className="px-3 py-3 text-center">
                              <PctBadge
                                curr={yearTotals[visibleYears[visibleYears.length - 1]]?.calls}
                                prev={yearTotals[visibleYears[visibleYears.length - 2]]?.calls}
                              />
                            </td>
                          </>
                        )}
                      </tr>
                    </tfoot>
                  </table>
                </div>
              </CardContent>
            </Card>

            {/* Chart */}
            <Card>
              <CardHeader className="pb-2">
                <CardTitle className="text-base">
                  {depts.length} מחלקות — {activeChart === 'revenue' ? 'הכנסה' : 'קריאות'}
                </CardTitle>
              </CardHeader>
              <CardContent className="p-0 pt-2">
                <style>{`.dept-chart svg { overflow: visible !important; }`}</style>
                <div className="dept-chart" dir="ltr">
                <ResponsiveContainer width="100%" height={Math.max(320, depts.length * 36 + 60)}>
                  <BarChart
                    data={depts.map(d => ({
                      name: d.deptName,
                      fullName: d.deptName,
                      ...Object.fromEntries(visibleYears.map(y => [
                        y,
                        activeChart === 'revenue' ? (d.byYear[y]?.revenue ?? 0) : (d.byYear[y]?.calls ?? 0)
                      ]))
                    }))}
                    layout="vertical"
                    margin={{ top: 4, right: 8, left: 8, bottom: 8 }}
                  >
                    <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" horizontal={false} />
                    <XAxis
                      type="number"
                      tick={{ fontSize: 11 }}
                      tickFormatter={v => {
                        if (!v) return '0';
                        if (activeChart === 'revenue') {
                          if (Math.abs(v) >= 1_000_000) return `${(v / 1_000_000).toFixed(1)}M`;
                          if (Math.abs(v) >= 1_000) return `${(v / 1_000).toFixed(0)}K`;
                          return String(v);
                        }
                        return String(v);
                      }}
                    />
                    <YAxis
                      type="category"
                      dataKey="name"
                      orientation="right"
                      width={220}
                      tickLine={false}
                      tick={(props: any) => {
                        const { x, y, payload } = props;
                        return (
                          <g transform={`translate(${x},${y})`} style={{ overflow: 'visible' }}>
                            <text x={6} y={0} dy={4} textAnchor="start" fontSize={11} fill="#374151" style={{ overflow: 'visible' }}>
                              {payload.value}
                            </text>
                          </g>
                        );
                      }}
                    />
                    <Tooltip
                      formatter={(val: number, name: string) => [
                        activeChart === 'revenue' ? fmt(val) : val.toLocaleString(),
                        name
                      ]}
                      labelFormatter={(l, p) => p[0]?.payload?.fullName || l}
                    />
                    <Legend verticalAlign="top" wrapperStyle={{ paddingBottom: 8 }} />
                    {visibleYears.map(y => (
                      <Bar key={y} dataKey={y} name={y} fill={YEAR_COLORS[y]} radius={[3, 0, 0, 3]}>
                        <LabelList
                          dataKey={y}
                          position="right"
                          style={{ fontSize: 10, fill: '#6b7280' }}
                          formatter={(v: number) => {
                            if (!v) return '';
                            if (activeChart === 'revenue') {
                              if (v >= 1_000_000) return `${(v / 1_000_000).toFixed(1)}M`;
                              if (v >= 1_000) return `${(v / 1_000).toFixed(0)}K`;
                              return String(v);
                            }
                            if (v >= 1_000) return `${(v / 1_000).toFixed(1)}K`;
                            return String(v);
                          }}
                        />
                      </Bar>
                    ))}
                  </BarChart>
                </ResponsiveContainer>
                </div>
              </CardContent>
            </Card>
          </>
        )}
        </React.Fragment>)}
      </div>
    </DashboardLayout>
  );
}

// ─── Financial Dept Tab ──────────────────────────────────────────────────────

interface FinDeptRow { dept_code: string; dept_name: string; agent_name: string; family_name: string; revenue: number; qty: number; line_count: number; }
interface FinDept { deptCode: string; deptName: string; revenue: number; qty: number; lineCount: number; agents: { name: string; revenue: number; qty: number; lineCount: number }[]; }

function FinancialDeptTab({ rows, dateFrom, setDateFrom, dateTo, setDateTo, onApply }: {
  rows: FinDeptRow[]; dateFrom: string; setDateFrom: (v: string) => void;
  dateTo: string; setDateTo: (v: string) => void; onApply: () => void;
}) {
  const [expandedDepts, setExpandedDepts] = useState<Set<string>>(new Set());

  const depts = useMemo<FinDept[]>(() => {
    const map = new Map<string, FinDept>();
    for (const row of rows) {
      const key = row.dept_code;
      if (!map.has(key)) map.set(key, { deptCode: row.dept_code, deptName: row.dept_name, revenue: 0, qty: 0, lineCount: 0, agents: [] });
      const d = map.get(key)!;
      const rev = Number(row.revenue) || 0; const q = Number(row.qty) || 0; const lc = Number(row.line_count) || 0;
      d.revenue += rev; d.qty += q; d.lineCount += lc;
      if (row.agent_name) {
        const a = d.agents.find(x => x.name === row.agent_name);
        if (a) { a.revenue += rev; a.qty += q; a.lineCount += lc; }
        else d.agents.push({ name: row.agent_name, revenue: rev, qty: q, lineCount: lc });
      }
    }
    const result = Array.from(map.values()).sort((a, b) => b.revenue - a.revenue);
    result.forEach(d => d.agents.sort((a, b) => b.revenue - a.revenue));
    return result;
  }, [rows]);

  const totalRevenue = depts.reduce((s, d) => s + d.revenue, 0);
  const totalLines   = depts.reduce((s, d) => s + d.lineCount, 0);
  const hasData = depts.length > 0;
  const toggleDept = (code: string) => setExpandedDepts(prev => { const n = new Set(prev); n.has(code) ? n.delete(code) : n.add(code); return n; });

  return (
    <div className="space-y-4">
      <Card>
        <CardContent className="pt-4 pb-3">
          <div className="flex flex-wrap gap-3 items-end" dir="rtl">
            <div>
              <label className="text-xs text-gray-500 block mb-1">מתאריך</label>
              <input type="date" value={dateFrom} onChange={e => setDateFrom(e.target.value)}
                className="border border-gray-200 rounded-lg px-3 py-1.5 text-sm focus:outline-none focus:border-emerald-400"
                data-testid="fin-dept-date-from" />
            </div>
            <div>
              <label className="text-xs text-gray-500 block mb-1">עד תאריך</label>
              <input type="date" value={dateTo} onChange={e => setDateTo(e.target.value)}
                className="border border-gray-200 rounded-lg px-3 py-1.5 text-sm focus:outline-none focus:border-emerald-400"
                data-testid="fin-dept-date-to" />
            </div>
            <button onClick={onApply} data-testid="fin-dept-apply"
              className="flex items-center gap-1.5 px-4 py-1.5 bg-emerald-600 text-white text-sm font-medium rounded-lg hover:bg-emerald-700 transition-colors">
              <RefreshCw size={14} /> הפעל שאילתא
            </button>
          </div>
        </CardContent>
      </Card>

      {!hasData ? (
        <Card>
          <CardContent className="py-14">
            <div className="text-center space-y-3">
              <div className="text-4xl">💰</div>
              <p className="text-base font-semibold text-amber-700">אין נתונים מסונכרנים</p>
              <p className="text-sm text-gray-500">יש לסנכרן שאילתא כספית תחילה, ולאחר מכן להפעיל שאילתא</p>
            </div>
          </CardContent>
        </Card>
      ) : (
        <>
          <div className="grid grid-cols-3 gap-4">
            <Card><CardContent className="pt-4 pb-4">
              <div className="text-xs text-gray-500 mb-1">סה"כ הכנסות</div>
              <div className="text-xl font-bold text-emerald-700">{fmt(totalRevenue)}</div>
            </CardContent></Card>
            <Card><CardContent className="pt-4 pb-4">
              <div className="text-xs text-gray-500 mb-1">מחלקות</div>
              <div className="text-xl font-bold text-gray-800">{depts.length}</div>
            </CardContent></Card>
            <Card><CardContent className="pt-4 pb-4">
              <div className="text-xs text-gray-500 mb-1">שורות חשבונית</div>
              <div className="text-xl font-bold text-gray-800">{totalLines.toLocaleString()}</div>
            </CardContent></Card>
          </div>

          <Card>
            <CardHeader className="pb-2"><CardTitle className="text-base">הכנסות לפי מחלקה (עד 15 ראשונות)</CardTitle></CardHeader>
            <CardContent className="p-0 pt-2">
              <div dir="ltr">
                <ResponsiveContainer width="100%" height={Math.max(260, Math.min(depts.length, 15) * 36 + 60)}>
                  <BarChart data={depts.slice(0, 15).map(d => ({ name: d.deptName || d.deptCode, revenue: Math.round(d.revenue) }))}
                    layout="vertical" margin={{ top: 4, right: 60, left: 8, bottom: 4 }}>
                    <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" horizontal={false} />
                    <XAxis type="number" tick={{ fontSize: 11 }} tickFormatter={v => v >= 1_000_000 ? `${(v/1_000_000).toFixed(1)}M` : v >= 1000 ? `${(v/1000).toFixed(0)}K` : String(v)} />
                    <YAxis type="category" dataKey="name" orientation="right" width={200} tick={{ fontSize: 11 }} tickLine={false} />
                    <Tooltip formatter={(v: number) => [fmt(v), 'הכנסות']} />
                    <Bar dataKey="revenue" name="הכנסות" fill="#10b981" radius={[3, 0, 0, 3]}>
                      <LabelList dataKey="revenue" position="right" style={{ fontSize: 10, fill: '#6b7280' }}
                        formatter={(v: number) => v >= 1_000_000 ? `${(v/1_000_000).toFixed(1)}M` : v >= 1000 ? `${(v/1000).toFixed(0)}K` : String(v)} />
                    </Bar>
                  </BarChart>
                </ResponsiveContainer>
              </div>
            </CardContent>
          </Card>

          <Card>
            <CardHeader className="pb-2"><CardTitle className="text-base">פירוט לפי מחלקה</CardTitle></CardHeader>
            <CardContent className="p-0">
              <div className="overflow-x-auto">
                <table className="w-full text-sm">
                  <thead>
                    <tr className="border-b bg-gray-50">
                      <th className="text-right px-4 py-2.5 font-medium text-gray-600 w-6"></th>
                      <th className="text-right px-4 py-2.5 font-medium text-gray-600">מחלקה</th>
                      <th className="text-center px-3 py-2.5 font-medium text-emerald-700">הכנסה</th>
                      <th className="text-center px-3 py-2.5 font-medium text-gray-600">כמות</th>
                      <th className="text-center px-3 py-2.5 font-medium text-gray-500">שורות</th>
                    </tr>
                  </thead>
                  <tbody>
                    {depts.map((dept, idx) => {
                      const expanded = expandedDepts.has(dept.deptCode);
                      return (
                        <React.Fragment key={dept.deptCode}>
                          <motion.tr initial={{ opacity: 0 }} animate={{ opacity: 1 }} transition={{ delay: idx * 0.02 }}
                            className={`border-b hover:bg-gray-50 cursor-pointer ${idx % 2 === 0 ? 'bg-white' : 'bg-gray-50/50'}`}
                            onClick={() => toggleDept(dept.deptCode)} data-testid={`fin-dept-row-${dept.deptCode}`}>
                            <td className="px-4 py-2.5 text-gray-400">
                              {dept.agents.length > 0 ? (expanded ? <ChevronUp size={14} /> : <ChevronDown size={14} />) : null}
                            </td>
                            <td className="px-4 py-2.5 font-medium text-gray-800" dir="rtl">{dept.deptName || dept.deptCode}</td>
                            <td className="px-3 py-2.5 text-center font-bold text-emerald-700">{fmt(dept.revenue)}</td>
                            <td className="px-3 py-2.5 text-center text-gray-600">{Math.round(dept.qty).toLocaleString()}</td>
                            <td className="px-3 py-2.5 text-center text-gray-400">{dept.lineCount.toLocaleString()}</td>
                          </motion.tr>
                          {expanded && dept.agents.map(agent => (
                            <tr key={agent.name} className="bg-emerald-50/60 border-b">
                              <td className="px-4 py-1.5"></td>
                              <td className="px-4 py-1.5 text-xs text-gray-600 pr-8" dir="rtl">└ {agent.name || '(ללא סוכן)'}</td>
                              <td className="px-3 py-1.5 text-center text-xs font-medium text-emerald-600">{fmt(agent.revenue)}</td>
                              <td className="px-3 py-1.5 text-center text-xs text-gray-500">{Math.round(agent.qty).toLocaleString()}</td>
                              <td className="px-3 py-1.5 text-center text-xs text-gray-400">{agent.lineCount.toLocaleString()}</td>
                            </tr>
                          ))}
                        </React.Fragment>
                      );
                    })}
                  </tbody>
                  <tfoot className="border-t bg-gray-50 font-semibold">
                    <tr>
                      <td></td>
                      <td className="px-4 py-2.5 text-gray-700">סה"כ</td>
                      <td className="px-3 py-2.5 text-center text-emerald-700">{fmt(totalRevenue)}</td>
                      <td className="px-3 py-2.5 text-center text-gray-600">{Math.round(depts.reduce((s,d)=>s+d.qty,0)).toLocaleString()}</td>
                      <td className="px-3 py-2.5 text-center text-gray-400">{totalLines.toLocaleString()}</td>
                    </tr>
                  </tfoot>
                </table>
              </div>
            </CardContent>
          </Card>
        </>
      )}
    </div>
  );
}

// ─── Operational Dept Tab ────────────────────────────────────────────────────

interface OpDeptRow { dept_code: string; dept_name: string; calibrator_name: string; family_name: string; total_qty: number; doc_count: number; }
interface OpDept { deptCode: string; deptName: string; totalQty: number; docCount: number; calibrators: { name: string; qty: number; docCount: number }[]; }

function OperationalDeptTab({ rows, dateFrom, setDateFrom, dateTo, setDateTo, onApply }: {
  rows: OpDeptRow[]; dateFrom: string; setDateFrom: (v: string) => void;
  dateTo: string; setDateTo: (v: string) => void; onApply: () => void;
}) {
  const [expandedDepts, setExpandedDepts] = useState<Set<string>>(new Set());

  const depts = useMemo<OpDept[]>(() => {
    const map = new Map<string, OpDept>();
    for (const row of rows) {
      const key = row.dept_code;
      if (!map.has(key)) map.set(key, { deptCode: row.dept_code, deptName: row.dept_name, totalQty: 0, docCount: 0, calibrators: [] });
      const d = map.get(key)!;
      const qty = Number(row.total_qty) || 0; const dc = Number(row.doc_count) || 0;
      d.totalQty += qty; d.docCount += dc;
      if (row.calibrator_name) {
        const c = d.calibrators.find(x => x.name === row.calibrator_name);
        if (c) { c.qty += qty; c.docCount += dc; }
        else d.calibrators.push({ name: row.calibrator_name, qty, docCount: dc });
      }
    }
    const result = Array.from(map.values()).sort((a, b) => b.totalQty - a.totalQty);
    result.forEach(d => d.calibrators.sort((a, b) => b.qty - a.qty));
    return result;
  }, [rows]);

  const totalQty   = depts.reduce((s, d) => s + d.totalQty, 0);
  const totalDocs  = depts.reduce((s, d) => s + d.docCount, 0);
  const uniqueCalibrators = new Set(rows.map(r => r.calibrator_name).filter(Boolean)).size;
  const hasData = depts.length > 0;
  const toggleDept = (code: string) => setExpandedDepts(prev => { const n = new Set(prev); n.has(code) ? n.delete(code) : n.add(code); return n; });

  return (
    <div className="space-y-4">
      <Card>
        <CardContent className="pt-4 pb-3">
          <div className="flex flex-wrap gap-3 items-end" dir="rtl">
            <div>
              <label className="text-xs text-gray-500 block mb-1">מתאריך</label>
              <input type="date" value={dateFrom} onChange={e => setDateFrom(e.target.value)}
                className="border border-gray-200 rounded-lg px-3 py-1.5 text-sm focus:outline-none focus:border-blue-400"
                data-testid="op-dept-date-from" />
            </div>
            <div>
              <label className="text-xs text-gray-500 block mb-1">עד תאריך</label>
              <input type="date" value={dateTo} onChange={e => setDateTo(e.target.value)}
                className="border border-gray-200 rounded-lg px-3 py-1.5 text-sm focus:outline-none focus:border-blue-400"
                data-testid="op-dept-date-to" />
            </div>
            <button onClick={onApply} data-testid="op-dept-apply"
              className="flex items-center gap-1.5 px-4 py-1.5 bg-blue-600 text-white text-sm font-medium rounded-lg hover:bg-blue-700 transition-colors">
              <RefreshCw size={14} /> הפעל שאילתא
            </button>
          </div>
        </CardContent>
      </Card>

      {!hasData ? (
        <Card>
          <CardContent className="py-14">
            <div className="text-center space-y-3">
              <div className="text-4xl">📦</div>
              <p className="text-base font-semibold text-blue-700">אין נתונים מסונכרנים</p>
              <p className="text-sm text-gray-500">יש לסנכרן שאילתא תפעולית תחילה, ולאחר מכן להפעיל שאילתא</p>
            </div>
          </CardContent>
        </Card>
      ) : (
        <>
          <div className="grid grid-cols-3 gap-4">
            <Card><CardContent className="pt-4 pb-4">
              <div className="text-xs text-gray-500 mb-1">סה"כ כמות</div>
              <div className="text-xl font-bold text-blue-700">{Math.round(totalQty).toLocaleString()}</div>
            </CardContent></Card>
            <Card><CardContent className="pt-4 pb-4">
              <div className="text-xs text-gray-500 mb-1">מחלקות</div>
              <div className="text-xl font-bold text-gray-800">{depts.length}</div>
            </CardContent></Card>
            <Card><CardContent className="pt-4 pb-4">
              <div className="text-xs text-gray-500 mb-1">כיילים</div>
              <div className="text-xl font-bold text-gray-800">{uniqueCalibrators}</div>
            </CardContent></Card>
          </div>

          <Card>
            <CardHeader className="pb-2"><CardTitle className="text-base">כמות קליטות לפי מחלקה (עד 15 ראשונות)</CardTitle></CardHeader>
            <CardContent className="p-0 pt-2">
              <div dir="ltr">
                <ResponsiveContainer width="100%" height={Math.max(260, Math.min(depts.length, 15) * 36 + 60)}>
                  <BarChart data={depts.slice(0, 15).map(d => ({ name: d.deptName || d.deptCode, qty: Math.round(d.totalQty) }))}
                    layout="vertical" margin={{ top: 4, right: 60, left: 8, bottom: 4 }}>
                    <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" horizontal={false} />
                    <XAxis type="number" tick={{ fontSize: 11 }} />
                    <YAxis type="category" dataKey="name" orientation="right" width={200} tick={{ fontSize: 11 }} tickLine={false} />
                    <Tooltip formatter={(v: number) => [v.toLocaleString(), 'כמות']} />
                    <Bar dataKey="qty" name="כמות" fill="#3b82f6" radius={[3, 0, 0, 3]}>
                      <LabelList dataKey="qty" position="right" style={{ fontSize: 10, fill: '#6b7280' }} />
                    </Bar>
                  </BarChart>
                </ResponsiveContainer>
              </div>
            </CardContent>
          </Card>

          <Card>
            <CardHeader className="pb-2"><CardTitle className="text-base">פירוט לפי מחלקה</CardTitle></CardHeader>
            <CardContent className="p-0">
              <div className="overflow-x-auto">
                <table className="w-full text-sm">
                  <thead>
                    <tr className="border-b bg-gray-50">
                      <th className="text-right px-4 py-2.5 font-medium text-gray-600 w-6"></th>
                      <th className="text-right px-4 py-2.5 font-medium text-gray-600">מחלקה</th>
                      <th className="text-center px-3 py-2.5 font-medium text-blue-700">כמות</th>
                      <th className="text-center px-3 py-2.5 font-medium text-gray-500">תעודות משלוח</th>
                    </tr>
                  </thead>
                  <tbody>
                    {depts.map((dept, idx) => {
                      const expanded = expandedDepts.has(dept.deptCode);
                      return (
                        <React.Fragment key={dept.deptCode}>
                          <motion.tr initial={{ opacity: 0 }} animate={{ opacity: 1 }} transition={{ delay: idx * 0.02 }}
                            className={`border-b hover:bg-gray-50 cursor-pointer ${idx % 2 === 0 ? 'bg-white' : 'bg-gray-50/50'}`}
                            onClick={() => toggleDept(dept.deptCode)} data-testid={`op-dept-row-${dept.deptCode}`}>
                            <td className="px-4 py-2.5 text-gray-400">
                              {dept.calibrators.length > 0 ? (expanded ? <ChevronUp size={14} /> : <ChevronDown size={14} />) : null}
                            </td>
                            <td className="px-4 py-2.5 font-medium text-gray-800" dir="rtl">{dept.deptName || dept.deptCode}</td>
                            <td className="px-3 py-2.5 text-center font-bold text-blue-700">{Math.round(dept.totalQty).toLocaleString()}</td>
                            <td className="px-3 py-2.5 text-center text-gray-400">{dept.docCount.toLocaleString()}</td>
                          </motion.tr>
                          {expanded && dept.calibrators.map(cal => (
                            <tr key={cal.name} className="bg-blue-50/60 border-b">
                              <td className="px-4 py-1.5"></td>
                              <td className="px-4 py-1.5 text-xs text-gray-600 pr-8" dir="rtl">└ {cal.name || '(ללא כייל)'}</td>
                              <td className="px-3 py-1.5 text-center text-xs font-medium text-blue-600">{Math.round(cal.qty).toLocaleString()}</td>
                              <td className="px-3 py-1.5 text-center text-xs text-gray-400">{cal.docCount.toLocaleString()}</td>
                            </tr>
                          ))}
                        </React.Fragment>
                      );
                    })}
                  </tbody>
                  <tfoot className="border-t bg-gray-50 font-semibold">
                    <tr>
                      <td></td>
                      <td className="px-4 py-2.5 text-gray-700">סה"כ</td>
                      <td className="px-3 py-2.5 text-center text-blue-700">{Math.round(totalQty).toLocaleString()}</td>
                      <td className="px-3 py-2.5 text-center text-gray-400">{totalDocs.toLocaleString()}</td>
                    </tr>
                  </tfoot>
                </table>
              </div>
            </CardContent>
          </Card>
        </>
      )}
    </div>
  );
}

// ─── Comparison Tab Component ───────────────────────────────────────────────

const CMP_COLORS = { A: '#6366f1', B: '#10b981' };
const ALL_MONTHS = ['01','02','03','04','05','06','07','08','09','10','11','12'];

function PeriodSelector({
  label, color, year, setYear, month, setMonth
}: {
  label: string; color: string;
  year: string; setYear: (y: string) => void;
  month: string; setMonth: (m: string) => void;
}) {
  return (
    <div className="flex-1 rounded-xl border-2 p-4" style={{ borderColor: color }}>
      <div className="text-sm font-bold mb-3" style={{ color }}>{label}</div>
      <div className="space-y-2">
        <div>
          <label className="text-xs text-gray-500 block mb-1">שנה</label>
          <select
            value={year}
            onChange={e => setYear(e.target.value)}
            data-testid={`cmp-${label}-year`}
            className="w-full border border-gray-200 rounded-lg px-3 py-1.5 text-sm focus:outline-none focus:border-indigo-400"
          >
            {['2024','2025','2026'].map(y => <option key={y} value={y}>{y}</option>)}
          </select>
        </div>
        <div>
          <label className="text-xs text-gray-500 block mb-1">חודש (אופציונלי)</label>
          <select
            value={month}
            onChange={e => setMonth(e.target.value)}
            data-testid={`cmp-${label}-month`}
            className="w-full border border-gray-200 rounded-lg px-3 py-1.5 text-sm focus:outline-none focus:border-indigo-400"
          >
            <option value="">כל השנה</option>
            {ALL_MONTHS.map(m => <option key={m} value={m}>{MONTH_NAMES[m]}</option>)}
          </select>
        </div>
      </div>
    </div>
  );
}

function StatBox({ label, valA, valB, labelA, labelB, fmt, onDrilldown }: {
  label: string; valA: number; valB: number; labelA: string; labelB: string;
  fmt?: (n: number) => string;
  onDrilldown?: () => void;
}) {
  const display = fmt ?? ((n: number) => n.toLocaleString());
  const pct = valB ? ((valA - valB) / valB) * 100 : NaN;
  const positive = pct >= 0;
  return (
    <Card
      className={onDrilldown ? 'cursor-pointer hover:shadow-md transition-shadow hover:border-indigo-200' : ''}
      onClick={onDrilldown}
    >
      <CardContent className="pt-4 pb-4">
        <div className="flex items-center justify-between mb-1">
          <p className="text-xs text-gray-500">{label}</p>
          {onDrilldown && <span className="text-[10px] text-indigo-400">לחץ לפירוט ↗</span>}
        </div>
        <div className="grid grid-cols-2 gap-3 mb-3 mt-2">
          <div>
            <div className="text-[10px] text-indigo-500 font-medium mb-0.5">{labelA}</div>
            <div className="text-lg font-bold text-gray-900">{display(valA)}</div>
          </div>
          <div>
            <div className="text-[10px] text-emerald-600 font-medium mb-0.5">{labelB}</div>
            <div className="text-lg font-bold text-gray-900">{display(valB)}</div>
          </div>
        </div>
        {!isNaN(pct) && (
          <div className={`flex items-center gap-1 text-sm font-semibold ${positive ? 'text-emerald-600' : 'text-red-500'}`}>
            {positive ? <TrendingUp size={14} /> : <TrendingDown size={14} />}
            {positive ? '+' : ''}{pct.toFixed(1)}%
            <span className="text-xs text-gray-400 font-normal">שינוי</span>
          </div>
        )}
      </CardContent>
    </Card>
  );
}

function CompareTab({
  cmpAYear, setCmpAYear, cmpAMonth, setCmpAMonth,
  cmpBYear, setCmpBYear, cmpBMonth, setCmpBMonth,
  compareData, fmt, monthlyCallStatsData,
}: {
  cmpAYear: string; setCmpAYear: (y: string) => void;
  cmpAMonth: string; setCmpAMonth: (m: string) => void;
  cmpBYear: string; setCmpBYear: (y: string) => void;
  cmpBMonth: string; setCmpBMonth: (m: string) => void;
  compareData: any;
  fmt: (n: number) => string;
  monthlyCallStatsData: { yearMonth: string; callCount: number }[] | undefined;
}) {
  const [drilldown, setDrilldown] = React.useState<{ type: 'revenue' | 'calls' } | null>(null);

  // Per-agent revenue drill-down rows
  const agentDrillRows: { agent: string; valA: number; valB: number }[] = React.useMemo(() => {
    if (drilldown?.type !== 'revenue') return [];
    const allAgents = new Set([
      ...(compareData.agentBreakdownA ?? []).map((r: any) => r.agent),
      ...(compareData.agentBreakdownB ?? []).map((r: any) => r.agent),
    ]);
    return Array.from(allAgents).map(agent => {
      const a = (compareData.agentBreakdownA ?? []).find((r: any) => r.agent === agent);
      const b = (compareData.agentBreakdownB ?? []).find((r: any) => r.agent === agent);
      return { agent, valA: a?.revenue ?? 0, valB: b?.revenue ?? 0 };
    }).sort((a, b) => b.valA - a.valA);
  }, [drilldown, compareData]);

  // Monthly call drill-down rows (from monthly_call_stats, company-wide)
  const callDrillRows: { label: string; valA: number; valB: number }[] = React.useMemo(() => {
    if (drilldown?.type !== 'calls' || !monthlyCallStatsData) return [];
    const allMonths = Array.from({ length: 12 }, (_, i) => String(i + 1).padStart(2, '0'));
    if (cmpAMonth || cmpBMonth) {
      // Single month comparison — just show the two values
      return [];
    }
    return allMonths.map(m => {
      const rowA = monthlyCallStatsData.find(r => r.yearMonth === `${cmpAYear}-${m}`);
      const rowB = monthlyCallStatsData.find(r => r.yearMonth === `${cmpBYear}-${m}`);
      return { label: MONTH_NAMES[m], valA: rowA?.callCount ?? 0, valB: rowB?.callCount ?? 0 };
    }).filter(r => r.valA > 0 || r.valB > 0);
  }, [drilldown, monthlyCallStatsData, cmpAYear, cmpBYear, cmpAMonth, cmpBMonth]);

  return (
    <div className="space-y-6">
      {/* Drill-down Dialog */}
      <Dialog open={!!drilldown} onOpenChange={o => !o && setDrilldown(null)}>
        <DialogContent className="max-w-2xl max-h-[80vh] overflow-y-auto">
          <DialogHeader>
            <DialogTitle className="text-base">
              {drilldown?.type === 'revenue' ? 'פירוט הכנסות לפי סוכן' : 'פירוט קריאות שירות לפי חודש'}
            </DialogTitle>
          </DialogHeader>

          {/* Source note */}
          <div className="text-xs text-gray-400 bg-gray-50 rounded-lg px-3 py-2 mb-3 font-mono" dir="ltr">
            {drilldown?.type === 'revenue'
              ? 'מקור: synced_customers → data→monthlyRevenue[]→revenue (Priority VATPRICE)'
              : 'מקור: monthly_call_stats ← DOCUMENTS(D) → SERNTRANS → MBA_SERNTRANSCALL → DOCUMENTS_Q(Q)'}
          </div>

          {/* Revenue drill-down: per-agent table */}
          {drilldown?.type === 'revenue' && (
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b bg-gray-50 text-right">
                  <th className="px-3 py-2 font-medium text-gray-600">סוכן</th>
                  <th className="px-3 py-2 font-medium text-indigo-600 text-center">{compareData.labelA}</th>
                  <th className="px-3 py-2 font-medium text-emerald-600 text-center">{compareData.labelB}</th>
                  <th className="px-3 py-2 font-medium text-gray-500 text-center">שינוי</th>
                </tr>
              </thead>
              <tbody>
                {agentDrillRows.map((row, i) => {
                  const pct = row.valB ? ((row.valA - row.valB) / row.valB) * 100 : NaN;
                  const pos = pct >= 0;
                  return (
                    <tr key={i} className={`border-b ${i % 2 === 0 ? 'bg-white' : 'bg-gray-50/50'}`}>
                      <td className="px-3 py-2 font-medium text-gray-800">{row.agent}</td>
                      <td className="px-3 py-2 text-center font-mono text-indigo-700">{fmt(row.valA)}</td>
                      <td className="px-3 py-2 text-center font-mono text-emerald-700">{fmt(row.valB)}</td>
                      <td className="px-3 py-2 text-center">
                        {!isNaN(pct) ? (
                          <span className={`text-xs font-semibold ${pos ? 'text-emerald-600' : 'text-red-500'}`}>
                            {pos ? '+' : ''}{pct.toFixed(1)}%
                          </span>
                        ) : '–'}
                      </td>
                    </tr>
                  );
                })}
              </tbody>
              <tfoot>
                <tr className="border-t-2 border-gray-300 bg-gray-100 font-bold">
                  <td className="px-3 py-2 text-gray-700">סה"כ</td>
                  <td className="px-3 py-2 text-center font-mono text-indigo-700">{fmt(agentDrillRows.reduce((s, r) => s + r.valA, 0))}</td>
                  <td className="px-3 py-2 text-center font-mono text-emerald-700">{fmt(agentDrillRows.reduce((s, r) => s + r.valB, 0))}</td>
                  <td />
                </tr>
              </tfoot>
            </table>
          )}

          {/* Calls drill-down: monthly breakdown or single-value summary */}
          {drilldown?.type === 'calls' && (
            <>
              {callDrillRows.length > 0 ? (
                <table className="w-full text-sm">
                  <thead>
                    <tr className="border-b bg-gray-50 text-right">
                      <th className="px-3 py-2 font-medium text-gray-600">חודש</th>
                      <th className="px-3 py-2 font-medium text-indigo-600 text-center">{compareData.labelA}</th>
                      <th className="px-3 py-2 font-medium text-emerald-600 text-center">{compareData.labelB}</th>
                      <th className="px-3 py-2 font-medium text-gray-500 text-center">שינוי</th>
                    </tr>
                  </thead>
                  <tbody>
                    {callDrillRows.map((row, i) => {
                      const pct = row.valB ? ((row.valA - row.valB) / row.valB) * 100 : NaN;
                      const pos = pct >= 0;
                      return (
                        <tr key={i} className={`border-b ${i % 2 === 0 ? 'bg-white' : 'bg-gray-50/50'}`}>
                          <td className="px-3 py-2 font-medium text-gray-800">{row.label}</td>
                          <td className="px-3 py-2 text-center font-mono text-indigo-700">{row.valA.toLocaleString()}</td>
                          <td className="px-3 py-2 text-center font-mono text-emerald-700">{row.valB.toLocaleString()}</td>
                          <td className="px-3 py-2 text-center">
                            {!isNaN(pct) ? (
                              <span className={`text-xs font-semibold ${pos ? 'text-emerald-600' : 'text-red-500'}`}>
                                {pos ? '+' : ''}{pct.toFixed(1)}%
                              </span>
                            ) : '–'}
                          </td>
                        </tr>
                      );
                    })}
                  </tbody>
                  <tfoot>
                    <tr className="border-t-2 border-gray-300 bg-gray-100 font-bold">
                      <td className="px-3 py-2 text-gray-700">סה"כ</td>
                      <td className="px-3 py-2 text-center font-mono text-indigo-700">{callDrillRows.reduce((s, r) => s + r.valA, 0).toLocaleString()}</td>
                      <td className="px-3 py-2 text-center font-mono text-emerald-700">{callDrillRows.reduce((s, r) => s + r.valB, 0).toLocaleString()}</td>
                      <td />
                    </tr>
                  </tfoot>
                </table>
              ) : (
                <div className="grid grid-cols-2 gap-4 py-2">
                  <div className="bg-indigo-50 rounded-lg p-4 text-center">
                    <div className="text-xs text-indigo-500 font-medium mb-1">{compareData.labelA}</div>
                    <div className="text-2xl font-bold text-indigo-700">{compareData.callsA.toLocaleString()}</div>
                    <div className="text-xs text-gray-400 mt-1">קריאות שירות</div>
                  </div>
                  <div className="bg-emerald-50 rounded-lg p-4 text-center">
                    <div className="text-xs text-emerald-600 font-medium mb-1">{compareData.labelB}</div>
                    <div className="text-2xl font-bold text-emerald-700">{compareData.callsB.toLocaleString()}</div>
                    <div className="text-xs text-gray-400 mt-1">קריאות שירות</div>
                  </div>
                </div>
              )}
              {!monthlyCallStatsData?.length && (
                <p className="text-xs text-amber-600 text-center py-3">
                  נתוני קריאות שירות טרם סונכרנו — הרץ: <span className="font-mono">py sync-customer-data.py --monthly-calls</span>
                </p>
              )}
            </>
          )}
        </DialogContent>
      </Dialog>

      {/* Period selectors */}
      <div className="flex gap-4 items-stretch">
        <PeriodSelector
          label="תקופה א׳" color={CMP_COLORS.A}
          year={cmpAYear} setYear={setCmpAYear}
          month={cmpAMonth} setMonth={setCmpAMonth}
        />
        <div className="flex items-center justify-center text-2xl text-gray-300 font-light px-2">מול</div>
        <PeriodSelector
          label="תקופה ב׳" color={CMP_COLORS.B}
          year={cmpBYear} setYear={setCmpBYear}
          month={cmpBMonth} setMonth={setCmpBMonth}
        />
      </div>

      {/* Summary cards */}
      <div className="grid grid-cols-2 gap-4">
        <StatBox
          label="הכנסות"
          valA={compareData.revenueA} valB={compareData.revenueB}
          labelA={compareData.labelA} labelB={compareData.labelB}
          fmt={fmt}
          onDrilldown={() => setDrilldown({ type: 'revenue' })}
        />
        <StatBox
          label="קריאות"
          valA={compareData.callsA} valB={compareData.callsB}
          labelA={compareData.labelA} labelB={compareData.labelB}
          onDrilldown={() => setDrilldown({ type: 'calls' })}
        />
      </div>

      {/* Chart — only for year vs year */}
      {compareData.mode === 'year' && compareData.chart.length > 0 && (
        <>
          <Card>
            <CardHeader className="pb-2">
              <CardTitle className="text-base">הכנסות לפי חודש — {compareData.labelA} מול {compareData.labelB}</CardTitle>
            </CardHeader>
            <CardContent>
              <div dir="ltr">
                <ResponsiveContainer width="100%" height={280}>
                  <BarChart data={compareData.chart} margin={{ top: 4, right: 8, left: 8, bottom: 4 }}>
                    <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
                    <XAxis dataKey="month" tick={{ fontSize: 10 }} />
                    <YAxis tick={{ fontSize: 10 }} tickFormatter={v => v >= 1_000_000 ? `${(v/1_000_000).toFixed(1)}M` : v >= 1000 ? `${(v/1000).toFixed(0)}K` : String(v)} />
                    <Tooltip formatter={(val: number, name: string) => [fmt(val), name]} />
                    <Legend />
                    <Bar dataKey={`הכנסה ${cmpAYear}`} fill={CMP_COLORS.A} radius={[3,3,0,0]} />
                    <Bar dataKey={`הכנסה ${cmpBYear}`} fill={CMP_COLORS.B} radius={[3,3,0,0]} />
                  </BarChart>
                </ResponsiveContainer>
              </div>
            </CardContent>
          </Card>

          <Card>
            <CardHeader className="pb-2">
              <CardTitle className="text-base">קריאות לפי חודש — {compareData.labelA} מול {compareData.labelB}</CardTitle>
            </CardHeader>
            <CardContent>
              <div dir="ltr">
                <ResponsiveContainer width="100%" height={240}>
                  <LineChart data={compareData.chart} margin={{ top: 4, right: 8, left: 8, bottom: 4 }}>
                    <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
                    <XAxis dataKey="month" tick={{ fontSize: 10 }} />
                    <YAxis tick={{ fontSize: 10 }} />
                    <Tooltip />
                    <Legend />
                    <Line type="monotone" dataKey={`קריאות ${cmpAYear}`} stroke={CMP_COLORS.A} strokeWidth={2} dot={{ r: 3 }} />
                    <Line type="monotone" dataKey={`קריאות ${cmpBYear}`} stroke={CMP_COLORS.B} strokeWidth={2} dot={{ r: 3 }} />
                  </LineChart>
                </ResponsiveContainer>
              </div>
            </CardContent>
          </Card>

          {/* Monthly table */}
          <Card>
            <CardHeader className="pb-2">
              <CardTitle className="text-base">פירוט חודשי</CardTitle>
            </CardHeader>
            <CardContent className="p-0">
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b bg-gray-50">
                    <th className="text-right px-4 py-2.5 font-medium text-gray-600">חודש</th>
                    <th className="text-center px-3 py-2.5 font-medium text-indigo-600">הכנסה {cmpAYear}</th>
                    <th className="text-center px-3 py-2.5 font-medium text-emerald-600">הכנסה {cmpBYear}</th>
                    <th className="text-center px-3 py-2.5 font-medium text-gray-500">% שינוי</th>
                    <th className="text-center px-3 py-2.5 font-medium text-indigo-600">קריאות {cmpAYear}</th>
                    <th className="text-center px-3 py-2.5 font-medium text-emerald-600">קריאות {cmpBYear}</th>
                  </tr>
                </thead>
                <tbody>
                  {compareData.chart.map((row: any, i: number) => {
                    const rA = row[`הכנסה ${cmpAYear}`];
                    const rB = row[`הכנסה ${cmpBYear}`];
                    const pct = rB ? ((rA - rB) / rB) * 100 : NaN;
                    const pos = pct >= 0;
                    return (
                      <tr key={i} className={`border-b ${i % 2 === 0 ? 'bg-white' : 'bg-gray-50/50'}`}>
                        <td className="px-4 py-2 font-medium">{row.month}</td>
                        <td className="px-3 py-2 text-center font-mono text-indigo-700">{fmt(rA)}</td>
                        <td className="px-3 py-2 text-center font-mono text-emerald-700">{fmt(rB)}</td>
                        <td className="px-3 py-2 text-center">
                          {!isNaN(pct) ? (
                            <span className={`text-xs font-semibold ${pos ? 'text-emerald-600' : 'text-red-500'}`}>
                              {pos ? '+' : ''}{pct.toFixed(1)}%
                            </span>
                          ) : '–'}
                        </td>
                        <td className="px-3 py-2 text-center text-indigo-700">{row[`קריאות ${cmpAYear}`].toLocaleString()}</td>
                        <td className="px-3 py-2 text-center text-emerald-700">{row[`קריאות ${cmpBYear}`].toLocaleString()}</td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </CardContent>
          </Card>
        </>
      )}

      {/* Single value comparison (month vs month or mixed) */}
      {(compareData.mode === 'month' || compareData.mode === 'single') && (
        <Card>
          <CardContent className="pt-6 pb-6">
            <div dir="ltr">
              <ResponsiveContainer width="100%" height={220}>
                <BarChart
                  data={[
                    { name: 'הכנסות', [compareData.labelA]: compareData.revenueA, [compareData.labelB]: compareData.revenueB },
                  ]}
                  margin={{ top: 4, right: 16, left: 16, bottom: 4 }}
                >
                  <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
                  <XAxis dataKey="name" tick={{ fontSize: 12 }} />
                  <YAxis tick={{ fontSize: 10 }} tickFormatter={v => v >= 1_000_000 ? `${(v/1_000_000).toFixed(1)}M` : v >= 1000 ? `${(v/1000).toFixed(0)}K` : String(v)} />
                  <Tooltip formatter={(val: number, name: string) => [fmt(val), name]} />
                  <Legend />
                  <Bar dataKey={compareData.labelA} fill={CMP_COLORS.A} radius={[4,4,0,0]} />
                  <Bar dataKey={compareData.labelB} fill={CMP_COLORS.B} radius={[4,4,0,0]} />
                </BarChart>
              </ResponsiveContainer>
            </div>
          </CardContent>
        </Card>
      )}
    </div>
  );
}
