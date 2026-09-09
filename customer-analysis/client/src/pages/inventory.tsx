import { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { motion } from "framer-motion";
import DashboardLayout from "@/components/layout/DashboardLayout";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Badge } from "@/components/ui/badge";
import { 
  Search, 
  Package,
  AlertTriangle,
  CheckCircle2,
  Clock,
  Loader2,
  Wrench
} from "lucide-react";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";

export default function InventoryPage() {
  const [searchTerm, setSearchTerm] = useState("");

  const { data: customersData, isLoading } = useQuery({
    queryKey: ['customers-list'],
    queryFn: async () => {
      const res = await fetch('/api/customers/list');
      return res.json();
    }
  });

  const customers = customersData?.customers || [];

  const allDevices = customers.flatMap((customer: any) => {
    const alerts = customer.alerts || [];
    return alerts.map((alert: any) => ({
      customerName: customer.companyName,
      customerId: customer.id,
      deviceName: alert.title?.replace(' - כיול באיחור', '') || 'לא ידוע',
      serialNo: alert.message?.match(/ס"נ: ([^,]+)/)?.[1] || '',
      nextCalDate: alert.message?.match(/תאריך כיול הבא: ([^}]+)/)?.[1] || '',
      status: 'overdue'
    }));
  });

  const filteredDevices = allDevices.filter((device: any) =>
    device.deviceName?.toLowerCase().includes(searchTerm.toLowerCase()) ||
    device.customerName?.toLowerCase().includes(searchTerm.toLowerCase()) ||
    device.serialNo?.includes(searchTerm)
  );

  const stats = {
    total: customers.reduce((acc: number, c: any) => acc + (c.deviceInventory?.totalDevices || 0), 0),
    active: customers.reduce((acc: number, c: any) => acc + (c.deviceInventory?.activeDevices || 0), 0),
    overdue: allDevices.length
  };

  if (isLoading) {
    return (
      <DashboardLayout>
        <div className="flex flex-col items-center justify-center h-[80vh] gap-4">
          <Loader2 className="h-10 w-10 animate-spin text-primary" />
          <p className="text-muted-foreground">טוען מלאי מכשירים...</p>
        </div>
      </DashboardLayout>
    );
  }

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
            <h1 className="text-3xl font-bold">מלאי מכשירים</h1>
            <p className="text-muted-foreground">ניהול ומעקב אחר כל המכשירים במערכת</p>
          </div>
          <div className="relative w-full md:w-80">
            <Search className="absolute right-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-muted-foreground" />
            <Input
              placeholder="חיפוש מכשיר, לקוח או מס' סידורי..."
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              className="pr-10"
              data-testid="input-search-inventory"
            />
          </div>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          <Card>
            <CardContent className="pt-6">
              <div className="flex items-center gap-4">
                <div className="w-12 h-12 rounded-full bg-primary/10 flex items-center justify-center">
                  <Package className="w-6 h-6 text-primary" />
                </div>
                <div>
                  <p className="text-2xl font-bold">{stats.total.toLocaleString()}</p>
                  <p className="text-sm text-muted-foreground">סה"כ מכשירים</p>
                </div>
              </div>
            </CardContent>
          </Card>
          <Card>
            <CardContent className="pt-6">
              <div className="flex items-center gap-4">
                <div className="w-12 h-12 rounded-full bg-green-500/10 flex items-center justify-center">
                  <CheckCircle2 className="w-6 h-6 text-green-500" />
                </div>
                <div>
                  <p className="text-2xl font-bold">{stats.active.toLocaleString()}</p>
                  <p className="text-sm text-muted-foreground">בתוקף</p>
                </div>
              </div>
            </CardContent>
          </Card>
          <Card>
            <CardContent className="pt-6">
              <div className="flex items-center gap-4">
                <div className="w-12 h-12 rounded-full bg-destructive/10 flex items-center justify-center">
                  <AlertTriangle className="w-6 h-6 text-destructive" />
                </div>
                <div>
                  <p className="text-2xl font-bold">{stats.overdue.toLocaleString()}</p>
                  <p className="text-sm text-muted-foreground">דורשים כיול</p>
                </div>
              </div>
            </CardContent>
          </Card>
        </div>

        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <Wrench className="w-5 h-5" />
              מכשירים הדורשים כיול
            </CardTitle>
          </CardHeader>
          <CardContent>
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead className="text-right">מכשיר</TableHead>
                  <TableHead className="text-right">מס' סידורי</TableHead>
                  <TableHead className="text-right">לקוח</TableHead>
                  <TableHead className="text-right">תאריך כיול</TableHead>
                  <TableHead className="text-right">סטטוס</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {filteredDevices.slice(0, 50).map((device: any, idx: number) => (
                  <TableRow key={idx} data-testid={`row-device-${idx}`}>
                    <TableCell className="font-medium">{device.deviceName}</TableCell>
                    <TableCell className="font-mono text-sm">{device.serialNo}</TableCell>
                    <TableCell>{device.customerName}</TableCell>
                    <TableCell>{device.nextCalDate}</TableCell>
                    <TableCell>
                      <Badge variant="destructive" className="gap-1">
                        <Clock className="w-3 h-3" />
                        באיחור
                      </Badge>
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
            {filteredDevices.length > 50 && (
              <p className="text-center text-sm text-muted-foreground mt-4">
                מציג 50 מתוך {filteredDevices.length} מכשירים
              </p>
            )}
          </CardContent>
        </Card>
      </motion.div>
    </DashboardLayout>
  );
}
