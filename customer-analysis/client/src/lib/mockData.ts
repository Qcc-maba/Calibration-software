export interface Meeting {
  id: string;
  date: string;
  summary: string;
  participants: string[];
}

export interface Contact {
  id: string;
  name: string;
  role: string;
  email: string;
  phone: string;
}

export interface CalibrationAlert {
  type: 'error' | 'warning';
  title: string;
  message: string;
  serialNo: string;
  lastCalDate: string;
  nextCalDate: string;
}

export interface CustomerComplaint {
  COMPNAME: string;
  CURDATE: string;
  DUEDATE: string;
  COMPSTATUS: string;
  COMPTYPE: string;
  COMPURGENCY: string;
  CUSTDES: string;
  COMPDIAG: string;
  COMPMETHOD: string;
  COMPREAL: string;
  CLOSED: string;
  [key: string]: any;
}

export interface Customer {
  id: string;
  companyName: string;
  hp: string; // Company ID
  address: string;
  agentName?: string;
  contacts: Contact[];
  shippingMethod: string;
  
  // 3-Year Analysis Data
  financials: {
    year: number;
    revenue: number;
    quotesCount: number;
    ordersCount: number;
    discountsTotal?: number;
    invoicesCount?: number;
    quotesRevenue?: number;
    ordersRevenue?: number;
    returnsRevenue?: number;
    returnsCount?: number;
  }[];
  
  deviceInventory: {
    totalDevices: number;
    activeDevices: number;
    outForCalibration: number;
  };
  
  calibrationTypes: {
    name: string;
    value: number;
    color: string;
  }[];

  calibrationDepartments?: {
    name: string;
    value: number;
    color: string;
  }[];

  calibrationItems?: {
    partName: string;
    description: string;
    price: number;
    quantity: number;
    orderNumber: string;
    date: string;
    department: string;
    location: 'internal' | 'external';
  }[];
  
  monthlyCalibrationDistribution: {
    month: string;
    count: number;
  }[];
  
  calibrationLocationSplit: {
    internal: number; // In-lab
    external: number; // On-site
  };

  calibrationByLocation?: {
    name: string;
    internal: number;
    external: number;
    total: number;
    internalPct: number;
    externalPct: number;
  }[];

  devicesList?: {
    serialNo: string;
    deviceName: string;
    model: string;
    manufacturer: string;
    lastCalDate: string;
    nextCalDate: string;
    certificateNo: string;
    status: 'active' | 'expired';
    location: 'internal' | 'external';
    department?: string;
    ska?: string;
  }[];

  ordersDetail?: {
    orderNumber: string;
    quotation: string;
    orderDate: string;
    year: number;
    priceAfterDiscount: number;
    discountPct: number;
    description: string;
    serialNo: string;
  }[];

  invoices?: {
    invoiceNumber: string;
    date: string;
    year: number;
    month: number;
    totalPrice: number;
    netPrice: number;
    vat: number;
    discount: number;
    orderId: number;
  }[];

  orders?: {
    orderId: number;
    orderName: string;
    date: string;
    year: number;
    month: number;
    totalPrice: number;
    netPrice: number;
    vat: number;
    discountAmount: number;
    closed: boolean;
  }[];

  meetingNotes: Meeting[];
  alerts: CalibrationAlert[];
  complaints: CustomerComplaint[];
  calibrationTrends?: any[];
  customerScore?: {
    score: number;
    grade: string;
    tenureScore: number;
    revenueScore: number;
    frequencyScore: number;
    breakdown?: { tenure: number; revenue: number; frequency: number };
  };
  returnDocuments?: any[];
  quotes?: any[];
  recentCalibrations?: any[];
  recentReturns?: any[];
  totalOrdersCount?: number;
  phone?: string;
  monthlyRevenue?: any[];
  pendingForecast?: { totalDocuments: number; totalValue: number };
}

export const MOCK_CUSTOMER: Customer = {
  id: "CUST-001",
  companyName: "אלביט מערכות בע״מ",
  hp: "510935634",
  address: "פארק המדע, רחובות, ישראל",
  contacts: [
    {
      id: "CT-1",
      name: "דוד כהן",
      role: "מנהל איכות",
      email: "david.cohen@elbit.co.il",
      phone: "050-1234567"
    },
    {
      id: "CT-2",
      name: "שרה לוי",
      role: "אחראית רכש",
      email: "sara.levy@elbit.co.il",
      phone: "052-9876543"
    }
  ],
  shippingMethod: "UPS",
  
  financials: [
    { year: 2023, revenue: 150000, quotesCount: 45, ordersCount: 40, discountsTotal: 12000 },
    { year: 2024, revenue: 185000, quotesCount: 52, ordersCount: 48, discountsTotal: 15000 },
    { year: 2025, revenue: 210000, quotesCount: 60, ordersCount: 55, discountsTotal: 18000 },
  ],

  deviceInventory: {
    totalDevices: 450,
    activeDevices: 420,
    outForCalibration: 30
  },

  calibrationTypes: [
    { name: "טמפרטורה", value: 35, color: "hsl(var(--chart-1))" },
    { name: "לחץ", value: 25, color: "hsl(var(--chart-2))" },
    { name: "אלקטרוניקה", value: 20, color: "hsl(var(--chart-3))" },
    { name: "מסה", value: 15, color: "hsl(var(--chart-4))" },
    { name: "אחר", value: 5, color: "hsl(var(--chart-5))" },
  ],

  monthlyCalibrationDistribution: [
    { month: "ינו", count: 20 },
    { month: "פבר", count: 25 },
    { month: "מרץ", count: 40 },
    { month: "אפר", count: 35 },
    { month: "מאי", count: 30 },
    { month: "יונ", count: 45 },
    { month: "יול", count: 20 },
    { month: "אוג", count: 15 },
    { month: "ספט", count: 25 },
    { month: "אוק", count: 50 },
    { month: "נוב", count: 40 },
    { month: "דצמ", count: 55 },
  ],

  calibrationLocationSplit: {
    internal: 70, // 70%
    external: 30  // 30%
  },

  meetingNotes: [
    {
      id: "MT-1",
      date: "2024-11-15",
      summary: "סיכום רבעוני: דנו בצורך להגדיל את תדירות הכיולים עבור חיישני הטמפרטורה בקו הייצור החדש.",
      participants: ["דוד כהן", "רון מנהל מעבדה"]
    },
    {
      id: "MT-2",
      date: "2024-08-01",
      summary: "פגישת חידוש חוזה: אושרה הנחה של 5% עבור התחייבות שנתית ל-500 מכשירים.",
      participants: ["שרה לוי", "יעל מכירות"]
    }
  ],

  alerts: [
    {
      type: "error",
      title: "Fluke 87V Multimeter",
      message: "פג תוקף הכיול",
      serialNo: "SN-998877",
      lastCalDate: "15/10/2023",
      nextCalDate: "15/10/2024"
    },
    {
      type: "warning",
      title: "Pressure Gauge 10bar",
      message: "כיול קרוב",
      serialNo: "SN-112233",
      lastCalDate: "20/01/2024",
      nextCalDate: "20/01/2025"
    }
  ],
  complaints: []
};
