import { useQuery, useQueryClient } from "@tanstack/react-query";
import { useState, useMemo } from "react";
import DashboardLayout from "@/components/layout/DashboardLayout";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { Badge } from "@/components/ui/badge";
import { ScrollArea } from "@/components/ui/scroll-area";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Button } from "@/components/ui/button";
import { Loader2, Truck, DollarSign, TrendingUp, Calendar, BarChart2, RefreshCw, Clock, CloudDownload } from "lucide-react";
import {
  BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, Legend,
  AreaChart, Area
} from "recharts";

const MONTH_NAMES = [
  'ינואר', 'פברואר', 'מרץ', 'אפריל', 'מאי', 'יוני',
  'יולי', 'אוגוסט', 'ספטמבר', 'אוקטובר', 'נובמבר', 'דצמבר'
];

interface MonthlyTotal {
  month: number;
  total: number;
  count: number;
  shipping: number;
  supplier: number;
  shippingCount: number;
}

interface UpsExpense {
  id: string;
  iv: string;
  ivnum: string;
  doc: string;
  ivdate: string;
  cust: string;
  customerName: string;
  currency: string;
  amount: number;
  vatPrice: number;
  source: string;
  part: string;
}

interface ExpensesData {
  year: number;
  total: number;
  count: number;
  monthly: MonthlyTotal[];
  expenses: UpsExpense[];
}


interface DailyEntry {
  date: string;       // DD/MM/YYYY
  isoDate: string;    // YYYY-MM-DD
  count: number;
  supplier: number;
  shipping: number;
  net: number;
}

interface DailyData {
  year: number;
  month: number | null;
  totalDays: number;
  totalRecords: number;
  totalSupplier: number;
  totalShipping: number;
  totalNet: number;
  avgDailyCost: number;
  maxDay: DailyEntry | null;
  daily: DailyEntry[];
}


export default function ExpensesPage() {
  const [selectedYear, setSelectedYear] = useState<number>(new Date().getFullYear());
  const [activeTab, setActiveTab] = useState("daily");
  const [dailyMonth, setDailyMonth] = useState<number>(0);
  const [isSyncingShip, setIsSyncingShip] = useState(false);
  const [shipSyncResult, setShipSyncResult] = useState<{ success: boolean; message: string } | null>(null);
  const queryClient = useQueryClient();

  const { data, isLoading, isFetching: isFetchingUps } = useQuery<ExpensesData>({
    queryKey: ['/api/expenses/ups', selectedYear],
    queryFn: async () => {
      const response = await fetch(`/api/expenses/ups?year=${selectedYear}`);
      if (!response.ok) throw new Error('Failed to fetch');
      return response.json();
    }
  });

  const monthParam = dailyMonth > 0 ? `&month=${dailyMonth}` : '';
  const { data: dailyData, isLoading: dailyLoading, isFetching: isFetchingDaily } = useQuery<DailyData>({
    queryKey: ['/api/expenses/ups/daily', selectedYear, dailyMonth],
    queryFn: async () => {
      const response = await fetch(`/api/expenses/ups/daily?year=${selectedYear}${monthParam}`);
      if (!response.ok) throw new Error('Failed to fetch daily');
      return response.json();
    }
  });

  const { data: shipData, isFetching: isFetchingShipments } = useQuery<{ totalShipments: number; totalCost: number; monthly: { month: number; count: number; totalCost: number }[] }>({
    queryKey: ['/api/shipments', selectedYear],
    queryFn: async () => {
      const response = await fetch(`/api/shipments?year=${selectedYear}`);
      if (!response.ok) throw new Error('Failed to fetch shipments');
      return response.json();
    }
  });

  const { data: lastSyncData } = useQuery<{ lastSync: string | null }>({
    queryKey: ['/api/expenses/ups/last-sync'],
    queryFn: async () => {
      const response = await fetch('/api/expenses/ups/last-sync');
      if (!response.ok) throw new Error('Failed to fetch last sync');
      return response.json();
    }
  });

  const isRefreshing = isFetchingUps || isFetchingDaily || isFetchingShipments;

  const handleRefresh = () => {
    queryClient.invalidateQueries({ queryKey: ['/api/expenses/ups', selectedYear] });
    queryClient.invalidateQueries({ queryKey: ['/api/expenses/ups/daily', selectedYear, dailyMonth] });
    queryClient.invalidateQueries({ queryKey: ['/api/shipments', selectedYear] });
    queryClient.invalidateQueries({ queryKey: ['/api/expenses/ups/last-sync'] });
  };

  const handleShipSync = async () => {
    setIsSyncingShip(true);
    setShipSyncResult(null);
    try {
      const fromDate = `${selectedYear}-01-01`;
      const toDate = selectedYear === new Date().getFullYear()
        ? new Date().toISOString().slice(0, 10)
        : `${selectedYear}-12-31`;
      const resp = await fetch('/api/ship/sync-live', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ fromDate, toDate })
      });
      const result = await resp.json();
      if (result.success) {
        setShipSyncResult({ success: true, message: `נשמרו ${result.saved} משלוחים (${result.endpoint?.split('?')[0] ?? ''})` });
        handleRefresh();
      } else {
        const tried = result.tried as { endpoint: string; status: number; preview?: string }[] | undefined;
        const detail = tried
          ? tried.map(t => `${t.status} ${t.endpoint.split('?')[0]}: ${t.preview ?? ''}`).join(' | ')
          : '';
        console.log('[ship-sync] tried:', tried);
        setShipSyncResult({ success: false, message: result.error || 'שגיאה בסנכרון' });
      }
    } catch (e: any) {
      setShipSyncResult({ success: false, message: e.message || 'שגיאת רשת' });
    } finally {
      setIsSyncingShip(false);
    }
  };

  const formatLastSync = (ts: string | null | undefined) => {
    if (!ts) return 'לא סונכרן עדיין';
    const d = new Date(ts);
    return d.toLocaleDateString('he-IL', { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric', hour: '2-digit', minute: '2-digit' });
  };


  const chartData = useMemo(() => {
    if (!data?.monthly) return [];
    return data.monthly.map(m => {
      const supplierCost = Math.max(0, m.supplier);
      const customerRevenue = Math.max(0, m.shipping);
      const loss = supplierCost - customerRevenue;
      return {
        month: MONTH_NAMES[m.month - 1],
        monthNum: m.month,
        total: m.total,
        customerPaid: customerRevenue,
        supplier: supplierCost,
        loss: loss > 0 ? loss : 0,
        count: m.count
      };
    });
  }, [data]);

  const dailyChartData = useMemo(() => {
    if (!dailyData?.daily) return [];
    return dailyData.daily.map(d => {
      // d.date is DD/MM/YYYY
      const [dd, mm] = d.date.split('/');
      const label = dailyMonth > 0 ? dd : `${dd}/${mm}`;
      return {
        label,
        isoDate: d.isoDate,
        date: d.date,
        supplier: Math.round(d.supplier),
        shipping: Math.round(d.shipping),
        net: Math.round(d.net),
        count: d.count
      };
    });
  }, [dailyData, dailyMonth]);

  const supplierTotal = data?.monthly?.reduce((s, m) => s + m.supplier, 0) || 0;
  const customerRevenueTotal = data?.monthly?.reduce((s, m) => s + m.shipping, 0) || 0;
  const profitLoss = customerRevenueTotal - supplierTotal;

  // Ship.co.il cost per package (actual cost from ship.co.il data)
  const shipTotalShipments = shipData?.totalShipments || 0;
  const shipTotalCost = shipData?.totalCost || 0;
  const costPerPackage = shipTotalShipments > 0 ? shipTotalCost / shipTotalShipments : 0;
  const hasShipData = shipTotalShipments > 0;
  const maxMonth = data?.monthly?.reduce((max, m) => m.supplier > (max.supplier || 0) ? m : max, { month: 0, supplier: 0, total: 0 });

  if (isLoading) {
    return (
      <DashboardLayout>
        <div className="flex items-center justify-center h-64">
          <Loader2 className="w-8 h-8 animate-spin text-primary" />
        </div>
      </DashboardLayout>
    );
  }

  return (
    <DashboardLayout>
      <div className="p-6 space-y-6" dir="rtl">
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-3xl font-bold tracking-tight">לוגיסטיקה</h1>
            <p className="text-muted-foreground">מעקב הוצאות ספק UPS ומשלוחים</p>
          </div>
          <Select value={selectedYear.toString()} onValueChange={(v) => setSelectedYear(parseInt(v))}>
            <SelectTrigger className="w-32" data-testid="select-year">
              <SelectValue placeholder="שנה" />
            </SelectTrigger>
            <SelectContent>
              {[2024, 2025, 2026].map(year => (
                <SelectItem key={year} value={year.toString()} data-testid={`select-year-${year}`}>{year}</SelectItem>
              ))}
            </SelectContent>
          </Select>
        </div>

        <Tabs defaultValue="ups" className="w-full">
          <TabsList className="mb-4">
            <TabsTrigger value="ups" className="flex items-center gap-2">
              <Truck className="w-4 h-4" />
              הוצאות UPS
            </TabsTrigger>
          </TabsList>
          <TabsContent value="ups" className="space-y-6">

        {/* Last sync + refresh row */}
        <div className="flex items-center gap-3 text-sm flex-wrap" data-testid="row-last-sync">
          <div className="flex items-center gap-1.5 text-muted-foreground">
            <Clock className="w-4 h-4" />
            <span>
              עודכן לאחרונה: <span className="font-medium text-foreground">{formatLastSync(lastSyncData?.lastSync)}</span>
            </span>
          </div>
          {shipSyncResult && (
            <span className={`text-xs font-medium px-2 py-0.5 rounded-full ${shipSyncResult.success ? 'bg-emerald-100 text-emerald-700' : 'bg-red-100 text-red-700'}`}>
              {shipSyncResult.message}
            </span>
          )}
          <div className="flex-1" />
          <Button
            variant="outline"
            size="sm"
            onClick={handleShipSync}
            disabled={isSyncingShip || isRefreshing}
            data-testid="button-ship-sync"
          >
            {isSyncingShip ? (
              <Loader2 className="w-4 h-4 ml-1.5 animate-spin" />
            ) : (
              <CloudDownload className="w-4 h-4 ml-1.5" />
            )}
            שלוף מ-Ship API
          </Button>
          <Button
            variant="outline"
            size="sm"
            onClick={handleRefresh}
            disabled={isRefreshing}
            data-testid="button-refresh"
          >
            {isRefreshing ? (
              <Loader2 className="w-4 h-4 ml-1.5 animate-spin" />
            ) : (
              <RefreshCw className="w-4 h-4 ml-1.5" />
            )}
            רענן
          </Button>
        </div>

        <Tabs value={activeTab} onValueChange={setActiveTab} className="w-full">
          <TabsList className="grid w-full grid-cols-2 max-w-sm" data-testid="tabs-expenses">
            <TabsTrigger value="ups" data-testid="tab-ups">
              <DollarSign className="w-4 h-4 ml-2" />
              הוצאות Priority
            </TabsTrigger>
            <TabsTrigger value="daily" data-testid="tab-daily">
              <BarChart2 className="w-4 h-4 ml-2" />
              הוצאות יומיות
            </TabsTrigger>
          </TabsList>

          {/* ───── Priority tab ───── */}
          <TabsContent value="ups" className="space-y-6 mt-6">
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-5 gap-4">
              <Card className="bg-gradient-to-br from-blue-50 to-blue-100/50 border-blue-200" data-testid="card-total-expenses">
                <CardContent className="pt-6">
                  <div className="flex items-center justify-between">
                    <div className="text-right">
                      <p className="text-sm font-medium text-muted-foreground">שילמתי ל-UPS</p>
                      <h3 className="text-2xl font-bold text-blue-600">
                        ₪{supplierTotal.toLocaleString(undefined, { maximumFractionDigits: 0 })}
                      </h3>
                      <p className="text-xs text-muted-foreground">הוצאות ספק</p>
                    </div>
                    <DollarSign className="w-10 h-10 text-blue-500/50" />
                  </div>
                </CardContent>
              </Card>

              <Card className="bg-gradient-to-br from-green-50 to-green-100/50 border-green-200" data-testid="card-customer-revenue">
                <CardContent className="pt-6">
                  <div className="flex items-center justify-between">
                    <div className="text-right">
                      <p className="text-sm font-medium text-muted-foreground">קיבלתי מלקוחות</p>
                      <h3 className="text-2xl font-bold text-green-600">
                        ₪{customerRevenueTotal.toLocaleString(undefined, { maximumFractionDigits: 0 })}
                      </h3>
                      <p className="text-xs text-muted-foreground">הכנסות משילוח</p>
                    </div>
                    <TrendingUp className="w-10 h-10 text-green-500/50" />
                  </div>
                </CardContent>
              </Card>

              <Card className={`bg-gradient-to-br ${profitLoss >= 0 ? 'from-emerald-50 to-emerald-100/50 border-emerald-200' : 'from-red-50 to-red-100/50 border-red-200'}`} data-testid="card-profit-loss">
                <CardContent className="pt-6">
                  <div className="flex items-center justify-between">
                    <div className="text-right">
                      <p className="text-sm font-medium text-muted-foreground">{profitLoss >= 0 ? 'רווח' : 'הפסד'}</p>
                      <h3 className={`text-2xl font-bold ${profitLoss >= 0 ? 'text-emerald-600' : 'text-red-600'}`}>
                        {profitLoss >= 0 ? '+' : ''}₪{profitLoss.toLocaleString(undefined, { maximumFractionDigits: 0 })}
                      </h3>
                      <p className="text-xs text-muted-foreground">הכנסות - הוצאות</p>
                    </div>
                    <Calendar className={`w-10 h-10 ${profitLoss >= 0 ? 'text-emerald-500/50' : 'text-red-500/50'}`} />
                  </div>
                </CardContent>
              </Card>

              <Card className="bg-gradient-to-br from-orange-50 to-orange-100/50 border-orange-200" data-testid="card-max-month">
                <CardContent className="pt-6">
                  <div className="flex items-center justify-between">
                    <div className="text-right">
                      <p className="text-sm font-medium text-muted-foreground">חודש שיא הוצאות</p>
                      <h3 className="text-2xl font-bold text-orange-600">
                        {maxMonth?.month ? MONTH_NAMES[maxMonth.month - 1] : '-'}
                      </h3>
                      <p className="text-xs text-muted-foreground">
                        ₪{(maxMonth?.supplier || 0).toLocaleString(undefined, { maximumFractionDigits: 0 })}
                      </p>
                    </div>
                    <Calendar className="w-10 h-10 text-orange-500/50" />
                  </div>
                </CardContent>
              </Card>

              <Card className="bg-gradient-to-br from-violet-50 to-violet-100/50 border-violet-200" data-testid="card-cost-per-package">
                <CardContent className="pt-6">
                  <div className="flex items-center justify-between">
                    <div className="text-right">
                      <p className="text-sm font-medium text-muted-foreground">עלות פר חבילה</p>
                      {hasShipData ? (
                        <>
                          <h3 className="text-2xl font-bold text-violet-600">
                            ₪{costPerPackage.toLocaleString(undefined, { maximumFractionDigits: 1 })}
                          </h3>
                          <p className="text-xs text-muted-foreground">
                            {shipTotalShipments.toLocaleString()} חבילות · ship.co.il
                          </p>
                        </>
                      ) : (
                        <>
                          <h3 className="text-lg font-semibold text-violet-400 mt-1">אין נתוני Ship</h3>
                          <p className="text-xs text-muted-foreground">יש להריץ סנכרון Ship</p>
                        </>
                      )}
                    </div>
                    <Truck className="w-10 h-10 text-violet-500/50" />
                  </div>
                </CardContent>
              </Card>
            </div>

            <Card data-testid="card-monthly-chart">
              <CardHeader>
                <CardTitle>השוואת הוצאות מול הכנסות</CardTitle>
                <CardDescription>כמה שילמתי ל-UPS לעומת כמה הלקוחות שילמו לי</CardDescription>
              </CardHeader>
              <CardContent>
                <div className="h-[350px]" dir="ltr">
                  <ResponsiveContainer width="100%" height="100%">
                    <BarChart data={chartData} margin={{ top: 20, right: 30, left: 20, bottom: 5 }} barCategoryGap="15%">
                      <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="hsl(var(--border))" />
                      <XAxis dataKey="month" tick={{ fontSize: 11, fill: 'hsl(var(--muted-foreground))' }} tickLine={false} axisLine={false} />
                      <YAxis tick={{ fontSize: 11, fill: 'hsl(var(--muted-foreground))' }} tickFormatter={(v) => `₪${(v/1000).toFixed(0)}K`} tickLine={false} axisLine={false} />
                      <Tooltip
                        formatter={(value: number, name: string) => [`₪${value.toLocaleString()}`, name]}
                        labelFormatter={(label) => label}
                        contentStyle={{ borderRadius: '8px', border: 'none', boxShadow: '0 4px 12px rgba(0,0,0,0.1)', textAlign: 'right', direction: 'rtl' }}
                      />
                      <Legend verticalAlign="top" height={36} wrapperStyle={{ direction: 'rtl' }} />
                      <Bar dataKey="supplier" name="הוצאות UPS (שילמתי)" fill="#3b82f6" radius={[6, 6, 0, 0]} maxBarSize={35} />
                      <Bar dataKey="customerPaid" name="הכנסות מלקוחות (קיבלתי)" fill="#22c55e" radius={[6, 6, 0, 0]} maxBarSize={35} />
                      <Bar dataKey="loss" name="הפסד (כחול - ירוק)" fill="#ef4444" radius={[6, 6, 0, 0]} maxBarSize={35} />
                    </BarChart>
                  </ResponsiveContainer>
                </div>
              </CardContent>
            </Card>

            <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
              <Card className="shadow-lg border-0 bg-gradient-to-br from-white to-slate-50">
                <CardHeader className="border-b bg-gradient-to-r from-blue-50 to-indigo-50">
                  <CardTitle className="text-blue-900 flex items-center gap-2">
                    <Calendar className="w-5 h-5" />
                    פירוט חודשי
                  </CardTitle>
                  <CardDescription>סיכום הוצאות והפסד לכל חודש</CardDescription>
                </CardHeader>
                <CardContent className="pt-4">
                  <ScrollArea className="h-[420px]">
                    <div className="space-y-3 pl-2">
                      {data?.monthly?.filter(m => m.supplier > 0).map((m) => {
                        const loss = m.supplier - m.shipping;
                        const shipMonth = shipData?.monthly?.find(sm => sm.month === m.month);
                        const shipCount = shipMonth?.count || 0;
                        const shipCost = shipMonth?.totalCost || 0;
                        const monthCostPerPackage = shipCount > 0 ? shipCost / shipCount : 0;
                        return (
                          <div key={m.month} className="flex items-center justify-between p-4 rounded-xl border-2 border-slate-100 bg-white hover:border-blue-200 hover:shadow-md transition-all duration-200" data-testid={`month-row-${m.month}`}>
                            <div className="flex items-center gap-4">
                              <div className="w-12 h-12 rounded-full bg-gradient-to-br from-blue-500 to-blue-600 flex items-center justify-center text-lg font-bold text-white shadow-md">
                                {m.month}
                              </div>
                              <div>
                                <p className="font-semibold text-lg text-slate-800">{MONTH_NAMES[m.month - 1]}</p>
                                <p className="text-sm text-muted-foreground">
                                  {shipCount > 0 ? `${shipCount} חבילות` : `${m.shippingCount || 0} רשומות`}
                                </p>
                              </div>
                            </div>
                            <div className="text-right space-y-1">
                              <div className="flex items-center gap-2 justify-end">
                                <p className="font-bold text-blue-600">₪{m.supplier.toLocaleString(undefined, { maximumFractionDigits: 0 })}</p>
                                <span className="text-xs text-blue-600 bg-blue-50 px-2 py-0.5 rounded">שילמתי</span>
                              </div>
                              <div className="flex items-center gap-2 justify-end">
                                <p className="font-bold text-green-600">₪{m.shipping.toLocaleString(undefined, { maximumFractionDigits: 0 })}</p>
                                <span className="text-xs text-green-600 bg-green-50 px-2 py-0.5 rounded">קיבלתי</span>
                              </div>
                              {monthCostPerPackage > 0 && (
                                <div className="flex items-center gap-2 justify-end">
                                  <p className="font-bold text-violet-600">₪{monthCostPerPackage.toLocaleString(undefined, { maximumFractionDigits: 1 })}</p>
                                  <span className="text-xs text-violet-600 bg-violet-50 px-2 py-0.5 rounded">לחבילה</span>
                                </div>
                              )}
                              {loss > 0 && (
                                <div className="flex items-center gap-2 justify-end">
                                  <p className="font-bold text-red-600">₪{loss.toLocaleString(undefined, { maximumFractionDigits: 0 })}</p>
                                  <span className="text-xs text-red-600 bg-red-50 px-2 py-0.5 rounded">הפסד</span>
                                </div>
                              )}
                            </div>
                          </div>
                        );
                      })}
                      {(!data?.monthly || data.monthly.every(m => m.supplier === 0)) && (
                        <div className="text-center py-12 text-muted-foreground">
                          <Truck className="w-16 h-16 mx-auto mb-3 opacity-30" />
                          <p className="text-lg">אין נתוני הוצאות לשנה זו</p>
                          <p className="text-sm">יש להריץ את סקריפט הסנכרון לייבוא הנתונים</p>
                        </div>
                      )}
                    </div>
                  </ScrollArea>
                </CardContent>
              </Card>

              <Card className="shadow-lg border-0 bg-gradient-to-br from-white to-slate-50">
                <CardHeader className="border-b bg-gradient-to-r from-green-50 to-emerald-50">
                  <CardTitle className="text-green-900 flex items-center gap-2">
                    <TrendingUp className="w-5 h-5" />
                    הכנסות משילוח לפי לקוח
                  </CardTitle>
                  <CardDescription>סכום חשבוניות משלוח לכל לקוח ב-{selectedYear}</CardDescription>
                </CardHeader>
                <CardContent className="pt-4">
                  <ScrollArea className="h-[420px]">
                    <div className="space-y-2 pl-2">
                      {data?.customerShipping?.map((c: any, idx: number) => (
                        <div key={c.customerId || idx} className="flex items-center justify-between p-3 rounded-lg border border-slate-100 bg-white hover:border-green-200 hover:shadow-sm transition-all duration-200" data-testid={`customer-shipping-row-${idx}`}>
                          <div className="flex items-center gap-3">
                            <div className="w-10 h-10 rounded-full bg-gradient-to-br from-green-400 to-green-500 flex items-center justify-center text-sm font-bold text-white shadow-sm">
                              {idx + 1}
                            </div>
                            <div>
                              <p className="font-semibold text-slate-800">{c.customerName}</p>
                              <p className="text-xs text-muted-foreground">{c.count} חשבוניות</p>
                            </div>
                          </div>
                          <div className="text-right">
                            <p className="font-bold text-xl text-green-600">₪{c.total.toLocaleString(undefined, { maximumFractionDigits: 0 })}</p>
                          </div>
                        </div>
                      ))}
                      {(!data?.customerShipping || data.customerShipping.length === 0) && (
                        <div className="text-center py-12 text-muted-foreground">
                          <TrendingUp className="w-16 h-16 mx-auto mb-3 opacity-30" />
                          <p className="text-lg">אין נתוני הכנסות משילוח</p>
                        </div>
                      )}
                    </div>
                  </ScrollArea>
                </CardContent>
              </Card>
            </div>
          </TabsContent>

          {/* ───── Daily expenses tab ───── */}
          <TabsContent value="daily" className="space-y-6 mt-6">
            {/* Controls row */}
            <div className="flex flex-wrap items-center gap-3">
              <Select value={dailyMonth.toString()} onValueChange={(v) => setDailyMonth(parseInt(v))}>
                <SelectTrigger className="w-36" data-testid="select-daily-month">
                  <SelectValue placeholder="כל השנה" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="0">כל השנה</SelectItem>
                  {MONTH_NAMES.map((name, i) => (
                    <SelectItem key={i + 1} value={(i + 1).toString()}>{name}</SelectItem>
                  ))}
                </SelectContent>
              </Select>
              <span className="text-sm text-muted-foreground">
                {dailyMonth > 0 ? `${MONTH_NAMES[dailyMonth - 1]} ${selectedYear}` : `כל ${selectedYear}`}
                {dailyData && ` — ${dailyData.totalDays} ימים פעילים`}
              </span>
            </div>

            {/* KPI cards */}
            {dailyLoading ? (
              <div className="flex items-center justify-center h-40">
                <Loader2 className="w-8 h-8 animate-spin text-primary" />
              </div>
            ) : (
              <>
                <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
                  <Card className="bg-gradient-to-br from-blue-50 to-blue-100/50 border-blue-200" data-testid="card-daily-supplier">
                    <CardContent className="pt-6">
                      <div className="text-right">
                        <p className="text-sm font-medium text-muted-foreground">שילמתי ל-UPS</p>
                        <h3 className="text-2xl font-bold text-blue-700">
                          ₪{(dailyData?.totalSupplier || 0).toLocaleString(undefined, { maximumFractionDigits: 0 })}
                        </h3>
                        <p className="text-xs text-muted-foreground">סה״כ הוצאות ספק</p>
                      </div>
                    </CardContent>
                  </Card>

                  <Card className="bg-gradient-to-br from-green-50 to-green-100/50 border-green-200" data-testid="card-daily-shipping">
                    <CardContent className="pt-6">
                      <div className="text-right">
                        <p className="text-sm font-medium text-muted-foreground">קיבלתי מלקוחות</p>
                        <h3 className="text-2xl font-bold text-green-700">
                          ₪{(dailyData?.totalShipping || 0).toLocaleString(undefined, { maximumFractionDigits: 0 })}
                        </h3>
                        <p className="text-xs text-muted-foreground">סה״כ הכנסות שילוח</p>
                      </div>
                    </CardContent>
                  </Card>

                  <Card className="bg-gradient-to-br from-sky-50 to-sky-100/50 border-sky-200" data-testid="card-daily-avg">
                    <CardContent className="pt-6">
                      <div className="text-right">
                        <p className="text-sm font-medium text-muted-foreground">ממוצע יומי לUPS</p>
                        <h3 className="text-2xl font-bold text-sky-700">
                          ₪{(dailyData?.avgDailyCost || 0).toLocaleString(undefined, { maximumFractionDigits: 0 })}
                        </h3>
                        <p className="text-xs text-muted-foreground">לכל יום פעיל</p>
                      </div>
                    </CardContent>
                  </Card>

                  <Card className="bg-gradient-to-br from-rose-50 to-rose-100/50 border-rose-200" data-testid="card-daily-max">
                    <CardContent className="pt-6">
                      <div className="text-right">
                        <p className="text-sm font-medium text-muted-foreground">יום שיא הוצאות</p>
                        <h3 className="text-2xl font-bold text-rose-700">
                          ₪{(dailyData?.maxDay?.supplier || 0).toLocaleString(undefined, { maximumFractionDigits: 0 })}
                        </h3>
                        <p className="text-xs text-muted-foreground font-medium">
                          {dailyData?.maxDay?.date || '-'}
                        </p>
                      </div>
                    </CardContent>
                  </Card>
                </div>

                {/* Daily bar chart — supplier vs shipping */}
                {dailyChartData.length > 0 ? (
                  <Card data-testid="card-daily-chart">
                    <CardHeader>
                      <CardTitle>הוצאות יומיות — {dailyMonth > 0 ? MONTH_NAMES[dailyMonth - 1] : 'כל השנה'} {selectedYear}</CardTitle>
                      <CardDescription>השוואה יומית: מה שילמתי ל-UPS מול מה שגביתי מלקוחות</CardDescription>
                    </CardHeader>
                    <CardContent>
                      <div className="h-[340px]" dir="ltr">
                        <ResponsiveContainer width="100%" height="100%">
                          <AreaChart data={dailyChartData} margin={{ top: 10, right: 30, left: 20, bottom: 5 }}>
                            <defs>
                              <linearGradient id="supplierGrad" x1="0" y1="0" x2="0" y2="1">
                                <stop offset="5%"  stopColor="#3b82f6" stopOpacity={0.25} />
                                <stop offset="95%" stopColor="#3b82f6" stopOpacity={0.02} />
                              </linearGradient>
                              <linearGradient id="shippingGrad" x1="0" y1="0" x2="0" y2="1">
                                <stop offset="5%"  stopColor="#22c55e" stopOpacity={0.25} />
                                <stop offset="95%" stopColor="#22c55e" stopOpacity={0.02} />
                              </linearGradient>
                            </defs>
                            <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="hsl(var(--border))" />
                            <XAxis
                              dataKey="label"
                              tick={{ fontSize: 10, fill: 'hsl(var(--muted-foreground))' }}
                              tickLine={false}
                              axisLine={false}
                              interval={dailyChartData.length > 60 ? 6 : dailyChartData.length > 30 ? 2 : 0}
                            />
                            <YAxis
                              tick={{ fontSize: 11, fill: 'hsl(var(--muted-foreground))' }}
                              tickFormatter={(v) => v >= 1000 ? `₪${(v/1000).toFixed(0)}K` : `₪${v}`}
                              tickLine={false}
                              axisLine={false}
                            />
                            <Tooltip
                              formatter={(value: number, name: string) => [`₪${value.toLocaleString()}`, name]}
                              labelFormatter={(label, payload) => {
                                if (payload?.[0]) {
                                  const p = payload[0].payload as any;
                                  const [dd, mm, yyyy] = p.date.split('/');
                                  const d = new Date(Number(yyyy), Number(mm)-1, Number(dd));
                                  return d.toLocaleDateString('he-IL', { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' });
                                }
                                return label;
                              }}
                              contentStyle={{ borderRadius: '8px', border: 'none', boxShadow: '0 4px 12px rgba(0,0,0,0.1)', textAlign: 'right', direction: 'rtl' }}
                            />
                            <Legend verticalAlign="top" height={36} wrapperStyle={{ direction: 'rtl' }} />
                            <Area
                              type="monotone"
                              dataKey="supplier"
                              name="שילמתי ל-UPS"
                              stroke="#3b82f6"
                              strokeWidth={2}
                              fill="url(#supplierGrad)"
                              dot={false}
                              activeDot={{ r: 4 }}
                            />
                            <Area
                              type="monotone"
                              dataKey="shipping"
                              name="גביתי מלקוחות"
                              stroke="#22c55e"
                              strokeWidth={2}
                              fill="url(#shippingGrad)"
                              dot={false}
                              activeDot={{ r: 4 }}
                            />
                          </AreaChart>
                        </ResponsiveContainer>
                      </div>
                    </CardContent>
                  </Card>
                ) : (
                  <Card data-testid="card-daily-empty">
                    <CardContent className="py-16 text-center text-muted-foreground">
                      <BarChart2 className="w-16 h-16 mx-auto mb-3 opacity-30" />
                      <p className="text-lg font-medium">אין נתוני הוצאות לשנה זו</p>
                      <p className="text-sm mt-1">הנתונים מגיעים מ-Priority — בדקו שהסנכרון רץ</p>
                    </CardContent>
                  </Card>
                )}

                {/* Daily breakdown table */}
                {dailyData && dailyData.daily.length > 0 && (
                  <Card data-testid="card-daily-table">
                    <CardHeader className="border-b bg-gradient-to-r from-blue-50 to-indigo-50">
                      <CardTitle className="text-blue-900 flex items-center gap-2">
                        <Calendar className="w-5 h-5" />
                        פירוט יומי
                      </CardTitle>
                      <CardDescription>{dailyData.totalDays} ימים פעילים, {dailyData.totalRecords} רשומות</CardDescription>
                    </CardHeader>
                    <CardContent className="pt-4">
                      <ScrollArea className="h-[500px]">
                        <table className="w-full text-sm" data-testid="table-daily">
                          <thead className="sticky top-0 bg-white border-b">
                            <tr className="text-right">
                              <th className="p-3 font-medium text-muted-foreground">תאריך</th>
                              <th className="p-3 font-medium text-muted-foreground">יום</th>
                              <th className="p-3 font-medium text-muted-foreground text-center">רשומות</th>
                              <th className="p-3 font-medium text-muted-foreground text-left">שילמתי ל-UPS</th>
                              <th className="p-3 font-medium text-muted-foreground text-left">גביתי מלקוחות</th>
                              <th className="p-3 font-medium text-muted-foreground text-left">רווח/הפסד</th>
                            </tr>
                          </thead>
                          <tbody>
                            {[...dailyData.daily].reverse().map((d, idx) => {
                              const isMax = dailyData.maxDay?.date === d.date;
                              const [dd, mm, yyyy] = d.date.split('/');
                              const dateObj = new Date(Number(yyyy), Number(mm) - 1, Number(dd));
                              const weekday = dateObj.toLocaleDateString('he-IL', { weekday: 'long' });
                              const isProfit = d.net >= 0;
                              return (
                                <tr
                                  key={d.date}
                                  className={`border-b transition-colors ${isMax ? 'bg-rose-50' : 'hover:bg-slate-50'}`}
                                  data-testid={`daily-row-${idx}`}
                                >
                                  <td className="p-3 font-medium">{d.date}</td>
                                  <td className="p-3 text-muted-foreground text-sm">{weekday}</td>
                                  <td className="p-3 text-center">
                                    <Badge variant="secondary">{d.count}</Badge>
                                  </td>
                                  <td className="p-3 text-left">
                                    <div className="flex items-center gap-2">
                                      <span className={`font-bold ${isMax ? 'text-rose-600' : 'text-blue-700'}`}>
                                        ₪{d.supplier.toLocaleString(undefined, { maximumFractionDigits: 0 })}
                                      </span>
                                      {isMax && <Badge className="text-xs bg-rose-100 text-rose-700 border-rose-200">שיא</Badge>}
                                    </div>
                                  </td>
                                  <td className="p-3 text-left font-medium text-green-700">
                                    {d.shipping > 0 ? `₪${d.shipping.toLocaleString(undefined, { maximumFractionDigits: 0 })}` : '—'}
                                  </td>
                                  <td className="p-3 text-left">
                                    {d.supplier > 0 || d.shipping > 0 ? (
                                      <span className={`font-bold ${isProfit ? 'text-emerald-600' : 'text-red-600'}`}>
                                        {isProfit ? '+' : ''}₪{d.net.toLocaleString(undefined, { maximumFractionDigits: 0 })}
                                      </span>
                                    ) : '—'}
                                  </td>
                                </tr>
                              );
                            })}
                          </tbody>
                        </table>
                      </ScrollArea>
                    </CardContent>
                  </Card>
                )}
              </>
            )}
          </TabsContent>
        </Tabs>

          </TabsContent>
        </Tabs>
      </div>
    </DashboardLayout>
  );
}
