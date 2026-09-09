import { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { Link } from "wouter";
import { motion } from "framer-motion";
import DashboardLayout from "@/components/layout/DashboardLayout";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { BilingualText } from "@/components/BilingualText";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { 
  Search, 
  Building2, 
  Package, 
  AlertTriangle,
  ChevronLeft,
  Loader2,
  Download,
  Star,
  Users,
  Clock
} from "lucide-react";
import { Tooltip, TooltipContent, TooltipTrigger } from "@/components/ui/tooltip";
import { cn } from "@/lib/utils";

export default function CustomersPage() {
  const [searchTerm, setSearchTerm] = useState("");
  const [selectedYear, setSelectedYear] = useState<number>(new Date().getFullYear());
  const [selectedAgent, setSelectedAgent] = useState<string>('all');

  const { data: customersData, isLoading } = useQuery({
    queryKey: ['customers-list'],
    queryFn: async () => {
      const res = await fetch('/api/customers/list');
      return res.json();
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

  const allCustomers = customersData?.customers || [];
  const uniqueAgents = agentsData?.agents || [];

  const hasRevenueInYear = (customer: any, year: number): boolean => {
    if (customer.financials) {
      return customer.financials.some((f: any) => f.year === year && f.revenue > 0);
    }
    if (customer.monthlyRevenue) {
      return customer.monthlyRevenue.some((m: any) => {
        const [y] = (m.month || '').split('-');
        return parseInt(y) === year && m.revenue > 0;
      });
    }
    return false;
  };

  const getCustomerYearRevenue = (customer: any, year: number): number => {
    if (customer.financials) {
      const yearData = customer.financials.find((f: any) => f.year === year);
      return yearData?.revenue || 0;
    }
    if (customer.monthlyRevenue) {
      return customer.monthlyRevenue
        .filter((m: any) => {
          const [y] = (m.month || '').split('-');
          return parseInt(y) === year;
        })
        .reduce((sum: number, m: any) => sum + (m.revenue || 0), 0);
    }
    return 0;
  };

  const isStale = (syncedAt: string | null | undefined): boolean => {
    if (!syncedAt) return true;
    const age = Date.now() - new Date(syncedAt).getTime();
    return age > 24 * 60 * 60 * 1000;
  };

  const formatSyncedAt = (syncedAt: string | null | undefined): string => {
    if (!syncedAt) return 'לא ידוע';
    return new Date(syncedAt).toLocaleString('he-IL', { dateStyle: 'short', timeStyle: 'short' });
  };

  const searchMatchesCustomer = (customer: any, term: string): boolean => {
    if (!term) return false;
    const lowerTerm = term.toLowerCase();
    return (
      customer.companyName?.toLowerCase().includes(lowerTerm) ||
      customer.id?.toString().includes(term) ||
      customer.hp?.toString().includes(term)
    );
  };

  const customersFilteredByYear = searchTerm.length >= 2
    ? allCustomers
    : allCustomers.filter((c: any) => hasRevenueInYear(c, selectedYear));
  
  const customersFilteredByAgent = selectedAgent === 'all' 
    ? customersFilteredByYear 
    : customersFilteredByYear.filter((c: any) => c.agentName === selectedAgent);
  
  const customers = customersFilteredByAgent
    .sort((a: any, b: any) => getCustomerYearRevenue(b, selectedYear) - getCustomerYearRevenue(a, selectedYear));

  const filteredCustomers = searchTerm
    ? customers.filter((customer: any) => searchMatchesCustomer(customer, searchTerm))
    : customers;

  if (isLoading) {
    return (
      <DashboardLayout>
        <div className="flex flex-col items-center justify-center h-[80vh] gap-4">
          <Loader2 className="h-10 w-10 animate-spin text-primary" />
          <p className="text-muted-foreground">טוען רשימת לקוחות...</p>
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
            <h1 className="text-3xl font-bold flex items-center gap-2">
              <Users className="w-8 h-8 text-primary" />
              לקוחות פעילים {selectedYear}
            </h1>
            <p className="text-muted-foreground">{customers.length} לקוחות עם פעילות בשנה זו (מתוך {allCustomers.length} במערכת)</p>
          </div>
          <div className="flex items-center gap-3 flex-row-reverse">
            <Select value={selectedYear.toString()} onValueChange={(v) => setSelectedYear(parseInt(v))}>
              <SelectTrigger className="w-32" data-testid="select-year">
                <SelectValue placeholder="שנה" />
              </SelectTrigger>
              <SelectContent>
                {[2024, 2025, 2026].map(year => (
                  <SelectItem key={year} value={year.toString()}>{year}</SelectItem>
                ))}
              </SelectContent>
            </Select>
            <Select value={selectedAgent} onValueChange={setSelectedAgent}>
              <SelectTrigger className="w-40" data-testid="select-agent">
                <SelectValue placeholder="סוכן" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="all">כל הסוכנים</SelectItem>
                {uniqueAgents.map(agent => (
                  <SelectItem key={agent} value={agent}>{agent}</SelectItem>
                ))}
              </SelectContent>
            </Select>
            <Button
              variant="outline"
              onClick={() => window.location.href = '/api/export/customers.xlsx'}
              data-testid="button-export-customers"
              className="gap-2"
            >
              <Download className="w-4 h-4" />
              ייצוא לאקסל
            </Button>
            <div className="relative w-full md:w-80">
              <Search className="absolute right-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-muted-foreground" />
              <Input
                placeholder="חיפוש לפי שם או מספר לקוח..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                className="pr-10"
                data-testid="input-search-customers"
              />
            </div>
          </div>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {filteredCustomers.map((customer: any) => (
            <Link key={customer.id} href={`/dashboard?customer=${customer.id}`}>
              <Card 
                className="hover:shadow-lg transition-all cursor-pointer border-r-4 border-r-primary/30 hover:border-r-primary"
                data-testid={`card-customer-${customer.id}`}
              >
                <CardHeader className="pb-2">
                  <div className="flex items-start justify-between">
                    <div className="flex items-center gap-2">
                      <div className="w-10 h-10 rounded-full bg-primary/10 flex items-center justify-center">
                        <Building2 className="w-5 h-5 text-primary" />
                      </div>
                      <div>
                        <CardTitle className="text-base"><BilingualText text={customer.companyName} /></CardTitle>
                        <p className="text-xs text-muted-foreground font-mono">מספר לקוח: {customer.hp || customer.id}</p>
                        {customer.agentName && (
                          <p className="text-xs text-muted-foreground">סוכן: {customer.agentName}</p>
                        )}
                      </div>
                    </div>
                    <ChevronLeft className="w-5 h-5 text-muted-foreground" />
                  </div>
                </CardHeader>
                <CardContent>
                  <div className="space-y-2">
                    <div className="flex items-center justify-between text-sm">
                      <span className="text-muted-foreground">הכנסות {selectedYear}:</span>
                      <span className="font-bold text-emerald-600">₪{getCustomerYearRevenue(customer, selectedYear).toLocaleString(undefined, { maximumFractionDigits: 0 })}</span>
                    </div>
                    <div className="flex items-center justify-between text-sm">
                      <div className="flex items-center gap-2">
                        <Package className="w-4 h-4 text-muted-foreground" />
                        <span>{customer.deviceInventory?.totalDevices || 0} מכשירים</span>
                      </div>
                      <div className="flex items-center gap-2">
                        {isStale(customer.syncedAt) && (
                          <Tooltip>
                            <TooltipTrigger asChild>
                              <Badge
                                variant="outline"
                                className="gap-1 border-yellow-500 text-yellow-700 bg-yellow-50 cursor-default"
                                data-testid={`badge-stale-${customer.id}`}
                                onClick={(e) => e.preventDefault()}
                              >
                                <Clock className="w-3 h-3" />
                                נתונים ישנים
                              </Badge>
                            </TooltipTrigger>
                            <TooltipContent side="top">
                              סונכרן לאחרונה: {formatSyncedAt(customer.syncedAt)}
                            </TooltipContent>
                          </Tooltip>
                        )}
                        {customer.customerScore?.grade && (
                          <Badge 
                            variant="outline"
                            className={cn(
                              "gap-1 font-bold",
                              customer.customerScore.grade === 'A' ? "border-emerald-500 text-emerald-600 bg-emerald-50" :
                              customer.customerScore.grade === 'B' ? "border-blue-500 text-blue-600 bg-blue-50" :
                              customer.customerScore.grade === 'C' ? "border-amber-500 text-amber-600 bg-amber-50" :
                              customer.customerScore.grade === 'D' ? "border-orange-500 text-orange-600 bg-orange-50" : 
                              "border-red-500 text-red-600 bg-red-50"
                            )}
                          >
                            <Star className="w-3 h-3" />
                            {customer.customerScore.grade}
                          </Badge>
                        )}
                        {customer.alerts?.length > 0 && (
                          <Badge variant="destructive" className="gap-1">
                            <AlertTriangle className="w-3 h-3" />
                            {customer.alerts.length}
                          </Badge>
                        )}
                      </div>
                    </div>
                  </div>
                </CardContent>
              </Card>
            </Link>
          ))}
        </div>

        {filteredCustomers.length === 0 && (
          <div className="text-center py-12 text-muted-foreground">
            <Building2 className="w-12 h-12 mx-auto mb-4 opacity-50" />
            <p>לא נמצאו לקוחות</p>
          </div>
        )}
      </motion.div>
    </DashboardLayout>
  );
}
