import { sql } from "drizzle-orm";
import { pgTable, text, varchar, jsonb, timestamp, real } from "drizzle-orm/pg-core";
import { createInsertSchema } from "drizzle-zod";
import { z } from "zod";

export const users = pgTable("users", {
  id: varchar("id").primaryKey().default(sql`gen_random_uuid()`),
  username: text("username").notNull().unique(),
  password: text("password").notNull(),
});

export const insertUserSchema = createInsertSchema(users).pick({
  username: true,
  password: true,
});

export type InsertUser = z.infer<typeof insertUserSchema>;
export type User = typeof users.$inferSelect;

// Synced customers from local SQL Server
export const syncedCustomers = pgTable("synced_customers", {
  id: varchar("id").primaryKey(),
  hp: varchar("hp"),
  companyName: text("company_name").notNull(),
  data: jsonb("data").notNull(),
  syncedAt: timestamp("synced_at").defaultNow().notNull(),
});

export const insertSyncedCustomerSchema = createInsertSchema(syncedCustomers);
export type InsertSyncedCustomer = z.infer<typeof insertSyncedCustomerSchema>;
export type SyncedCustomer = typeof syncedCustomers.$inferSelect;

// App settings for scoring configuration
export const appSettings = pgTable("app_settings", {
  key: varchar("key").primaryKey(),
  value: jsonb("value").notNull(),
  updatedAt: timestamp("updated_at").defaultNow().notNull(),
});

export const insertAppSettingsSchema = createInsertSchema(appSettings);
export type InsertAppSettings = z.infer<typeof insertAppSettingsSchema>;
export type AppSettings = typeof appSettings.$inferSelect;

// Default scoring configuration
export const defaultScoringConfig = {
  weights: {
    tenure: 25,
    revenue: 40,
    frequency: 35
  },
  thresholds: {
    A: 85,
    B: 70,
    C: 55,
    D: 40
  },
  maxValues: {
    tenureMonths: 60,
    revenueAmount: 500000
  }
};

export type ScoringConfig = typeof defaultScoringConfig;

// Company days off for target calculations
export const companyDaysOff = pgTable("company_days_off", {
  id: varchar("id").primaryKey().default(sql`gen_random_uuid()`),
  date: varchar("date").notNull(),
  reason: text("reason").notNull(),
  createdAt: timestamp("created_at").defaultNow().notNull(),
});

export const insertCompanyDayOffSchema = createInsertSchema(companyDaysOff).pick({
  date: true,
  reason: true,
});
export type InsertCompanyDayOff = z.infer<typeof insertCompanyDayOffSchema>;
export type CompanyDayOff = typeof companyDaysOff.$inferSelect;

// UPS Expenses tracking
export const upsExpenses = pgTable("ups_expenses", {
  id: varchar("id").primaryKey().default(sql`gen_random_uuid()`),
  iv: varchar("iv").notNull(),
  ivnum: varchar("ivnum"),
  doc: varchar("doc"),
  ivdate: varchar("ivdate"),
  cust: varchar("cust"),
  customerName: text("customer_name"),
  currency: varchar("currency"),
  amount: real("amount"),
  vatPrice: real("vat_price"),
  source: varchar("source").notNull(),
  part: varchar("part"),
  data: jsonb("data"),
  syncedAt: timestamp("synced_at").defaultNow().notNull(),
});

export const insertUpsExpenseSchema = createInsertSchema(upsExpenses).omit({ 
  id: true, 
  syncedAt: true 
});
export type InsertUpsExpense = z.infer<typeof insertUpsExpenseSchema>;
export type UpsExpense = typeof upsExpenses.$inferSelect;

// Department performance stats (synced from SQL Server)
export const departmentStats = pgTable("department_stats", {
  id: varchar("id").primaryKey(),
  deptCode: varchar("dept_code").notNull(),
  deptName: text("dept_name"),
  year: varchar("year").notNull(),
  agentCode: varchar("agent_code"),
  agentName: text("agent_name"),
  customerCount: real("customer_count").default(0),
  callCount: real("call_count").default(0),
  revenue: real("revenue").default(0),
  syncedAt: timestamp("synced_at").defaultNow().notNull(),
});

export const insertDepartmentStatSchema = createInsertSchema(departmentStats).omit({ syncedAt: true });
export type InsertDepartmentStat = z.infer<typeof insertDepartmentStatSchema>;
export type DepartmentStat = typeof departmentStats.$inferSelect;

export const shipShipments = pgTable("ship_shipments", {
  id: varchar("id").primaryKey(),
  shipmentId: varchar("shipment_id"),
  trackingNumber: varchar("tracking_number"),
  shipDate: varchar("ship_date"),
  customerRef: varchar("customer_ref"),
  recipientName: text("recipient_name"),
  recipientCity: text("recipient_city"),
  weight: real("weight"),
  cost: real("cost"),
  currency: varchar("currency"),
  status: varchar("status"),
  serviceType: varchar("service_type"),
  data: jsonb("data"),
  syncedAt: timestamp("synced_at").defaultNow().notNull(),
});

export const insertShipShipmentSchema = createInsertSchema(shipShipments).omit({
  syncedAt: true
});
export type InsertShipShipment = z.infer<typeof insertShipShipmentSchema>;
export type ShipShipment = typeof shipShipments.$inferSelect;

// Monthly company-wide service call counts (from Priority ERP DOCUMENTS_Q)
export const monthlyCallStats = pgTable("monthly_call_stats", {
  yearMonth: varchar("year_month").primaryKey(), // 'YYYY-MM'
  callCount: real("call_count").default(0),
  syncedAt: timestamp("synced_at").defaultNow().notNull(),
});

export const insertMonthlyCallStatSchema = createInsertSchema(monthlyCallStats).omit({ syncedAt: true });
export type InsertMonthlyCallStat = z.infer<typeof insertMonthlyCallStatSchema>;
export type MonthlyCallStat = typeof monthlyCallStats.$inferSelect;

// Calibrator department stats — revenue + calls grouped by ORDERS.DOER (who performed the work)
export const calibratorDeptStats = pgTable("calibrator_dept_stats", {
  id: varchar("id").primaryKey(),          // "{doer}__{deptCode}__{year}"
  doerId: varchar("doer_id").notNull(),    // ORDERS.DOER (= tblUsers.ID)
  deptCode: varchar("dept_code").notNull(),
  deptName: text("dept_name"),
  year: varchar("year").notNull(),
  customerCount: real("customer_count").default(0),
  callCount: real("call_count").default(0),
  revenue: real("revenue").default(0),
  syncedAt: timestamp("synced_at").defaultNow().notNull(),
});
export const insertCalibratorDeptStatSchema = createInsertSchema(calibratorDeptStats).omit({ syncedAt: true });
export type InsertCalibratorDeptStat = z.infer<typeof insertCalibratorDeptStatSchema>;
export type CalibratorDeptStat = typeof calibratorDeptStats.$inferSelect;

// Calibrators — ORDERS.DOER → AGENTS mapping from Priority ERP
export const calibrators = pgTable("calibrators", {
  userId: varchar("user_id").primaryKey(),
  fullName: text("full_name"),
  agentCode: varchar("agent_code"),
  calibrationCount: real("calibration_count").default(0),
  syncedAt: timestamp("synced_at").defaultNow().notNull(),
});

export const insertCalibratorSchema = createInsertSchema(calibrators).omit({ syncedAt: true });
export type InsertCalibrator = z.infer<typeof insertCalibratorSchema>;
export type Calibrator = typeof calibrators.$inferSelect;

// Company-wide return documents (TYPE='N') — global sync, all customers
export const companyReturnDocuments = pgTable("company_return_documents", {
  id: varchar("id").primaryKey().default(sql`gen_random_uuid()`),
  docNumber: varchar("doc_number"),
  customerName: text("customer_name"),
  customerId: varchar("customer_id"),
  openDate: varchar("open_date"),
  value: real("value").default(0),
  status: varchar("status"),
  month: varchar("month"),
  syncedAt: timestamp("synced_at").defaultNow().notNull(),
});

export const insertCompanyReturnDocumentSchema = createInsertSchema(companyReturnDocuments).omit({ syncedAt: true });
export type InsertCompanyReturnDocument = z.infer<typeof insertCompanyReturnDocumentSchema>;
export type CompanyReturnDocument = typeof companyReturnDocuments.$inferSelect;

// Company-wide calibration alerts — global sync, all customers, no [:10] limit
export const companyCalibrationAlerts = pgTable("company_calibration_alerts", {
  id: varchar("id").primaryKey().default(sql`gen_random_uuid()`),
  customerId: varchar("customer_id"),
  customerName: text("customer_name"),
  serialNo: varchar("serial_no"),
  deviceName: text("device_name"),
  nextCalDate: varchar("next_cal_date"),
  lastCalDate: varchar("last_cal_date"),
  type: varchar("type"),
  location: varchar("location"),
  syncId: varchar("sync_id"),
  syncedAt: timestamp("synced_at").defaultNow().notNull(),
});

export const insertCompanyCalibrationAlertSchema = createInsertSchema(companyCalibrationAlerts).omit({ syncedAt: true });
export type InsertCompanyCalibrationAlert = z.infer<typeof insertCompanyCalibrationAlertSchema>;
export type CompanyCalibrationAlert = typeof companyCalibrationAlerts.$inferSelect;

// Operational query rows — synced from local Python script
export const operationalQueryRows = pgTable("operational_query_rows", {
  id: varchar("id").primaryKey().default(sql`gen_random_uuid()`),
  docNo: varchar("doc_no"),
  docDate: varchar("doc_date"),
  custName: varchar("cust_name"),
  syncId: varchar("sync_id"),
  data: jsonb("data").notNull(),
  syncedAt: timestamp("synced_at").defaultNow().notNull(),
});

export const insertOperationalQueryRowSchema = createInsertSchema(operationalQueryRows).omit({ syncedAt: true });
export type InsertOperationalQueryRow = z.infer<typeof insertOperationalQueryRowSchema>;
export type OperationalQueryRow = typeof operationalQueryRows.$inferSelect;

// Financial query rows — synced from local Python script
export const financialQueryRows = pgTable("financial_query_rows", {
  id: varchar("id").primaryKey().default(sql`gen_random_uuid()`),
  ivNum: varchar("iv_num"),
  ivDate: varchar("iv_date"),
  custName: varchar("cust_name"),
  syncId: varchar("sync_id"),
  data: jsonb("data").notNull(),
  syncedAt: timestamp("synced_at").defaultNow().notNull(),
});

export const insertFinancialQueryRowSchema = createInsertSchema(financialQueryRows).omit({ syncedAt: true });
export type InsertFinancialQueryRow = z.infer<typeof insertFinancialQueryRowSchema>;
export type FinancialQueryRow = typeof financialQueryRows.$inferSelect;
