import { useQuery } from "@tanstack/react-query";
import { motion } from "framer-motion";
import DashboardLayout from "@/components/layout/DashboardLayout";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { 
  AlertTriangle,
  Loader2,
  TrendingUp,
  Building2,
  Package,
  DollarSign,
  ShoppingCart,
  Users,
  Calendar
} from "lucide-react";

export default function AlertsPage() {
  const { data: alerts, isLoading } = useQuery({
    queryKey: ['alerts-summary'],
    queryFn: async () => {
      const res = await fetch('/api/alerts/summary');
      return res.json();
    }
  });

  if (isLoading) {
    return (
      <DashboardLayout>
        <div className="flex flex-col items-center justify-center h-[80vh] gap-4">
          <Loader2 className="h-10 w-10 animate-spin text-primary" />
          <p className="text-muted-foreground">טוען נתוני התראות...</p>
        </div>
      </DashboardLayout>
    );
  }

  const topByRevenue = alerts?.topByRevenue || [];
  const topByOrders = alerts?.topByOrders || [];
  const topByExpiredDevices = alerts?.topByExpiredDevices || [];
  const topByMonthlyRevenue = alerts?.topByMonthlyRevenue || [];
  
  const monthNames = ['ינואר', 'פברואר', 'מרץ', 'אפריל', 'מאי', 'יוני', 'יולי', 'אוגוסט', 'ספטמבר', 'אוקטובר', 'נובמבר', 'דצמבר'];
  const currentMonthName = monthNames[(alerts?.currentMonth || 1) - 1];

  return (
    <DashboardLayout>
      <motion.div 
        className="space-y-6 max-w-7xl mx-auto text-right"
        dir="rtl"
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
      >
        <div>
          <h1 className="text-3xl font-bold flex items-center gap-3">
            <AlertTriangle className="w-8 h-8 text-amber-500" />
            סיכום התראות כללי
          </h1>
          <p className="text-muted-foreground">סקירה כללית של כל הלקוחות במערכת</p>
        </div>

        {/* Summary Cards */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-5 gap-4">
          <Card>
            <CardHeader className="pb-2">
              <CardTitle className="text-sm text-muted-foreground flex items-center gap-2">
                <Users className="w-4 h-4" />
                סה"כ לקוחות
              </CardTitle>
            </CardHeader>
            <CardContent>
              <p className="text-3xl font-bold" data-testid="text-total-customers">
                {alerts?.totalCustomers || 0}
              </p>
            </CardContent>
          </Card>

          <Card>
            <CardHeader className="pb-2">
              <CardTitle className="text-sm text-muted-foreground flex items-center gap-2">
                <TrendingUp className="w-4 h-4" />
                לקוחות פעילים
              </CardTitle>
            </CardHeader>
            <CardContent>
              <p className="text-3xl font-bold text-green-600" data-testid="text-active-customers">
                {alerts?.customersWithActivity || 0}
              </p>
            </CardContent>
          </Card>

          <Card className="border-blue-500 border-2 bg-blue-50/30">
            <CardHeader className="pb-2">
              <CardTitle className="text-sm text-muted-foreground flex items-center gap-2">
                <Calendar className="w-4 h-4 text-blue-600" />
                הכנסות נטו - {currentMonthName}
              </CardTitle>
            </CardHeader>
            <CardContent>
              <p className="text-2xl font-bold text-blue-600" data-testid="text-monthly-revenue">
                ₪{(alerts?.totalMonthlyNetRevenue || 0).toLocaleString()}
              </p>
              <p className="text-xs text-muted-foreground">(לפני מע"מ)</p>
            </CardContent>
          </Card>

          <Card>
            <CardHeader className="pb-2">
              <CardTitle className="text-sm text-muted-foreground flex items-center gap-2">
                <Package className="w-4 h-4" />
                סה"כ מכשירים
              </CardTitle>
            </CardHeader>
            <CardContent>
              <p className="text-3xl font-bold" data-testid="text-total-devices">
                {alerts?.totalDevices || 0}
              </p>
            </CardContent>
          </Card>

          <Card className={alerts?.totalExpiredDevices > 0 ? 'border-amber-500 border-2' : ''}>
            <CardHeader className="pb-2">
              <CardTitle className="text-sm text-muted-foreground flex items-center gap-2">
                <AlertTriangle className="w-4 h-4 text-amber-500" />
                מכשירים פגי תוקף
              </CardTitle>
            </CardHeader>
            <CardContent>
              <p className="text-3xl font-bold text-amber-600" data-testid="text-expired-devices">
                {alerts?.totalExpiredDevices || 0}
              </p>
            </CardContent>
          </Card>
        </div>

        {/* Top Companies Lists */}
        <div className="grid grid-cols-1 lg:grid-cols-4 gap-6">
          {/* Top by Monthly Revenue (Current Month) */}
          <Card className="border-blue-200 bg-blue-50/20">
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <Calendar className="w-5 h-5 text-blue-600" />
                מובילים ב{currentMonthName} (נטו)
              </CardTitle>
            </CardHeader>
            <CardContent className="max-h-[500px] overflow-y-auto">
              {topByMonthlyRevenue.length > 0 ? (
                <div className="space-y-2">
                  {topByMonthlyRevenue.map((company: any, idx: number) => (
                    <div 
                      key={company.id} 
                      className="flex flex-col p-2 bg-blue-50 rounded-lg hover:bg-blue-100 transition-colors"
                      data-testid={`row-monthly-${idx}`}
                    >
                      <div className="flex items-center gap-2 mb-1">
                        <Badge variant="outline" className="w-6 h-6 flex-shrink-0 flex items-center justify-center rounded-full text-xs border-blue-300">
                          {idx + 1}
                        </Badge>
                        <p className="font-medium text-sm truncate max-w-[150px]" title={company.companyName}>{company.companyName}</p>
                      </div>
                      <div className="flex items-center justify-end pr-8">
                        <span className="text-sm font-bold text-blue-600">
                          ₪{company.monthlyNetRevenue?.toLocaleString()}
                        </span>
                      </div>
                    </div>
                  ))}
                </div>
              ) : (
                <div className="text-center py-8 text-muted-foreground">
                  <Calendar className="w-12 h-12 mx-auto mb-3 opacity-30" />
                  <p>אין חשבוניות בחודש הנוכחי</p>
                </div>
              )}
            </CardContent>
          </Card>

          {/* Top by Revenue (Year) - Net */}
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <DollarSign className="w-5 h-5 text-green-600" />
                לקוחות מובילים {alerts?.currentYear} $
              </CardTitle>
            </CardHeader>
            <CardContent className="max-h-[500px] overflow-y-auto">
              {topByRevenue.length > 0 ? (
                <div className="space-y-2">
                  {topByRevenue.map((company: any, idx: number) => (
                    <div 
                      key={company.id} 
                      className="flex flex-col p-2 bg-muted/30 rounded-lg hover:bg-muted/50 transition-colors"
                      data-testid={`row-revenue-${idx}`}
                    >
                      <div className="flex items-center gap-2 mb-1">
                        <Badge variant="outline" className="w-6 h-6 flex-shrink-0 flex items-center justify-center rounded-full text-xs">
                          {idx + 1}
                        </Badge>
                        <p className="font-medium text-sm truncate max-w-[180px]" title={company.companyName}>{company.companyName}</p>
                      </div>
                      <div className="flex items-center justify-between pr-8">
                        <span className="text-xs text-muted-foreground">
                          {company.totalOrders} הזמנות
                        </span>
                        <span className="text-sm font-bold text-green-600">
                          ₪{company.totalRevenue?.toLocaleString()}
                        </span>
                      </div>
                    </div>
                  ))}
                </div>
              ) : (
                <div className="text-center py-8 text-muted-foreground">
                  <Building2 className="w-12 h-12 mx-auto mb-3 opacity-30" />
                  <p>אין נתונים זמינים</p>
                </div>
              )}
            </CardContent>
          </Card>

          {/* Top by Orders */}
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <ShoppingCart className="w-5 h-5 text-blue-600" />
                לקוחות מובילים לפי הזמנות
              </CardTitle>
            </CardHeader>
            <CardContent className="max-h-[500px] overflow-y-auto">
              {topByOrders.length > 0 ? (
                <div className="space-y-2">
                  {topByOrders.map((company: any, idx: number) => (
                    <div 
                      key={company.id} 
                      className="flex flex-col p-2 bg-muted/30 rounded-lg hover:bg-muted/50 transition-colors"
                      data-testid={`row-orders-${idx}`}
                    >
                      <div className="flex items-center gap-2 mb-1">
                        <Badge variant="outline" className="w-6 h-6 flex-shrink-0 flex items-center justify-center rounded-full text-xs">
                          {idx + 1}
                        </Badge>
                        <p className="font-medium text-sm truncate max-w-[180px]" title={company.companyName}>{company.companyName}</p>
                      </div>
                      <div className="flex items-center justify-between pr-8">
                        <span className="text-xs text-muted-foreground">
                          ₪{company.totalRevenue?.toLocaleString()}
                        </span>
                        <span className="text-sm font-bold text-blue-600">
                          {company.totalOrders} הזמנות
                        </span>
                      </div>
                    </div>
                  ))}
                </div>
              ) : (
                <div className="text-center py-8 text-muted-foreground">
                  <Building2 className="w-12 h-12 mx-auto mb-3 opacity-30" />
                  <p>אין נתונים זמינים</p>
                </div>
              )}
            </CardContent>
          </Card>

          {/* Top by Expired Devices */}
          <Card className="border-amber-200">
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <AlertTriangle className="w-5 h-5 text-amber-600" />
                מכשירים פגי תוקף לפי לקוח
              </CardTitle>
            </CardHeader>
            <CardContent className="max-h-[500px] overflow-y-auto">
              {topByExpiredDevices.length > 0 ? (
                <div className="space-y-2">
                  {topByExpiredDevices.map((company: any, idx: number) => (
                    <div 
                      key={company.id} 
                      className="flex flex-col p-2 bg-amber-50 rounded-lg hover:bg-amber-100 transition-colors"
                      data-testid={`row-expired-${idx}`}
                    >
                      <div className="flex items-center gap-2 mb-1">
                        <Badge variant="outline" className="w-6 h-6 flex-shrink-0 flex items-center justify-center rounded-full text-xs border-amber-300">
                          {idx + 1}
                        </Badge>
                        <p className="font-medium text-sm truncate max-w-[180px]" title={company.companyName}>{company.companyName}</p>
                      </div>
                      <div className="flex items-center justify-between pr-8">
                        <span className="text-xs text-muted-foreground">
                          {company.totalOrders} הזמנות
                        </span>
                        <Badge variant="destructive" className="flex-shrink-0">
                          {company.expiredDevices} פג תוקף
                        </Badge>
                      </div>
                    </div>
                  ))}
                </div>
              ) : (
                <div className="text-center py-8 text-muted-foreground">
                  <Package className="w-12 h-12 mx-auto mb-3 opacity-30" />
                  <p>אין מכשירים פגי תוקף</p>
                </div>
              )}
            </CardContent>
          </Card>
        </div>
      </motion.div>
    </DashboardLayout>
  );
}
