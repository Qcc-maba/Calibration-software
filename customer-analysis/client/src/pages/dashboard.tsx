import React, { useState, useEffect, useRef } from 'react';
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { useSearch, useLocation, useParams } from "wouter";
import { useToast } from "@/hooks/use-toast";
import { fetchCustomerData } from "@/lib/customer-loader";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { ScrollArea } from "@/components/ui/scroll-area";
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription } from "@/components/ui/dialog";
import DashboardLayout from "@/components/layout/DashboardLayout";
import { BilingualText } from "@/components/BilingualText";
import { cn } from "@/lib/utils";
import { 
  Building2, 
  MapPin, 
  Phone, 
  Mail, 
  Truck, 
  TrendingUp,
  Package, 
  FileCheck,
  AlertTriangle,
  CalendarDays,
  MoreHorizontal,
  Download,
  ExternalLink,
  Users,
  FileText,
  Loader2,
  Star,
  Clock,
  ReceiptText,
} from "lucide-react";
import { 
  BarChart, 
  Bar, 
  XAxis, 
  YAxis, 
  CartesianGrid, 
  Tooltip, 
  Legend, 
  ResponsiveContainer, 
  PieChart, 
  Pie, 
  Cell,
  LineChart,
  Line,
  AreaChart,
  Area
} from 'recharts';
import { motion } from "framer-motion";

// Animation variants
const containerVariants = {
  hidden: { opacity: 0 },
  visible: { 
    opacity: 1,
    transition: { 
      staggerChildren: 0.1 
    }
  }
};

const itemVariants = {
  hidden: { y: 20, opacity: 0 },
  visible: { y: 0, opacity: 1 }
};

function InvoicesListCard({ invoices }: { invoices: any[] }) {
  const [selectedYear, setSelectedYear] = useState<number | 'all'>('all');
  
  const years = [2024, 2025, 2026];
  const filteredInvoices = selectedYear === 'all' 
    ? invoices 
    : invoices.filter((inv: any) => inv.year === selectedYear);
  
  const invoicesOnly = filteredInvoices.filter((inv: any) => (inv.invoiceNumber || '').startsWith('I'));
  const receiptsOnly = filteredInvoices.filter((inv: any) => (inv.invoiceNumber || '').startsWith('K'));
  
  const invoicesTotal = invoicesOnly.reduce((sum: number, i: any) => sum + (i.totalPrice || 0), 0);
  const receiptsTotal = receiptsOnly.reduce((sum: number, i: any) => sum + (i.totalPrice || 0), 0);

  const yearTotals = years.map(year => ({
    year,
    count: invoices.filter((i: any) => i.year === year).length
  }));

  const renderDocList = (docs: any[], title: string, total: number, color: string) => (
    <div className="flex-1">
      <div className={`p-3 rounded-t-lg ${color} text-white font-bold flex justify-between`}>
        <span>{title} ({docs.length})</span>
        <span>₪{total.toLocaleString()}</span>
      </div>
      <ScrollArea className="h-[350px] border border-t-0 rounded-b-lg">
        <div className="space-y-1 p-2">
          {docs.map((doc: any, index: number) => (
            <div 
              key={index} 
              className="grid grid-cols-3 gap-2 p-2 rounded text-sm hover:bg-muted/30 transition-colors"
            >
              <span className="font-mono text-xs">{doc.invoiceNumber}</span>
              <span className="text-xs">{doc.date}</span>
              <span className="text-xs font-bold">₪{(doc.totalPrice || 0).toLocaleString()}</span>
            </div>
          ))}
          {docs.length === 0 && (
            <div className="text-center py-8 text-muted-foreground text-sm">אין מסמכים</div>
          )}
        </div>
      </ScrollArea>
    </div>
  );

  return (
    <Card className="lg:col-span-3">
      <CardHeader>
        <div className="flex items-center justify-between flex-wrap gap-2">
          <div>
            <CardTitle>חשבוניות וקבלות</CardTitle>
            <CardDescription>מסמכים מ-Priority</CardDescription>
          </div>
          <div className="flex gap-1 flex-wrap">
            <Button 
              size="sm" 
              variant={selectedYear === 'all' ? 'default' : 'outline'}
              onClick={() => setSelectedYear('all')}
              data-testid="button-filter-all"
            >
              הכל
            </Button>
            {yearTotals.map(({ year, count }) => (
              <Button 
                key={year}
                size="sm" 
                variant={selectedYear === year ? 'default' : 'outline'}
                onClick={() => setSelectedYear(year)}
                data-testid={`button-filter-${year}`}
              >
                {year}
              </Button>
            ))}
          </div>
        </div>
      </CardHeader>
      <CardContent>
        <div className="flex gap-4">
          {renderDocList(invoicesOnly, 'חשבוניות (I)', invoicesTotal, 'bg-blue-600')}
          {renderDocList(receiptsOnly, 'קבלות (K)', receiptsTotal, 'bg-emerald-600')}
        </div>
      </CardContent>
    </Card>
  );
}

const HEBREW_MONTHS: Record<string, string> = {
  '01': 'ינואר', '02': 'פברואר', '03': 'מרץ', '04': 'אפריל',
  '05': 'מאי', '06': 'יוני', '07': 'יולי', '08': 'אוגוסט',
  '09': 'ספטמבר', '10': 'אוקטובר', '11': 'נובמבר', '12': 'דצמבר'
};

export default function Dashboard() {
  const [isFullCardOpen, setIsFullCardOpen] = useState(false);
  const [selectedYear, setSelectedYear] = useState<number | 'all'>('all');
  const [selectedWorkloadMonth, setSelectedWorkloadMonth] = useState<string | null>(null);
  const [selectedInventoryYear, setSelectedInventoryYear] = useState<number>(2025);
  const [excludedCalTypes, setExcludedCalTypes] = useState<Set<string>>(new Set());
  const [deviceSearch, setDeviceSearch] = useState<string>('');

  const queryClient = useQueryClient();
  const { toast } = useToast();
  const prevSyncStatusRef = useRef<string | null>(null);
  
  // Get customer ID from URL path param (/dashboard/:id) or query param (?customer=xxx)
  const params = useParams<{ id?: string }>();
  const searchString = useSearch();
  const [, setLocation] = useLocation();
  const urlParams = new URLSearchParams(searchString);
  const customerIdFromUrl = params.id || urlParams.get('customer');

  // Use customer ID from URL, or fall back to customer 1082 (ישקר בע"מ)
  const selectedCustomerId = customerIdFromUrl || '1082';

  // Poll global sync status to detect when a sync completes
  const { data: globalSyncStatus } = useQuery<{ lastSync: string | null; syncState: { status: string } }>({
    queryKey: ['/api/company/global-sync-status'],
    queryFn: async () => {
      const res = await fetch('/api/company/global-sync-status');
      if (!res.ok) return { lastSync: null, syncState: { status: 'idle' } };
      return res.json();
    },
    refetchInterval: (data) => {
      const st = data?.state?.data?.syncState?.status;
      if (st === 'requested' || st === 'running') return 3000;
      return false;
    },
  });

  const isSyncActive = globalSyncStatus?.syncState?.status === 'requested' || globalSyncStatus?.syncState?.status === 'running';

  // Invalidate the customer query and show toast when sync transitions running → complete
  useEffect(() => {
    const currentStatus = globalSyncStatus?.syncState?.status ?? null;
    const prev = prevSyncStatusRef.current;
    prevSyncStatusRef.current = currentStatus;
    if (prev === 'running' && currentStatus === 'complete') {
      queryClient.invalidateQueries({ queryKey: ['customer', selectedCustomerId] });
      queryClient.invalidateQueries({ queryKey: ['similar-customers', selectedCustomerId] });
      toast({
        title: 'הסנכרון הושלם — הנתונים עודכנו',
        description: 'נתוני הלקוח רועננו אוטומטית',
      });
    }
  }, [globalSyncStatus?.syncState?.status, selectedCustomerId]);

  // Use React Query to fetch data for the selected customer — starts immediately, no list dependency
  const { data: customer, isLoading, error } = useQuery({
    queryKey: ['customer', selectedCustomerId],
    queryFn: () => fetchCustomerData(selectedCustomerId),
    enabled: !!selectedCustomerId
  });

  // Detect if customer has no meaningful data (no devices, no orders, no calibration trends)
  const isEmptyCustomer = !isLoading && customer && (
    (customer.devicesList?.length ?? 0) === 0 &&
    (customer.ordersDetail?.length ?? 0) === 0 &&
    (customer.calibrationTrends?.length ?? 0) === 0
  );

  // Fetch similar customers only when current customer has no data
  const { data: similarData } = useQuery({
    queryKey: ['similar-customers', selectedCustomerId],
    queryFn: () => fetch(`/api/customers/${selectedCustomerId}/similar`).then(r => r.json()),
    enabled: !!isEmptyCustomer,
    staleTime: 60000
  });

  // Auto-select the inventory year with the most calibration data for this customer
  useEffect(() => {
    if (!customer?.calibrationTrends?.length) return;
    const totals = { 2024: 0, 2025: 0, 2026: 0 };
    (customer.calibrationTrends as any[]).forEach((ct: any) => {
      totals[2024] += ct.y2024 || 0;
      totals[2025] += ct.y2025 || 0;
      totals[2026] += ct.y2026 || 0;
    });
    const best = (Object.entries(totals) as [string, number][])
      .sort((a, b) => b[1] - a[1])[0];
    if (best && best[1] > 0) setSelectedInventoryYear(Number(best[0]));
  }, [customer]);

  if (isLoading) {
    return (
      <DashboardLayout>
        <div className="flex flex-col items-center justify-center h-[80vh] gap-4">
          <Loader2 className="h-10 w-10 animate-spin text-primary" />
          <p className="text-muted-foreground animate-pulse">טוען נתוני לקוח...</p>
        </div>
      </DashboardLayout>
    );
  }

  if (error || !customer) {
    return (
      <DashboardLayout>
        <div className="flex flex-col items-center justify-center h-[80vh] gap-4 text-destructive">
          <AlertTriangle className="h-10 w-10" />
          <p>שגיאה בטעינת הנתונים</p>
          <Button variant="outline" onClick={() => window.location.reload()}>נסה שוב</Button>
        </div>
      </DashboardLayout>
    );
  }

  // Prepare financials data with discount percentage
  // Formula: discount% = discounts / (revenue + discounts) * 100
  const financialsWithPercent = (customer.financials || []).map((f: any) => {
    const grossPrice = (f.revenue || 0) + (f.discountsTotal || 0);
    return {
      ...f,
      discountPercent: grossPrice > 0 ? ((f.discountsTotal / grossPrice) * 100).toFixed(1) : 0
    };
  });

  // Calculate monthly calibration distribution from orders
  const monthlyDistribution = (() => {
    const months = ['ינו', 'פבר', 'מרץ', 'אפר', 'מאי', 'יונ', 'יול', 'אוג', 'ספט', 'אוק', 'נוב', 'דצמ'];
    const monthCounts: number[] = new Array(12).fill(0);
    
    (customer.ordersDetail || []).forEach((order: any) => {
      if (order.orderDate) {
        // Parse date format DD/MM/YYYY
        const parts = order.orderDate.split('/');
        if (parts.length >= 2) {
          const month = parseInt(parts[1], 10) - 1; // 0-indexed
          if (month >= 0 && month < 12) {
            monthCounts[month]++;
          }
        }
      }
    });
    
    return months.map((month, idx) => ({
      month,
      monthKey: `2025-${String(idx + 1).padStart(2, '0')}`,
      count: monthCounts[idx]
    }));
  })();

  // Determine calibration type color by part number suffix
  const getSuffixColor = (name: string): string => {
    const parts = (name || '').split('-');
    const suffix = parts[parts.length - 1]?.trim();
    if (suffix === '0' || suffix === '1') return '#2563eb'; // blue - פנים
    if (suffix === '7' || suffix === '8') return '#eab308'; // yellow - חוץ
    if (suffix === '4' || suffix === '5') return '#f97316'; // orange - קבלנים
    return '#94a3b8'; // gray - other
  };

  // Derive devices list from orders if devicesList is empty
  const derivedDevicesList = (() => {
    if (customer.devicesList && customer.devicesList.length > 0) {
      return customer.devicesList;
    }
    
    // Extract unique devices from orders
    const deviceMap = new Map<string, any>();
    (customer.ordersDetail || []).forEach((order: any) => {
      const desc = order.description || '';
      const serialNo = order.serialNo || '';
      
      // Skip transport/shipping items
      if (desc.includes('נסיעה') || desc.includes('הובלה')) return;
      
      // Create unique key from description (device type)
      const key = desc.substring(0, 50);
      
      if (!deviceMap.has(key)) {
        // Determine location from description
        const isExternal = desc.includes('באתרכם') || desc.includes('באתר');
        const isInternal = desc.includes('במבא');
        
        deviceMap.set(key, {
          serialNo: serialNo || '-',
          deviceName: desc.substring(0, 60),
          model: '-',
          manufacturer: '-',
          lastCalDate: order.orderDate || '-',
          nextCalDate: '-',
          status: 'active',
          location: isExternal ? 'external' : (isInternal ? 'internal' : 'internal')
        });
      }
    });
    
    return Array.from(deviceMap.values());
  })();

  // Export customer data to CSV
  const handleExportReport = () => {
    const lines: string[] = [];
    
    // Header
    lines.push('דוח לקוח - ' + customer.companyName);
    lines.push('מספר לקוח: ' + (customer.hp || customer.id));
    lines.push('כתובת: ' + customer.address);
    lines.push('');
    
    // Financials
    lines.push('=== נתונים פיננסיים ===');
    lines.push('שנה,הכנסות,הנחות,הזמנות,הצעות מחיר');
    (customer.financials || []).forEach((f: any) => {
      lines.push(`${f.year},${f.revenue},${f.discountsTotal},${f.ordersCount},${f.quotesCount}`);
    });
    lines.push('');
    
    // Devices summary
    lines.push('=== מלאי מכשירים ===');
    lines.push(`סה"כ מכשירים: ${customer.deviceInventory?.totalDevices || 0}`);
    lines.push(`מכשירים פעילים: ${customer.deviceInventory?.activeDevices || 0}`);
    lines.push(`פג תוקף: ${customer.deviceInventory?.outForCalibration || 0}`);
    lines.push('');
    
    // Orders detail
    if ((customer.ordersDetail?.length ?? 0) > 0) {
      lines.push('=== פירוט הזמנות ===');
      lines.push('מספר הזמנה,הצעת מחיר,תאריך,תיאור,מספר סידורי,הנחה %,סכום');
      (customer.ordersDetail || []).forEach((o: any) => {
        lines.push(`${o.orderNumber},${o.quotation},${o.orderDate},"${o.description}",${o.serialNo},${o.discountPct},${o.priceAfterDiscount}`);
      });
      lines.push('');
    }
    
    // Devices list
    if ((customer.devicesList?.length ?? 0) > 0) {
      lines.push('=== רשימת מכשירים ===');
      lines.push('מספר סידורי,שם מכשיר,מק"ט,יצרן,כיול אחרון,כיול הבא,מק"ט כיול,סטטוס,מיקום');
      (customer.devicesList || []).forEach((d: any) => {
        lines.push(`${d.serialNo},"${d.deviceName}",${d.partNumber || d.model},${d.manufacturer},${d.lastCalDate},${d.nextCalDate},${d.lastCalibrationPart || d.model},${d.status === 'expired' ? 'פג תוקף' : 'בתוקף'},${d.location === 'external' ? 'חוץ' : 'פנים'}`);
      });
    }
    
    // Create and download file
    const content = '\uFEFF' + lines.join('\n'); // BOM for Hebrew
    const blob = new Blob([content], { type: 'text/csv;charset=utf-8' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `דוח_${customer.companyName}_${new Date().toISOString().split('T')[0]}.csv`;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
  };

  const CustomTooltip = ({ active, payload, label }: any) => {
    if (active && payload && payload.length) {
      const yearData = financialsWithPercent.find((f: any) => f.year === label);
      return (
        <div className="bg-popover border border-border p-3 rounded-lg shadow-lg text-xs">
          <p className="font-bold text-popover-foreground mb-1">{label}</p>
          {payload.map((entry: any, index: number) => (
            <p key={index} style={{ color: entry.color }} className="flex items-center gap-2">
              <span className="w-2 h-2 rounded-full" style={{ backgroundColor: entry.color }}></span>
              {entry.name}: {entry.value.toLocaleString()}
            </p>
          ))}
          {yearData && yearData.revenue > 0 && (
            <p className="text-amber-600 mt-1 font-semibold">
              אחוז הנחה: {yearData.discountPercent}%
            </p>
          )}
        </div>
      );
    }
    return null;
  };

  return (
    <DashboardLayout>
      <motion.div 
        className="space-y-8 max-w-7xl mx-auto text-right"
        dir="rtl"
        variants={containerVariants}
        initial="hidden"
        animate="visible"
      >
        {/* Header Section */}
        <motion.div variants={itemVariants} className="flex flex-col md:flex-row md:items-center justify-between gap-4">
          <div>
            <div className="flex items-center gap-3 mb-1">
              <h1 className="text-3xl font-bold tracking-tight text-foreground"><BilingualText text={customer.companyName} /></h1>
              <Badge variant="outline" className="border-primary/20 text-primary bg-primary/5">לקוח פעיל</Badge>
            </div>
            <p className="text-muted-foreground flex items-center gap-2 text-sm">
              <span className="font-mono bg-muted px-1.5 py-0.5 rounded text-xs">מספר לקוח: {customer.hp || customer.id}</span>
              <span>•</span>
              <span className="flex items-center gap-1"><MapPin className="w-3 h-3" /> {customer.address}</span>
            </p>
          </div>
          <div className="flex items-center gap-2 flex-row-reverse">
            <Button variant="outline" className="gap-2" onClick={handleExportReport} data-testid="button-export-report">
              <Download className="w-4 h-4" />
              ייצוא דוח
            </Button>
            <Button className="gap-2 shadow-lg shadow-primary/20" onClick={() => setIsFullCardOpen(true)} data-testid="button-open-full-card">
              <ExternalLink className="w-4 h-4" />
              פתח כרטיס מלא
            </Button>
          </div>
        </motion.div>

        {/* Sync Progress Banner - shown while a sync is running */}
        {isSyncActive && (
          <motion.div variants={itemVariants} data-testid="banner-sync-running">
            <div className="rounded-xl border border-blue-200 bg-blue-50 dark:bg-blue-950/30 dark:border-blue-800 px-4 py-3 flex items-center gap-3">
              <Loader2 className="w-4 h-4 animate-spin text-blue-600 dark:text-blue-400 flex-shrink-0" />
              <span className="text-sm font-medium text-blue-800 dark:text-blue-300">
                {globalSyncStatus?.syncState?.status === 'requested' ? 'סנכרון התבקש — ממתין לסקריפט...' : 'מסנכרן נתוני לקוח — הנתונים יתעדכנו בסיום'}
              </span>
            </div>
          </motion.div>
        )}

        {/* Empty Customer Banner - shown when customer has no calibration/device data */}
        {isEmptyCustomer && (
          <motion.div variants={itemVariants}>
            <div className="rounded-xl border border-amber-200 bg-amber-50 dark:bg-amber-950/30 dark:border-amber-800 p-4 flex flex-col gap-3" dir="rtl">
              <div className="flex items-center gap-2 text-amber-800 dark:text-amber-300">
                <AlertTriangle className="w-5 h-5 flex-shrink-0" />
                <span className="font-semibold text-base">לקוח ללא נתוני כיולים במערכת</span>
              </div>
              <p className="text-sm text-amber-700 dark:text-amber-400">
                ללקוח זה אין מכשירים, הזמנות או כיולים מסונכרנים. ייתכן שמדובר ברשומה כפולה — בדוק את הלקוחות הדומים להלן.
              </p>
              {similarData?.similar?.length > 0 && (
                <div className="flex flex-col gap-2">
                  <p className="text-xs font-medium text-amber-800 dark:text-amber-300">לקוחות דומים עם נתונים:</p>
                  <div className="flex flex-wrap gap-2">
                    {similarData.similar.map((s: any) => (
                      <button
                        key={s.id}
                        onClick={() => setLocation(`/dashboard/${s.id}`)}
                        className="text-xs bg-white dark:bg-amber-900/50 border border-amber-200 dark:border-amber-700 rounded-lg px-3 py-2 text-right hover:bg-amber-100 dark:hover:bg-amber-800/50 transition-colors cursor-pointer"
                        data-testid={`button-similar-customer-${s.id}`}
                      >
                        <div className="font-medium text-amber-900 dark:text-amber-200">{s.company_name}</div>
                        <div className="text-amber-600 dark:text-amber-400 mt-0.5">
                          מס׳ לקוח: {s.hp} · {Number(s.devices).toLocaleString()} מכשירים
                        </div>
                      </button>
                    ))}
                  </div>
                </div>
              )}
            </div>
          </motion.div>
        )}

        {/* Revenue Summary - Top Banner */}
        <motion.div variants={itemVariants}>
           <Card className="bg-gradient-to-l from-primary via-primary to-primary/80 text-primary-foreground border-none shadow-xl shadow-primary/30 relative overflow-hidden">
             <div className="absolute inset-0 bg-[radial-gradient(ellipse_at_top_right,_var(--tw-gradient-stops))] from-white/10 via-transparent to-transparent pointer-events-none" />
             <CardContent className="py-6 relative z-10">
               {(() => {
                 const financials = customer.financials || [];
                 const fin2024 = financials.find((f: any) => f.year === 2024) || { revenue: 0, ordersCount: 0, invoicesCount: 0 };
                 const fin2025 = financials.find((f: any) => f.year === 2025) || { revenue: 0, ordersCount: 0, invoicesCount: 0 };
                 const fin2026 = financials.find((f: any) => f.year === 2026) || { revenue: 0, ordersCount: 0, invoicesCount: 0 };
                 const revenue2026 = Number(fin2026.revenue) || 0;
                 const revenue2025 = Number(fin2025.revenue) || 0;
                 const revenue2024 = Number(fin2024.revenue) || 0;
                 const totalRevenue = revenue2024 + revenue2025 + revenue2026;
                 const docs2026 = (fin2026.invoicesCount || 0) + (fin2026.ordersCount || 0);
                 const docs2025 = (fin2025.invoicesCount || 0) + (fin2025.ordersCount || 0);
                 const docs2024 = (fin2024.invoicesCount || 0) + (fin2024.ordersCount || 0);
                 const totalDocs = docs2024 + docs2025 + docs2026;
                 const growthPct = revenue2025 > 0 
                   ? (((revenue2026 - revenue2025) / revenue2025) * 100).toFixed(1)
                   : null;
                 const discount2025 = Number((fin2025 as any).discountsTotal) || 0;
                 const grossPrice2025 = revenue2025 + discount2025;
                 const discountPct2025 = grossPrice2025 > 0 ? ((discount2025 / grossPrice2025) * 100).toFixed(1) : '0';
                 return (
                   <div className="flex flex-wrap items-center justify-center gap-4">
                     {/* Revenue by Year - Only individual years, no total */}
                     <div className="bg-white/10 rounded-xl p-4 min-w-[140px] text-center">
                       <span className="block text-xs opacity-70 mb-1">הכנסות 2026</span>
                       <span className="font-bold text-2xl">₪{revenue2026.toLocaleString()}</span>
                       <span className="block text-xs opacity-60 mt-1">{docs2026} מסמכים</span>
                       {growthPct && (
                         <span className={cn(
                           "block text-xs mt-1 font-bold",
                           Number(growthPct) >= 0 ? "text-emerald-200" : "text-red-200"
                         )}>
                           {Number(growthPct) >= 0 ? '+' : ''}{growthPct}%
                         </span>
                       )}
                     </div>
                     <div className="bg-white/10 rounded-xl p-4 min-w-[140px] text-center">
                       <span className="block text-xs opacity-70 mb-1">הכנסות 2025</span>
                       <span className="font-bold text-2xl">₪{revenue2025.toLocaleString()}</span>
                       <span className="block text-xs opacity-60 mt-1">{docs2025} מסמכים</span>
                     </div>
                     <div className="bg-white/10 rounded-xl p-4 min-w-[140px] text-center">
                       <span className="block text-xs opacity-70 mb-1">הכנסות 2024</span>
                       <span className="font-bold text-2xl">₪{revenue2024.toLocaleString()}</span>
                       <span className="block text-xs opacity-60 mt-1">{docs2024} מסמכים</span>
                     </div>
                     <div className="bg-amber-500/20 rounded-xl p-4 min-w-[140px] text-center border border-amber-400/30">
                       <span className="block text-xs opacity-70 mb-1">הנחה 2025</span>
                       <span className="font-bold text-2xl">{discountPct2025}%</span>
                       <span className="block text-xs opacity-60 mt-1">₪{discount2025.toLocaleString()}</span>
                     </div>
                   </div>
                 );
               })()}
             </CardContent>
           </Card>
        </motion.div>

        {/* Info Cards Grid */}
        <motion.div variants={itemVariants} className="grid grid-cols-1 md:grid-cols-3 gap-4">
           {/* Contact Info Card */}
           <Card className="border-r-4 border-r-primary/50">
             <CardHeader className="pb-2">
               <CardTitle className="text-sm font-medium text-muted-foreground uppercase tracking-wider flex items-center gap-2">
                 <Users className="w-4 h-4" /> אנשי קשר
                 {customer.contacts?.length > 0 && (
                   <Badge variant="secondary" className="text-xs">{customer.contacts.length}</Badge>
                 )}
               </CardTitle>
             </CardHeader>
             <CardContent className="p-0">
               {customer.contacts?.length > 0 ? (
                 <ScrollArea className="h-[150px] px-6">
                   <div className="space-y-1 py-2">
                     {customer.contacts.slice(0, 20).map((contact: any, index: number) => (
                       <div key={index} className="flex items-center justify-between flex-row-reverse group p-2 hover:bg-muted/50 rounded-md transition-colors">
                         <div className="flex items-center gap-2 flex-row-reverse">
                           <div className="w-8 h-8 bg-primary/10 rounded-full flex items-center justify-center text-primary text-xs font-bold">
                             {contact.name?.charAt(0) || '?'}
                           </div>
                           <div className="text-right">
                             <p className="font-medium text-sm">{contact.name}</p>
                             <p className="text-xs text-muted-foreground">{contact.role || 'איש קשר'}</p>
                           </div>
                         </div>
                         <div className="text-left text-xs space-y-0.5" dir="ltr">
                           {contact.email && (
                             <div className="flex items-center gap-1 text-muted-foreground group-hover:text-primary transition-colors">
                               <Mail className="w-3 h-3" /> {contact.email}
                             </div>
                           )}
                           {contact.phone && (
                             <div className="flex items-center gap-1 text-muted-foreground">
                               <Phone className="w-3 h-3" /> {contact.phone}
                             </div>
                           )}
                         </div>
                       </div>
                     ))}
                   </div>
                 </ScrollArea>
               ) : (
                 <div className="flex flex-col items-center justify-center py-8 text-muted-foreground px-6">
                   <Users className="w-10 h-10 mb-2 opacity-30" />
                   <p className="text-sm">אין אנשי קשר</p>
                   <p className="text-xs">נתוני אנשי קשר יוצגו לאחר סנכרון</p>
                 </div>
               )}
             </CardContent>
           </Card>

           {/* Customer Score */}
           <Card className={cn(
             "border-t-4",
             customer.customerScore?.grade === 'A' ? "border-t-emerald-500" :
             customer.customerScore?.grade === 'B' ? "border-t-blue-500" :
             customer.customerScore?.grade === 'C' ? "border-t-amber-500" :
             customer.customerScore?.grade === 'D' ? "border-t-orange-500" : "border-t-red-500"
           )}>
             <CardHeader className="pb-2">
               <CardTitle className="text-sm font-medium text-muted-foreground uppercase tracking-wider flex items-center gap-2">
                 <Star className="w-4 h-4" /> ציון לקוח
               </CardTitle>
             </CardHeader>
             <CardContent>
               {customer.customerScore ? (
                 <div className="text-center">
                   <div className={cn(
                     "inline-flex items-center justify-center w-16 h-16 rounded-full text-3xl font-bold mb-2",
                     customer.customerScore.grade === 'A' ? "bg-emerald-100 text-emerald-700" :
                     customer.customerScore.grade === 'B' ? "bg-blue-100 text-blue-700" :
                     customer.customerScore.grade === 'C' ? "bg-amber-100 text-amber-700" :
                     customer.customerScore.grade === 'D' ? "bg-orange-100 text-orange-700" : "bg-red-100 text-red-700"
                   )}>
                     {customer.customerScore.grade}
                   </div>
                   <p className="text-sm text-muted-foreground">{customer.customerScore.score}/100</p>
                   <div className="grid grid-cols-3 gap-1 mt-3 text-xs">
                     <div className="text-center" title="ותק">
                       <p className="text-muted-foreground">ותק</p>
                       <p className="font-bold">{customer.customerScore.breakdown?.tenure || 0}</p>
                     </div>
                     <div className="text-center" title="סכום">
                       <p className="text-muted-foreground">סכום</p>
                       <p className="font-bold">{customer.customerScore.breakdown?.revenue || 0}</p>
                     </div>
                     <div className="text-center" title="תדירות">
                       <p className="text-muted-foreground">תדירות</p>
                       <p className="font-bold">{customer.customerScore.breakdown?.frequency || 0}</p>
                     </div>
                   </div>
                 </div>
               ) : (
                 <div className="text-center text-muted-foreground">
                   <Star className="w-8 h-8 mx-auto mb-2 opacity-30" />
                   <p className="text-xs">ציון לא זמין</p>
                   <p className="text-xs">הרץ סנכרון מחדש</p>
                 </div>
               )}
             </CardContent>
           </Card>

           {/* Shipping Info */}
           <Card>
             <CardHeader className="pb-2">
               <CardTitle className="text-sm font-medium text-muted-foreground uppercase tracking-wider flex items-center gap-2">
                 <Truck className="w-4 h-4" /> שינוע
               </CardTitle>
             </CardHeader>
             <CardContent className="flex flex-col items-center justify-center h-[120px]">
               <div className="w-12 h-12 bg-primary/10 rounded-full flex items-center justify-center text-primary mb-2">
                  <Truck className="w-6 h-6" />
               </div>
               <p className="font-bold text-lg">{customer.shippingMethod || '-'}</p>
               <p className="text-xs text-muted-foreground text-center">שיטה מועדפת</p>
             </CardContent>
           </Card>
        </motion.div>

        {/* Main Analytics Section */}
        <motion.div variants={itemVariants}>
          <Tabs defaultValue="financials" className="w-full">
            <div className="flex flex-row-reverse items-center justify-between mb-4">
              <h2 className="text-xl font-bold">ניתוח פעילות</h2>
              <TabsList className="bg-background border border-input">
                <TabsTrigger value="financials">סיכום פיננסי</TabsTrigger>
                <TabsTrigger value="revenue-detail">פירוט הכנסות</TabsTrigger>
                <TabsTrigger value="inventory">ניתוח פעילות</TabsTrigger>
                <TabsTrigger value="distribution">התפלגות</TabsTrigger>
                <TabsTrigger value="devices">מכשירים</TabsTrigger>
              </TabsList>
            </div>

            <TabsContent value="financials" className="mt-0">
               <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
                 {/* Left Column: Revenue Chart + Returns Card */}
                 <div className="md:col-span-2 flex flex-col gap-4">
                 <Card className="text-right">
                   <CardHeader className="text-right">
                     <CardTitle className="text-right">הכנסות והנחות</CardTitle>
                     <CardDescription className="text-right">מגמת הכנסות נטו אל מול הנחות שניתנו לאורך השנים</CardDescription>
                   </CardHeader>
                   <CardContent className="h-[300px]">
                     <ResponsiveContainer width="100%" height="100%">
                       <BarChart 
                         data={[2024, 2025, 2026].map(year => {
                           const yearFinancials = (customer.financials || []).find((f: any) => f.year === year) || { revenue: 0, discountsTotal: 0 };
                           return {
                             year,
                             revenue: Number(yearFinancials.revenue) || 0,
                             discountsTotal: Number(yearFinancials.discountsTotal) || 0
                           };
                         })}
                         margin={{ top: 20, right: 20, left: 30, bottom: 5 }}
                       >
                         <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="hsl(var(--border))" />
                         <XAxis dataKey="year" stroke="hsl(var(--muted-foreground))" fontSize={12} tickLine={false} axisLine={false} />
                         <YAxis orientation="left" stroke="hsl(var(--muted-foreground))" fontSize={12} tickLine={false} axisLine={false} tickFormatter={(value) => `₪${value/1000}k`} />
                         <Tooltip content={<CustomTooltip />} cursor={{fill: 'hsl(var(--muted)/0.4)'}} />
                         <Legend />
                         <Bar dataKey="revenue" name="הכנסות" fill="hsl(var(--chart-1))" radius={[4, 4, 0, 0]} barSize={40} />
                         <Bar dataKey="discountsTotal" name="הנחות" fill="hsl(var(--chart-4))" radius={[4, 4, 0, 0]} barSize={40} />
                       </BarChart>
                     </ResponsiveContainer>
                   </CardContent>
                 </Card>
                 
                 </div>

               </div>

               {/* Monthly Revenue Chart — 3-year comparison */}
               {customer.monthlyRevenue && customer.monthlyRevenue.length > 0 && (
                 <Card className="mt-6 text-right">
                   <CardHeader className="text-right">
                     <CardTitle className="text-right">הכנסות חודשיות — השוואת 3 שנים</CardTitle>
                     <CardDescription className="text-right">השוואת הכנסות חודשיות בין 2024, 2025 ו-2026</CardDescription>
                   </CardHeader>
                   <CardContent className="h-[350px]">
                     {(() => {
                       const MONTH_LABELS = ['ינו','פבר','מרץ','אפר','מאי','יונ','יול','אוג','ספט','אוק','נוב','דצמ'];
                       const byKey: Record<string, Record<string,number>> = {};
                       (customer.monthlyRevenue as any[]).forEach((m: any) => {
                         const [yr, mo] = m.month.split('-');
                         if (!['2024','2025','2026'].includes(yr)) return;
                         if (!byKey[mo]) byKey[mo] = {};
                         byKey[mo][yr] = (byKey[mo][yr] || 0) + (m.revenue || 0);
                       });
                       const chartData = Array.from({length:12},(_,i)=>{
                         const mo = String(i+1).padStart(2,'0');
                         return { month: MONTH_LABELS[i], '2024': byKey[mo]?.['2024']||0, '2025': byKey[mo]?.['2025']||0, '2026': byKey[mo]?.['2026']||0 };
                       });
                       return (
                         <ResponsiveContainer width="100%" height="100%">
                           <BarChart data={chartData} margin={{ top: 10, right: 10, left: 10, bottom: 0 }} barCategoryGap="20%">
                             <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="hsl(var(--border))" />
                             <XAxis dataKey="month" stroke="hsl(var(--muted-foreground))" fontSize={11} tickLine={false} axisLine={false} />
                             <YAxis orientation="left" stroke="hsl(var(--muted-foreground))" fontSize={11} tickLine={false} axisLine={false} tickFormatter={(v)=>`₪${(v/1000).toFixed(0)}k`} width={50} />
                             <Tooltip
                               contentStyle={{ direction:'rtl', textAlign:'right', backgroundColor:'white', border:'1px solid #e5e7eb', borderRadius:'8px', boxShadow:'0 4px 12px rgba(0,0,0,0.1)' }}
                               formatter={(value:any, name:string) => [`₪${Number(value).toLocaleString()}`, name]}
                             />
                             <Legend />
                             <Bar dataKey="2024" fill="#f87171" radius={[3,3,0,0]} barSize={12} />
                             <Bar dataKey="2025" fill="#60a5fa" radius={[3,3,0,0]} barSize={12} />
                             <Bar dataKey="2026" fill="#4ade80" radius={[3,3,0,0]} barSize={12} />
                           </BarChart>
                         </ResponsiveContainer>
                       );
                     })()}
                   </CardContent>
                 </Card>
               )}
            </TabsContent>

            <TabsContent value="revenue-detail" className="mt-0">
              <Card>
                <CardHeader>
                  <div className="flex items-center justify-between flex-wrap gap-2">
                    <div>
                      <CardTitle>פירוט הכנסות (חשבוניות)</CardTitle>
                      <CardDescription>
                        {(() => {
                          const count = selectedYear === 'all' 
                            ? (customer.invoices?.length || 0)
                            : (customer.invoices?.filter((i: any) => Number(i.year) === selectedYear) || []).length;
                          return `סה"כ ${count} חשבוניות מ-Priority`;
                        })()}
                      </CardDescription>
                    </div>
                    <div className="flex gap-2 flex-wrap">
                      <Badge 
                        variant={selectedYear === 'all' ? 'default' : 'outline'} 
                        className="text-sm cursor-pointer hover:bg-primary/80"
                        onClick={() => setSelectedYear('all')}
                        data-testid="filter-year-all"
                      >
                        הכל
                      </Badge>
                      {[2026, 2025, 2024].map(year => {
                        const yearFinancials = (customer.financials || []).find((f: any) => f.year === year) || { revenue: 0 };
                        const yearTotal = Number(yearFinancials.revenue) || 0;
                        return (
                          <Badge 
                            key={year} 
                            variant={selectedYear === year ? 'default' : 'outline'} 
                            className="text-sm cursor-pointer hover:bg-primary/80"
                            onClick={() => setSelectedYear(year)}
                            data-testid={`filter-year-${year}`}
                          >
                            {year}: ₪{yearTotal.toLocaleString()}
                          </Badge>
                        );
                      })}
                    </div>
                  </div>
                </CardHeader>
                <CardContent>
                  {(() => {
                    const filteredInvoices = selectedYear === 'all' 
                      ? (customer.invoices || [])
                      : (customer.invoices?.filter((i: any) => Number(i.year) === selectedYear) || []);
                    const filteredTotal = filteredInvoices.reduce((sum: number, i: any) => sum + (Number(i.netPrice) || 0), 0);
                    const filteredDiscounts = filteredInvoices.reduce((sum: number, i: any) => sum + (Number(i.discount) || 0), 0);
                    
                    return filteredInvoices.length > 0 ? (
                      <ScrollArea className="h-[500px]">
                        <div className="space-y-2">
                          <div className="grid grid-cols-7 gap-2 p-3 bg-muted/50 rounded-lg font-bold text-sm sticky top-0 text-right">
                            <span>מס' חשבונית</span>
                            <span>תאריך</span>
                            <span>שנה</span>
                            <span>מע"מ</span>
                            <span>הנחה</span>
                            <span>% הנחה</span>
                            <span>סכום נטו</span>
                          </div>
                          {filteredInvoices.map((invoice: any, index: number) => {
                            const netPrice = Number(invoice.netPrice) || 0;
                            const discount = Number(invoice.discount) || 0;
                            const discountPct = Number(invoice.discountPct) || 0;
                            return (
                              <div 
                                key={index} 
                                className="grid grid-cols-7 gap-2 p-3 rounded-lg text-sm hover:bg-muted/30 transition-colors border border-transparent text-right"
                              >
                                <span className="font-mono text-xs">{invoice.invoiceNumber || '-'}</span>
                                <span>{invoice.date || '-'}</span>
                                <span>{invoice.year || '-'}</span>
                                <span className="text-muted-foreground">₪{(Number(invoice.vat) || 0).toLocaleString()}</span>
                                <span className={discount > 0 ? 'text-amber-600' : 'text-muted-foreground'}>
                                  {discount > 0 ? `₪${discount.toLocaleString()}` : '-'}
                                </span>
                                <span className={discountPct > 0 ? 'text-amber-600 font-medium' : 'text-muted-foreground'}>
                                  {discountPct > 0 ? `${discountPct.toFixed(1)}%` : '-'}
                                </span>
                                <span className="font-bold text-emerald-600">₪{netPrice.toLocaleString()}</span>
                              </div>
                            );
                          })}
                          <div className="grid grid-cols-7 gap-2 p-3 bg-primary/10 rounded-lg font-bold text-sm mt-4 border-2 border-primary/30 text-right">
                            <span className="col-span-3 text-right">סה"כ ({filteredInvoices.length} חשבוניות)</span>
                            <span></span>
                            <span className="text-amber-600">{filteredDiscounts > 0 ? `₪${filteredDiscounts.toLocaleString()}` : '-'}</span>
                            <span className="text-amber-600">
                              {(() => {
                                const avgPct = (filteredTotal + filteredDiscounts) > 0 
                                  ? (filteredDiscounts / (filteredTotal + filteredDiscounts)) * 100 
                                  : 0;
                                return avgPct > 0 ? `${avgPct.toFixed(1)}%` : '-';
                              })()}
                            </span>
                            <span className="text-primary">₪{filteredTotal.toLocaleString()}</span>
                          </div>
                        </div>
                      </ScrollArea>
                    ) : (
                      <div className="h-[300px] flex flex-col items-center justify-center text-muted-foreground">
                        <FileText className="w-12 h-12 mb-3 opacity-30" />
                        <p className="text-sm">אין חשבוניות ללקוח זה</p>
                        <p className="text-xs">הכנסות מחושבות רק מחשבוניות</p>
                      </div>
                    );
                  })()}
                </CardContent>
              </Card>
            </TabsContent>

            <TabsContent value="inventory" className="mt-0">
               <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
                 {/* Inventory Stats - Based on selected year */}
                 {(() => {
                   const yearKey = `y${selectedInventoryYear}` as 'y2024' | 'y2025' | 'y2026';
                   const yearCalibrations = (customer.calibrationTrends || [])
                     .filter((ct: any) => !excludedCalTypes.has(ct.name))
                     .reduce((sum: number, ct: any) => sum + (ct[yearKey] || 0), 0);
                   return (
                 <div className="space-y-4">
                    <Card className="bg-accent/10 border-accent/20">
                      <CardContent className="pt-6">
                        <div className="flex items-center justify-between flex-row-reverse">
                          <div className="text-right">
                            <p className="text-sm font-medium text-muted-foreground">סה"כ כיולים {selectedInventoryYear}</p>
                            <h3 className="text-3xl font-bold text-foreground">{yearCalibrations.toLocaleString()}</h3>
                          </div>
                          <Package className="w-8 h-8 text-primary/50" />
                        </div>
                      </CardContent>
                    </Card>
                 </div>
                   );
                 })()}

                 {/* Calibration Types */}
                 <Card className="md:col-span-2">
                   <CardHeader className="text-right" dir="rtl">
                     <div className="flex items-center justify-between flex-wrap gap-2">
                       <div>
                         <CardTitle>התפלגות סוגי כיולים</CardTitle>
                         <CardDescription>שנת {selectedInventoryYear}</CardDescription>
                       </div>
                       <div className="flex gap-2">
                         {[2024, 2025, 2026].map(year => (
                           <Badge 
                             key={year} 
                             variant={selectedInventoryYear === year ? 'default' : 'outline'} 
                             className="text-sm cursor-pointer hover:bg-primary/80"
                             onClick={() => setSelectedInventoryYear(year)}
                             data-testid={`filter-inventory-year-${year}`}
                           >
                             {year}
                           </Badge>
                         ))}
                       </div>
                     </div>
                   </CardHeader>
                   <CardContent className="h-[350px]">
                     {(() => {
                       const yearKey = `y${selectedInventoryYear}` as 'y2024' | 'y2025' | 'y2026';
                       const allCalTypes = (customer.calibrationTrends || [])
                         .filter((ct: any) => ct[yearKey] > 0)
                         .map((ct: any) => ({
                           name: ct.name,
                           value: ct[yearKey],
                           color: getSuffixColor(ct.name),
                           excluded: excludedCalTypes.has(ct.name)
                         }))
                         .sort((a: any, b: any) => b.value - a.value)
                         .slice(0, 15);
                       const filteredCalibrationTypes = allCalTypes.filter((ct: any) => !ct.excluded);
                       const toggleExclude = (name: string) => {
                         setExcludedCalTypes(prev => {
                           const next = new Set(prev);
                           if (next.has(name)) next.delete(name);
                           else next.add(name);
                           return next;
                         });
                       };
                       
                       return filteredCalibrationTypes.length > 0 ? (
                       <div className="flex flex-row-reverse h-full gap-4">
                         {/* Pie Chart */}
                         <div className="flex-shrink-0 w-[250px] h-full">
                           <ResponsiveContainer width="100%" height="100%">
                             <PieChart>
                               <Pie
                                 data={filteredCalibrationTypes}
                                 cx="50%"
                                 cy="50%"
                                 innerRadius={60}
                                 outerRadius={90}
                                 paddingAngle={3}
                                 dataKey="value"
                                 nameKey="name"
                               >
                                 {filteredCalibrationTypes.map((entry: any, index: number) => (
                                   <Cell key={`cell-${index}`} fill={entry.color} strokeWidth={0} />
                                 ))}
                               </Pie>
                               <Tooltip />
                             </PieChart>
                           </ResponsiveContainer>
                         </div>
                         {/* Custom Legend - Click to exclude/include */}
                         <ScrollArea className="flex-1 h-full px-4">
                           <div className="space-y-2 text-right">
                             <p className="text-[10px] text-muted-foreground mb-2">לחץ על שורה להסתיר/להציג</p>
                             {allCalTypes.map((entry: any, index: number) => (
                               <div 
                                 key={index} 
                                 className={cn(
                                   "flex items-center gap-3 text-sm justify-end flex-row-reverse cursor-pointer rounded-md px-2 py-1 transition-all hover:bg-muted/50",
                                   entry.excluded && "opacity-40 line-through"
                                 )}
                                 title={entry.excluded ? "לחץ להציג בגרף" : "לחץ להסתיר מהגרף"}
                                 onClick={() => toggleExclude(entry.name)}
                                 data-testid={`toggle-cal-type-${index}`}
                               >
                                 <span className="w-3 h-3 rounded-full flex-shrink-0" style={{ backgroundColor: entry.color }}></span>
                                 <span className="font-mono text-muted-foreground text-xs whitespace-nowrap">({entry.value.toLocaleString()})</span>
                                 <span className="text-sm flex-1 text-right">{entry.name}</span>
                               </div>
                             ))}
                             {(customer.calibrationTrends || []).filter((ct: any) => ct[yearKey] > 0).length > 15 && (
                               <p className="text-[10px] text-muted-foreground pt-1">
                                 + {(customer.calibrationTrends || []).filter((ct: any) => ct[yearKey] > 0).length - 15} סוגים נוספים
                               </p>
                             )}
                           </div>
                         </ScrollArea>
                       </div>
                     ) : (
                       <div className="h-full flex flex-col items-center justify-center text-muted-foreground">
                         <Package className="w-12 h-12 mb-3 opacity-30" />
                         <p className="text-sm">אין נתוני כיולים לשנת {selectedInventoryYear}</p>
                         <p className="text-xs">בחר שנה אחרת או סנכרן נתונים</p>
                       </div>
                     );
                     })()}
                   </CardContent>
                 </Card>
               </div>
            </TabsContent>

            <TabsContent value="distribution" className="mt-0">
               <div className="grid grid-cols-1 gap-6">
                 {/* Location Split by Suffix - Full Width */}
                 <Card>
                   <CardHeader className="text-right">
                     <CardTitle>התפלגות סוגי כיול לפי סיומות</CardTitle>
                     <CardDescription>פנים (0,1) | חוץ (7,8) | קבלני משנה (4,5) — לפי 12 חודשים אחרונים</CardDescription>
                   </CardHeader>
                   <CardContent>
                     {(() => {
                       const groups: Record<string, number> = { פנים: 0, חוץ: 0, קבלנים: 0, אחר: 0 };
                       const groupColors: Record<string, string> = { פנים: '#2563eb', חוץ: '#eab308', קבלנים: '#f97316', אחר: '#94a3b8' };
                       const sourceData = (customer.calibrationByLocation?.length ?? 0) > 0
                         ? (customer.calibrationByLocation || []).map((item: any) => ({ name: item.name, count: (item.internal || 0) + (item.external || 0) }))
                         : (customer.calibrationTrends || []).map((ct: any) => ({ name: ct.name, count: (ct.y2025 || 0) + (ct.y2026 || 0) }));

                       sourceData.forEach((item: any) => {
                         const parts = (item.name || '').split('-');
                         const suffix = parts[parts.length - 1]?.trim();
                         const count = item.count || 0;
                         if (suffix === '0' || suffix === '1') groups.פנים += count;
                         else if (suffix === '7' || suffix === '8') groups.חוץ += count;
                         else if (suffix === '4' || suffix === '5') groups.קבלנים += count;
                         else groups.אחר += count;
                       });

                       const grandTotal = Object.values(groups).reduce((a, b) => a + b, 0);
                       if (grandTotal === 0) return (
                         <div className="h-[200px] flex flex-col items-center justify-center text-muted-foreground">
                           <Package className="w-12 h-12 mb-3 opacity-30" />
                           <p className="text-sm">אין נתוני התפלגות</p>
                         </div>
                       );

                       return (
                         <div className="space-y-4" dir="rtl">
                           {Object.entries(groups).filter(([, v]) => v > 0).sort(([,a],[,b]) => b - a).map(([name, count]) => {
                             const pct = Math.round((count / grandTotal) * 100);
                             return (
                               <div key={name} className="space-y-1">
                                 <div className="flex justify-between text-sm">
                                   <span className="font-medium" style={{ color: groupColors[name] }}>{name}</span>
                                   <span className="text-muted-foreground text-xs">{count.toLocaleString()} כיולים ({pct}%)</span>
                                 </div>
                                 <div className="flex h-6 rounded-full overflow-hidden bg-muted">
                                   <div
                                     className="flex items-center justify-center text-[10px] text-white font-medium transition-all"
                                     style={{ width: `${pct}%`, backgroundColor: groupColors[name] }}
                                   >
                                     {pct > 8 && `${pct}%`}
                                   </div>
                                 </div>
                               </div>
                             );
                           })}
                           <div className="flex flex-wrap justify-center gap-4 pt-4 border-t text-sm">
                             {Object.entries(groupColors).map(([name, color]) => (
                               <span key={name} className="flex items-center gap-2">
                                 <span className="w-3 h-3 rounded-full" style={{ backgroundColor: color }}></span>
                                 כיול {name}
                               </span>
                             ))}
                           </div>
                         </div>
                       );
                     })()}
                   </CardContent>
                 </Card>

                 {/* Total Calibrations Summary */}
                 {(() => {
                   const grandTotal = (customer.calibrationTrends || []).reduce((sum: number, ct: any) => sum + (ct.y2024 || 0) + (ct.y2025 || 0) + (ct.y2026 || 0), 0);
                   return grandTotal > 0 ? (
                     <Card>
                       <CardHeader className="text-right">
                         <CardTitle>סה&quot;כ כיולים</CardTitle>
                       </CardHeader>
                       <CardContent>
                         <div className="text-center">
                           <p className="text-5xl font-bold text-primary">{grandTotal.toLocaleString()}</p>
                           <p className="text-sm text-muted-foreground mt-2">סה&quot;כ כיולים (כל השנים)</p>
                         </div>
                       </CardContent>
                     </Card>
                   ) : null;
                 })()}

                 <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                   {/* Monthly Distribution */}
                   <Card>
                     <CardHeader className="text-right">
                       <CardTitle>עומס כיולים שנתי - 2025</CardTitle>
                       <CardDescription>לחץ על עמודה לראות את המכשירים שכוילו</CardDescription>
                     </CardHeader>
                     <CardContent className="h-[300px]">
                       {monthlyDistribution.some((m: any) => m.count > 0) ? (
                         <ResponsiveContainer width="100%" height="100%">
                           <BarChart data={monthlyDistribution} margin={{ top: 10, right: 10, left: 10, bottom: 0 }}>
                             <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="hsl(var(--border))" />
                             <XAxis dataKey="month" stroke="hsl(var(--muted-foreground))" fontSize={12} tickLine={false} axisLine={false} />
                             <YAxis orientation="left" stroke="hsl(var(--muted-foreground))" fontSize={12} tickLine={false} axisLine={false} allowDecimals={false} label={{ value: 'מכשירים', angle: -90, position: 'insideLeft', style: { textAnchor: 'middle', fontSize: 10, fill: 'hsl(var(--muted-foreground))' } }} />
                             <Tooltip cursor={{fill: 'hsl(var(--muted)/0.4)'}} contentStyle={{borderRadius: '8px', border: 'none', boxShadow: '0 4px 12px rgba(0,0,0,0.1)'}} formatter={(value: any) => [`${value} מכשירים`, 'כמות']} />
                             <Bar 
                               dataKey="count" 
                               name="מכשירים" 
                               fill="hsl(var(--primary))" 
                               radius={[4, 4, 0, 0]}
                               cursor="pointer"
                               onClick={(data: any) => data?.count > 0 && setSelectedWorkloadMonth(data.monthKey)}
                             />
                           </BarChart>
                         </ResponsiveContainer>
                       ) : (
                         <div className="h-full flex flex-col items-center justify-center text-muted-foreground">
                           <CalendarDays className="w-12 h-12 mb-3 opacity-30" />
                           <p className="text-sm">אין נתוני פיזור חודשי</p>
                           <p className="text-xs">נתונים יוצגו לאחר סנכרון כיולים</p>
                         </div>
                       )}
                     </CardContent>
                   </Card>
                   
                   {/* Selected Month Devices Modal */}
                   {selectedWorkloadMonth && (
                     <Dialog open={!!selectedWorkloadMonth} onOpenChange={() => setSelectedWorkloadMonth(null)}>
                       <DialogContent className="max-w-lg max-h-[80vh] overflow-y-auto" dir="rtl">
                         <DialogHeader>
                           <DialogTitle className="text-right">הזמנות כיול - {HEBREW_MONTHS[selectedWorkloadMonth.split('-')[1]] || selectedWorkloadMonth} 2025</DialogTitle>
                         </DialogHeader>
                         <div className="space-y-2">
                           {(() => {
                             const monthNum = selectedWorkloadMonth.split('-')[1];
                             const filteredOrders = (customer.ordersDetail || []).filter((o: any) => {
                               if (!o.orderDate) return false;
                               const parts = o.orderDate.split('/');
                               return parts.length >= 2 && parts[1] === monthNum && parts[2]?.includes('2025');
                             });
                             const totalItems = filteredOrders.reduce((sum: number, o: any) => {
                               const match = o.description?.match(/(\d+)\s*פריטים?/);
                               return sum + (match ? parseInt(match[1]) : 1);
                             }, 0);
                             return filteredOrders.length > 0 ? (
                               <>
                                 <div className="bg-primary/10 p-3 rounded-lg text-center mb-3">
                                   <p className="text-lg font-bold text-primary">{totalItems} מכשירים</p>
                                   <p className="text-xs text-muted-foreground">ב-{filteredOrders.length} הזמנות</p>
                                 </div>
                                 {filteredOrders.map((order: any, idx: number) => (
                                   <div key={idx} className="p-3 rounded-lg border bg-muted/30 text-right">
                                     <div className="flex justify-between items-start">
                                       <span className="text-xs font-mono text-muted-foreground">{order.orderNumber}</span>
                                       <span className="font-medium text-sm">{order.description}</span>
                                     </div>
                                     <p className="text-xs text-muted-foreground mt-1">
                                       {order.orderDate} • ₪{order.priceAfterDiscount?.toLocaleString()}
                                     </p>
                                   </div>
                                 ))}
                               </>
                             ) : (
                               <p className="text-center text-muted-foreground py-4">אין הזמנות בחודש זה</p>
                             );
                           })()}
                         </div>
                       </DialogContent>
                     </Dialog>
                   )}
                   
                 </div>
               </div>
            </TabsContent>

            <TabsContent value="devices" className="mt-0">
              <Card className="text-right">
                <CardHeader>
                  <div className="flex flex-row-reverse items-center justify-between">
                    <div className="text-right">
                      <CardTitle>רשימת מכשירים</CardTitle>
                      <CardDescription>כל המכשירים של הלקוח וסטטוס הכיול שלהם</CardDescription>
                    </div>
                    <div className="flex items-center gap-3 flex-wrap">
                      <input
                        type="text"
                        placeholder="חיפוש מכשיר..."
                        value={deviceSearch}
                        onChange={e => setDeviceSearch(e.target.value)}
                        className="border rounded-md px-3 py-1 text-sm w-44 focus:outline-none focus:ring-1 focus:ring-primary"
                        dir="rtl"
                      />
                      {(() => {
                        const expiredCount = derivedDevicesList.filter((d: any) => d.status === 'expired').length;
                        return expiredCount > 0 ? (
                          <Badge variant="destructive" className="text-sm gap-1">
                            <AlertTriangle className="w-3 h-3" />
                            {expiredCount} פגי תוקף
                          </Badge>
                        ) : null;
                      })()}
                      <Badge variant="outline" className="text-sm">
                        {derivedDevicesList.length} מכשירים
                      </Badge>
                    </div>
                  </div>
                </CardHeader>
                <CardContent>
                  {derivedDevicesList.length > 0 ? (
                    <ScrollArea className="h-[500px]">
                      <div className="space-y-2">
                        <div className="grid grid-cols-9 gap-2 p-3 bg-muted/50 rounded-lg font-bold text-sm sticky top-0 text-right" dir="rtl">
                          <span>תוקף</span>
                          <span>מיקום</span>
                          <span>כיול הבא</span>
                          <span>כיול אחרון</span>
                          <span>מק"ט כיול</span>
                          <span>יצרן</span>
                          <span>מק"ט</span>
                          <span>תיאור מכשיר</span>
                          <span>מספר סידורי</span>
                        </div>
                        {[...derivedDevicesList].filter((d: any) => {
                          if (!deviceSearch.trim()) return true;
                          const q = deviceSearch.toLowerCase();
                          return (
                            (d.deviceName || '').toLowerCase().includes(q) ||
                            (d.serialNo || '').toLowerCase().includes(q) ||
                            (d.manufacturer || '').toLowerCase().includes(q) ||
                            (d.model || '').toLowerCase().includes(q) ||
                            (d.partNumber || '').toLowerCase().includes(q)
                          );
                        }).sort((a: any, b: any) => {
                          // Expired first
                          if (a.status === 'expired' && b.status !== 'expired') return -1;
                          if (a.status !== 'expired' && b.status === 'expired') return 1;
                          // Then by nextCalDate ascending (closest upcoming first)
                          if (!a.nextCalDate && !b.nextCalDate) return 0;
                          if (!a.nextCalDate) return 1;
                          if (!b.nextCalDate) return -1;
                          // Parse DD/MM/YYYY format
                          const parseDate = (d: string) => {
                            const parts = d.split('/');
                            if (parts.length === 3) {
                              return new Date(parseInt(parts[2]), parseInt(parts[1]) - 1, parseInt(parts[0])).getTime();
                            }
                            return 0;
                          };
                          return parseDate(a.nextCalDate) - parseDate(b.nextCalDate);
                        }).map((device: any, index: number) => (
                          <div 
                            key={index} 
                            dir="rtl"
                            className={cn(
                              "grid grid-cols-9 gap-2 p-3 rounded-lg text-sm hover:bg-muted/30 transition-colors border text-right",
                              device.status === 'expired' ? "border-destructive/30 bg-destructive/5" : "border-transparent"
                            )}
                          >
                            <span>
                              <Badge 
                                variant={device.status === 'expired' ? 'destructive' : 'default'}
                                className="text-xs"
                              >
                                {device.status === 'expired' ? 'פג תוקף' : 'בתוקף'}
                              </Badge>
                            </span>
                            <span>
                              <Badge 
                                variant="outline" 
                                className={cn("text-xs", device.location === 'external' ? 'border-yellow-500 bg-yellow-50 text-yellow-700' : 'border-blue-500 bg-blue-50 text-blue-700')}
                              >
                                {device.location === 'external' ? 'חוץ' : 'פנים'}
                              </Badge>
                            </span>
                            <span className={device.status === 'expired' ? 'text-destructive font-bold' : ''}>{device.nextCalDate || '-'}</span>
                            <span>{device.lastCalDate || '-'}</span>
                            <span className="truncate font-mono text-xs text-muted-foreground">{device.lastCalibrationPart || device.model || '-'}</span>
                            <span className="truncate text-muted-foreground">{device.manufacturer || '-'}</span>
                            <span className="truncate font-mono text-xs">{device.partNumber || device.model || '-'}</span>
                            <span className="truncate" title={device.deviceName}>{device.deviceName}</span>
                            <span className="font-mono text-xs">{device.serialNo}</span>
                          </div>
                        ))}
                      </div>
                    </ScrollArea>
                  ) : (
                    <div className="h-[300px] flex flex-col items-center justify-center text-muted-foreground">
                      <Package className="w-12 h-12 mb-3 opacity-30" />
                      <p className="text-sm">אין רשימת מכשירים</p>
                      <p className="text-xs">הרץ סנכרון מחדש לקבלת הנתונים</p>
                    </div>
                  )}
                </CardContent>
              </Card>
            </TabsContent>
          </Tabs>
        </motion.div>

        {/* Bottom Section: Alerts & Notes */}
        <motion.div variants={itemVariants} className="grid grid-cols-1 md:grid-cols-2 gap-6">
           {/* Alerts */}
           <Card className="border-r-4 border-r-destructive/60 overflow-hidden">
             <CardHeader className="bg-destructive/5 pb-3">
               <CardTitle className="text-destructive flex items-center gap-2">
                 <AlertTriangle className="w-5 h-5" /> התראות כיול
                 {customer.alerts?.length > 0 && (
                   <Badge variant="destructive" className="text-xs">{customer.alerts.length}</Badge>
                 )}
               </CardTitle>
             </CardHeader>
             <CardContent className="p-0">
               {customer.alerts?.length > 0 ? (
                 <ScrollArea className="h-[250px]">
                   <div className="divide-y divide-border">
                     {customer.alerts.slice(0, 10).map((alert: any, index: number) => (
                       <div key={index} className="p-4 hover:bg-muted/30 transition-colors">
                         <div className="flex items-start gap-3 mb-2">
                            <div className={cn(
                              "w-2 h-2 mt-2 rounded-full flex-shrink-0", 
                              alert.type === 'warning' ? "bg-amber-400" : "bg-destructive animate-pulse"
                            )}></div>
                            <div className="flex-1">
                              <p className="font-bold text-sm">{alert.title?.replace(' - כיול באיחור', '')}</p>
                              <p className="text-xs text-muted-foreground">ס"נ: {alert.serialNo || alert.message?.split('ס"נ: ')[1]?.split(',')[0] || ''}</p>
                            </div>
                            <Badge variant="destructive" className="text-xs flex-shrink-0">פג תוקף</Badge>
                         </div>
                         <div className="grid grid-cols-2 gap-2 mr-5 text-xs">
                           <div className="bg-muted/50 rounded-lg p-2 text-center">
                             <span className="block text-muted-foreground mb-0.5">כויל לאחרונה</span>
                             <span className="font-bold text-foreground">{alert.lastCalDate || 'לא ידוע'}</span>
                           </div>
                           <div className="bg-destructive/10 rounded-lg p-2 text-center border border-destructive/20">
                             <span className="block text-destructive/80 mb-0.5">תאריך כיול הבא</span>
                             <span className="font-bold text-destructive">{alert.nextCalDate || 'לא ידוע'}</span>
                           </div>
                         </div>
                       </div>
                     ))}
                   </div>
                 </ScrollArea>
               ) : (
                 <div className="h-[250px] flex flex-col items-center justify-center text-muted-foreground">
                   <FileCheck className="w-12 h-12 mb-3 opacity-30 text-emerald-500" />
                   <p className="text-sm text-emerald-600 font-medium">אין התראות כיול</p>
                   <p className="text-xs">כל המכשירים מכוילים בזמן</p>
                 </div>
               )}
             </CardContent>
           </Card>

        </motion.div>
      </motion.div>

      {/* Full Customer Card Dialog */}
      <Dialog open={isFullCardOpen} onOpenChange={setIsFullCardOpen}>
        <DialogContent className="max-w-4xl max-h-[90vh] overflow-hidden" dir="rtl">
          <DialogHeader>
            <DialogTitle className="text-xl flex items-center gap-2">
              <Building2 className="w-5 h-5 text-primary" />
              <BilingualText text={customer.companyName} />
            </DialogTitle>
            <DialogDescription>כרטיס לקוח מלא</DialogDescription>
          </DialogHeader>
          <ScrollArea className="h-[70vh] pr-4">
            <div className="space-y-6">
              {/* Basic Info */}
              <div className="grid grid-cols-2 gap-4 p-4 bg-muted/30 rounded-lg">
                <div>
                  <span className="text-xs text-muted-foreground block mb-1">מספר לקוח</span>
                  <span className="font-mono font-bold">{customer.hp || customer.id}</span>
                </div>
                <div>
                  <span className="text-xs text-muted-foreground block mb-1">כתובת</span>
                  <span>{customer.address || 'לא צוינה'}</span>
                </div>
                <div>
                  <span className="text-xs text-muted-foreground block mb-1">שיטת משלוח</span>
                  <span>{customer.shippingMethod || 'לא צוינה'}</span>
                </div>
                <div>
                  <span className="text-xs text-muted-foreground block mb-1">סוכן</span>
                  <span>{customer.agentName || 'לא צוין'}</span>
                </div>
              </div>

              {/* Contacts */}
              {customer.contacts?.length > 0 && (
                <div>
                  <h3 className="font-bold mb-3 flex items-center gap-2">
                    <Users className="w-4 h-4" /> אנשי קשר ({customer.contacts.length})
                  </h3>
                  <div className="grid grid-cols-2 gap-3">
                    {customer.contacts.map((contact: any, i: number) => (
                      <div key={i} className="p-3 bg-muted/20 rounded-lg border">
                        <p className="font-bold text-sm">{contact.name}</p>
                        <p className="text-xs text-muted-foreground">{contact.role}</p>
                        {contact.email && <p className="text-xs mt-1 flex items-center gap-1"><Mail className="w-3 h-3" /> {contact.email}</p>}
                        {contact.phone && <p className="text-xs flex items-center gap-1"><Phone className="w-3 h-3" /> {contact.phone}</p>}
                      </div>
                    ))}
                  </div>
                </div>
              )}

              {/* Financial Summary */}
              <div>
                <h3 className="font-bold mb-3 flex items-center gap-2">
                  <TrendingUp className="w-4 h-4" /> סיכום פיננסי
                </h3>
                <div className="grid grid-cols-3 gap-3">
                  {(customer.financials || []).map((f: any) => (
                    <div key={f.year} className="p-3 bg-muted/20 rounded-lg border text-center">
                      <p className="text-lg font-bold text-primary">{f.year}</p>
                      <p className="text-xl font-bold text-emerald-600">₪{f.revenue.toLocaleString()}</p>
                      <p className="text-xs text-muted-foreground">{f.ordersCount} הזמנות • {f.quotesCount} הצעות</p>
                    </div>
                  ))}
                </div>
              </div>

              {/* Device Summary */}
              <div>
                <h3 className="font-bold mb-3 flex items-center gap-2">
                  <Package className="w-4 h-4" /> מלאי מכשירים
                </h3>
                <div className="grid grid-cols-3 gap-3">
                  <div className="p-3 bg-muted/20 rounded-lg border text-center">
                    <p className="text-2xl font-bold">{customer.deviceInventory?.totalDevices || 0}</p>
                    <p className="text-xs text-muted-foreground">סה"כ מכשירים</p>
                  </div>
                  <div className="p-3 bg-emerald-500/10 rounded-lg border border-emerald-500/30 text-center">
                    <p className="text-2xl font-bold text-emerald-600">{customer.deviceInventory?.activeDevices || 0}</p>
                    <p className="text-xs text-muted-foreground">בתוקף</p>
                  </div>
                  <div className="p-3 bg-destructive/10 rounded-lg border border-destructive/30 text-center">
                    <p className="text-2xl font-bold text-destructive">{customer.deviceInventory?.outForCalibration || 0}</p>
                    <p className="text-xs text-muted-foreground">פג תוקף</p>
                  </div>
                </div>
              </div>

              {/* Alerts */}
              {customer.alerts?.length > 0 && (
                <div>
                  <h3 className="font-bold mb-3 flex items-center gap-2 text-destructive">
                    <AlertTriangle className="w-4 h-4" /> התראות ({customer.alerts.length})
                  </h3>
                  <div className="space-y-2">
                    {customer.alerts.slice(0, 5).map((alert: any, i: number) => (
                      <div key={i} className="p-2 bg-destructive/10 rounded-lg border border-destructive/30 text-sm">
                        <span className="font-bold">{alert.title}</span>
                        <span className="text-xs text-muted-foreground mr-2">• ס"נ: {alert.serialNo}</span>
                      </div>
                    ))}
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
