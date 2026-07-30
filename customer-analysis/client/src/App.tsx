import { Switch, Route } from "wouter";
import { queryClient } from "./lib/queryClient";
import { QueryClientProvider } from "@tanstack/react-query";
import { Toaster } from "@/components/ui/toaster";
import { TooltipProvider } from "@/components/ui/tooltip";
import NotFound from "@/pages/not-found";
import Dashboard from "@/pages/dashboard";
import CustomersPage from "@/pages/customers";
import InventoryPage from "@/pages/inventory";
import QuotesPage from "@/pages/quotes";
import CalendarPage from "@/pages/calendar";
import SettingsPage from "@/pages/settings";
import CompanySummary from "@/pages/company-summary";
import CompanyTargets from "@/pages/company-targets";
import ExpensesPage from "@/pages/expenses";
import DepartmentsPage from "@/pages/departments";
import KelitotPage from "@/pages/kelitot";
import OperationalQueryPage from "@/pages/operational-query";
import FinancialQueryPage from "@/pages/financial-query";

function Router() {
  return (
    <Switch>
      <Route path="/" component={CompanySummary} />
      <Route path="/dashboard" component={Dashboard} />
      <Route path="/dashboard/:id" component={Dashboard} />
      <Route path="/customers" component={CustomersPage} />
      <Route path="/inventory" component={InventoryPage} />
      <Route path="/quotes" component={QuotesPage} />
      <Route path="/calendar" component={CalendarPage} />
      <Route path="/settings" component={SettingsPage} />
      <Route path="/summary" component={CompanySummary} />
      <Route path="/targets" component={CompanyTargets} />
      <Route path="/expenses" component={ExpensesPage} />
      <Route path="/logistics" component={ExpensesPage} />
      <Route path="/departments" component={DepartmentsPage} />
      <Route path="/kelitot" component={KelitotPage} />
      <Route path="/operational-query" component={OperationalQueryPage} />
      <Route path="/financial-query" component={FinancialQueryPage} />
      <Route component={NotFound} />
    </Switch>
  );
}

function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <TooltipProvider>
        <Toaster />
        <Router />
      </TooltipProvider>
    </QueryClientProvider>
  );
}

export default App;
