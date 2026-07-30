import { motion } from "framer-motion";
import DashboardLayout from "@/components/layout/DashboardLayout";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { 
  FileText, 
  Clock,
  CheckCircle2,
  XCircle,
  TrendingUp
} from "lucide-react";

export default function QuotesPage() {
  const stats = [
    { label: "ממתינות", value: 0, icon: Clock, color: "text-amber-500", bg: "bg-amber-500/10" },
    { label: "אושרו", value: 0, icon: CheckCircle2, color: "text-green-500", bg: "bg-green-500/10" },
    { label: "נדחו", value: 0, icon: XCircle, color: "text-destructive", bg: "bg-destructive/10" },
    { label: "סה\"כ החודש", value: 0, icon: TrendingUp, color: "text-primary", bg: "bg-primary/10" },
  ];

  return (
    <DashboardLayout>
      <motion.div 
        className="space-y-6 max-w-7xl mx-auto text-right"
        dir="rtl"
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
      >
        <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
          <div>
            <h1 className="text-3xl font-bold">הצעות מחיר</h1>
            <p className="text-muted-foreground">צפייה במעקב אחר הצעות מחיר</p>
          </div>
        </div>

        <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
          {stats.map((stat) => (
            <Card key={stat.label}>
              <CardContent className="pt-6">
                <div className="flex items-center gap-4">
                  <div className={`w-12 h-12 rounded-full ${stat.bg} flex items-center justify-center`}>
                    <stat.icon className={`w-6 h-6 ${stat.color}`} />
                  </div>
                  <div>
                    <p className="text-2xl font-bold">{stat.value}</p>
                    <p className="text-sm text-muted-foreground">{stat.label}</p>
                  </div>
                </div>
              </CardContent>
            </Card>
          ))}
        </div>

        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <FileText className="w-5 h-5" />
              הצעות אחרונות
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="flex flex-col items-center justify-center py-12 text-muted-foreground">
              <FileText className="w-16 h-16 mb-4 opacity-30" />
              <p className="text-lg font-medium">אין הצעות מחיר</p>
              <p className="text-sm">נתוני הצעות מחיר יופיעו כאן לאחר סנכרון מבסיס הנתונים</p>
            </div>
          </CardContent>
        </Card>
      </motion.div>
    </DashboardLayout>
  );
}
