import React from 'react';
import { useLocation, Link } from "wouter";
import { cn } from "@/lib/utils";
import { useQuery } from "@tanstack/react-query";
import { 
  Users, 
  Settings, 
  LogOut, 
  Bell,
  Menu,
  RefreshCw,
  CheckCircle2,
  Database,
  BarChart3,
  Building2,
  Calendar,
  Box,
  FileText,
  Target,
  Truck,
  Layers,
  Loader2,
  LayoutDashboard
} from "lucide-react";
import { Button } from "@/components/ui/button";
import { Sheet, SheetContent, SheetTrigger } from "@/components/ui/sheet";
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import { Badge } from "@/components/ui/badge";
import { Tooltip, TooltipContent, TooltipProvider, TooltipTrigger } from "@/components/ui/tooltip";

interface SidebarProps extends React.HTMLAttributes<HTMLDivElement> {
  isSyncActive?: boolean;
  syncStatus?: string;
  lastSync?: string | null;
}

function useTimeAgo(timestamp: string | null | undefined): string | null {
  const [label, setLabel] = React.useState<string | null>(null);

  React.useEffect(() => {
    if (!timestamp) { setLabel(null); return; }

    function compute() {
      const diffMs = Date.now() - new Date(timestamp!).getTime();
      const diffSec = Math.floor(diffMs / 1000);
      if (diffSec < 60) {
        setLabel('עודכן זה עתה');
      } else if (diffSec < 3600) {
        const mins = Math.floor(diffSec / 60);
        setLabel(`עודכן לפני ${mins} ${mins === 1 ? 'דקה' : 'דקות'}`);
      } else if (diffSec < 86400) {
        const hrs = Math.floor(diffSec / 3600);
        setLabel(`עודכן לפני ${hrs} ${hrs === 1 ? 'שעה' : 'שעות'}`);
      } else {
        const days = Math.floor(diffSec / 86400);
        setLabel(`עודכן לפני ${days} ${days === 1 ? 'יום' : 'ימים'}`);
      }
    }

    compute();
    const interval = setInterval(compute, 30000);
    return () => clearInterval(interval);
  }, [timestamp]);

  return label;
}

export function Sidebar({ className, isSyncActive, syncStatus, lastSync }: SidebarProps) {
  const [location] = useLocation();
  const timeAgo = useTimeAgo(lastSync);

  const menuSections = [
    {
      title: "מכירות ושירות",
      icon: BarChart3,
      items: [
        { icon: BarChart3, label: "ניתוח פעילות", href: "/summary" },
        { icon: Users, label: "לקוחות", href: "/customers" },
        { icon: Target, label: "יעדים", href: "/targets" },
      ]
    },
    {
      title: "תפעול",
      icon: Building2,
      items: [
        {
          icon: Layers, label: "ביצוע מחלקות", href: "/departments",
          subItems: [
            { icon: FileText, label: "שאילתא תפעולית", href: "/operational-query" },
            { icon: FileText, label: "שאילתא כספית", href: "/financial-query" },
          ]
        },
        { icon: Truck, label: "לוגיסטיקה", href: "/logistics" },
        { icon: LayoutDashboard, label: "דשבורד קליטות", href: "/kelitot" },
      ]
    },
    {
      title: "הגדרות",
      icon: Settings,
      items: [
        { icon: Settings, label: "הגדרות מערכת", href: "/settings" },
      ]
    }
  ];

  const isActive = (href: string) => {
    if (href === "/summary") return location === "/" || location.startsWith("/summary");
    return location.startsWith(href);
  };

  return (
    <div className={cn("pb-12 min-h-screen bg-sidebar text-sidebar-foreground border-l border-sidebar-border", className)}>
      <div className="space-y-4 py-4">
        <div className="px-6 py-2">
          <h2 className="text-2xl font-bold tracking-tight text-sidebar-primary-foreground flex items-center gap-2">
            <span className="bg-primary text-primary-foreground p-1 rounded-md text-sm">QCC</span>
            Analytics
          </h2>
          {timeAgo && !isSyncActive && (
            <p
              data-testid="sidebar-last-sync-label"
              className="text-xs text-sidebar-foreground/50 mt-0.5"
            >
              {timeAgo}
            </p>
          )}
        </div>

        {isSyncActive && (
          <div
            data-testid="sidebar-sync-indicator"
            className="mx-3 mb-1 px-3 py-2 rounded-lg border border-blue-200 bg-blue-50 dark:bg-blue-950/30 dark:border-blue-800 flex items-center gap-2"
          >
            <Loader2 className="h-3.5 w-3.5 animate-spin text-blue-600 dark:text-blue-400 flex-shrink-0" />
            <span className="text-xs font-medium text-blue-800 dark:text-blue-300 leading-tight">
              {syncStatus === 'requested' ? 'ממתין לסנכרון...' : 'מסנכרן נתונים...'}
            </span>
          </div>
        )}
        <div className="px-3 py-2">
          <div className="space-y-6">
            {menuSections.map((section) => (
              <div key={section.title} className="space-y-1">
                <div className="flex items-center gap-2 px-3 py-1.5 text-xs font-semibold text-sidebar-foreground/50 uppercase tracking-wider">
                  <section.icon className="h-3.5 w-3.5" />
                  {section.title}
                </div>
                {section.items.map((item) => (
                  <div key={item.href}>
                    <Link href={item.href}>
                      <div
                        data-testid={`nav-${item.href.replace(/\//g, '-').slice(1) || 'home'}`}
                        className={cn(
                          "flex items-center w-full justify-start gap-3 px-3 py-2 rounded-md text-sm transition-colors cursor-pointer mr-2",
                          isActive(item.href)
                            ? "bg-sidebar-accent text-sidebar-accent-foreground font-medium shadow-sm" 
                            : "text-sidebar-foreground/70 hover:text-sidebar-foreground hover:bg-sidebar-accent/50"
                        )}
                      >
                        <item.icon className="h-4 w-4" />
                        {item.label}
                      </div>
                    </Link>
                    {'subItems' in item && item.subItems && (
                      <div className="mr-5 border-r border-sidebar-foreground/15 pr-1 space-y-0.5 mt-0.5">
                        {(item.subItems as { icon: any; label: string; href: string }[]).map((sub) => (
                          <Link key={sub.href} href={sub.href}>
                            <div
                              data-testid={`nav-${sub.href.replace(/\//g, '-').slice(1)}`}
                              className={cn(
                                "flex items-center w-full justify-start gap-2 px-2 py-1.5 rounded-md text-xs transition-colors cursor-pointer",
                                isActive(sub.href)
                                  ? "bg-sidebar-accent text-sidebar-accent-foreground font-medium"
                                  : "text-sidebar-foreground/55 hover:text-sidebar-foreground hover:bg-sidebar-accent/40"
                              )}
                            >
                              <sub.icon className="h-3.5 w-3.5 shrink-0" />
                              {sub.label}
                            </div>
                          </Link>
                        ))}
                      </div>
                    )}
                  </div>
                ))}
              </div>
            ))}
          </div>
        </div>
      </div>
      <div className="absolute bottom-4 px-6 w-full">
         <Button variant="ghost" className="w-full justify-start gap-3 text-destructive hover:text-destructive hover:bg-destructive/10">
            <LogOut className="h-4 w-4" />
            התנתק
         </Button>
      </div>
    </div>
  );
}

export default function DashboardLayout({ children }: { children: React.ReactNode }) {
  const { data: globalSyncStatus } = useQuery({
    queryKey: ['/api/company/global-sync-status'],
    queryFn: async () => {
      const res = await fetch('/api/company/global-sync-status');
      if (!res.ok) return { lastSync: null, syncState: { status: 'idle' } };
      return res.json();
    },
    refetchInterval: (data) => {
      const st = (data as any)?.state?.data?.syncState?.status;
      if (st === 'requested' || st === 'running') return 3000;
      return 5000;
    }
  });

  const syncStateStatus = globalSyncStatus?.syncState?.status;
  const isSyncActive = syncStateStatus === 'requested' || syncStateStatus === 'running';

  return (
    <div className="flex min-h-screen bg-background text-foreground" dir="rtl">
      {/* Desktop Sidebar */}
      <div className="hidden md:flex w-64 flex-shrink-0 z-30">
        <Sidebar className="fixed w-64 right-0 h-full" isSyncActive={isSyncActive} syncStatus={syncStateStatus} lastSync={globalSyncStatus?.lastSync} />
      </div>

      <div className="flex-1 flex flex-col min-w-0">
        <header className="sticky top-0 z-20 flex h-16 items-center gap-4 border-b bg-background/95 backdrop-blur px-6 shadow-sm" dir="rtl">
          {/* User info — right side (RTL start) */}
          <div className="flex items-center gap-2">
             <Button variant="ghost" size="icon" className="relative text-muted-foreground hover:text-primary">
                <Bell className="h-5 w-5" />
                <span className="absolute top-2 right-2 h-2 w-2 rounded-full bg-destructive border-2 border-background"></span>
             </Button>
             <div className="h-8 w-[1px] bg-border mx-2"></div>
             <div className="flex items-center gap-3">
                <div className="text-right hidden sm:block">
                    <p className="text-sm font-medium leading-none">משתמש</p>
                    <p className="text-xs text-muted-foreground">QCC Analytics</p>
                </div>
                <Avatar className="h-9 w-9 border-2 border-background ring-2 ring-border">
                  <AvatarImage src="/avatars/01.png" alt="@user" />
                  <AvatarFallback className="bg-primary/10 text-primary">QCC</AvatarFallback>
                </Avatar>
             </div>
          </div>

          {/* Spacer */}
          <div className="flex-1" />

          {/* Mobile hamburger — left side (RTL end) */}
          <Sheet>
            <SheetTrigger asChild>
              <Button variant="ghost" size="icon" className="md:hidden shrink-0">
                <Menu className="h-5 w-5" />
                <span className="sr-only">תפריט</span>
              </Button>
            </SheetTrigger>
            <SheetContent side="right" className="p-0 w-64 border-l">
              <Sidebar isSyncActive={isSyncActive} syncStatus={syncStateStatus} lastSync={globalSyncStatus?.lastSync} />
            </SheetContent>
          </Sheet>
        </header>

        <main className="flex-1 p-6 md:p-8 pt-6 overflow-x-hidden" dir="rtl">
          {children}
        </main>
      </div>
    </div>
  );
}
