import { getPool, sql } from '../db/mssql';

export interface CustomerData {
  companyName: string;
  hp: string;
  address: string;
  shippingMethod: string;
  contacts: Array<{
    id: string;
    name: string;
    role: string;
    email: string;
    phone: string;
  }>;
  financials: Array<{
    year: number;
    revenue: number;
    quotesCount: number;
    ordersCount: number;
    discountsTotal: number;
  }>;
  deviceInventory: {
    totalDevices: number;
    activeDevices: number;
    outForCalibration: number;
  };
  calibrationTypes: Array<{
    name: string;
    value: number;
    color: string;
  }>;
  monthlyCalibrationDistribution: Array<{
    month: string;
    count: number;
  }>;
  calibrationLocationSplit: {
    internal: number;
    external: number;
  };
  meetingNotes: Array<{
    id: string;
    date: string;
    summary: string;
    participants: string[];
  }>;
  alerts: Array<{
    id: string;
    deviceId: string;
    deviceName: string;
    lastCalibration: string;
    nextCalibration: string;
    status: 'overdue' | 'upcoming';
  }>;
}

// Chart color palette for consistency
const CHART_COLORS = [
  "hsl(215 100% 50%)",   // chart-1: Blue
  "hsl(180 70% 45%)",    // chart-2: Teal
  "hsl(280 60% 60%)",    // chart-3: Purple
  "hsl(40 90% 60%)",     // chart-4: Amber
  "hsl(340 70% 60%)",    // chart-5: Pink
];

export async function getCustomerData(customerId: string): Promise<CustomerData> {
  const pool = await getPool();

  // Query basic customer info from database
  // Adjust table and column names based on your actual schema
  const customerResult = await pool.request()
    .input('customerId', sql.VarChar, customerId)
    .query(`
      SELECT TOP 1
        [Customer_Num] as hp,
        [Customer_Name] as companyName,
        [Address] as address
      FROM [dbo].[datasheet]
      WHERE [Customer_Num] = @customerId
    `);

  if (!customerResult.recordset.length) {
    throw new Error('Customer not found');
  }

  const customer = customerResult.recordset[0];

  // Get device count
  const deviceCountResult = await pool.request()
    .input('customerId', sql.VarChar, customerId)
    .query(`
      SELECT COUNT(DISTINCT [Serial_No]) as totalDevices
      FROM [dbo].[datasheet]
      WHERE [Customer_Num] = @customerId
    `);

  const totalDevices = deviceCountResult.recordset[0]?.totalDevices || 0;

  // Get calibration types distribution
  const calibrationTypesResult = await pool.request()
    .input('customerId', sql.VarChar, customerId)
    .query(`
      SELECT 
        [SKA] as calibrationType,
        COUNT(*) as count
      FROM [dbo].[datasheet]
      WHERE [Customer_Num] = @customerId
      AND [SKA] IS NOT NULL
      GROUP BY [SKA]
      ORDER BY count DESC
    `);

  const calibrationTypes = calibrationTypesResult.recordset.map((row, index) => ({
    name: row.calibrationType || 'אחר',
    value: parseInt(row.count) || 0,
    color: CHART_COLORS[index % CHART_COLORS.length]
  }));

  // For now, return a combination of real and placeholder data
  // You'll need to adjust queries based on your actual database schema
  return {
    companyName: customer.companyName || 'לקוח',
    hp: customer.hp,
    address: customer.address || 'לא צוין',
    shippingMethod: 'UPS', // Placeholder - add to DB if needed
    
    // Placeholder contacts - you'll need to query from your contacts table
    contacts: [
      {
        id: "CT-1",
        name: "איש קשר ראשי",
        role: "מנהל",
        email: "contact@company.com",
        phone: "050-0000000"
      }
    ],

    // Placeholder financial data - query from invoices/orders tables
    financials: [
      { year: 2023, revenue: 0, quotesCount: 0, ordersCount: 0, discountsTotal: 0 },
      { year: 2024, revenue: 0, quotesCount: 0, ordersCount: 0, discountsTotal: 0 },
      { year: 2025, revenue: 0, quotesCount: 0, ordersCount: 0, discountsTotal: 0 },
    ],

    deviceInventory: {
      totalDevices: totalDevices,
      activeDevices: Math.floor(totalDevices * 0.93), // Estimate
      outForCalibration: Math.floor(totalDevices * 0.07) // Estimate
    },

    calibrationTypes: calibrationTypes.length > 0 ? calibrationTypes : [
      { name: "אין נתונים", value: 1, color: CHART_COLORS[0] }
    ],

    // Placeholder - query from calibration history
    monthlyCalibrationDistribution: [
      { month: "ינו", count: 0 },
      { month: "פבר", count: 0 },
      { month: "מרץ", count: 0 },
      { month: "אפר", count: 0 },
      { month: "מאי", count: 0 },
      { month: "יונ", count: 0 },
      { month: "יול", count: 0 },
      { month: "אוג", count: 0 },
      { month: "ספט", count: 0 },
      { month: "אוק", count: 0 },
      { month: "נוב", count: 0 },
      { month: "דצמ", count: 0 },
    ],

    calibrationLocationSplit: {
      internal: 70,
      external: 30
    },

    meetingNotes: [],
    alerts: []
  };
}
