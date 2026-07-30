# QCC Analytics Dashboard

## Overview

QCC Analytics is a customer analysis dashboard for a calibration laboratory (מעבדת כיול). The application provides data visualization and customer management capabilities, displaying financial data, device inventory, calibration schedules, and meeting notes. The system is designed with Hebrew RTL (right-to-left) support and connects to an external SQL Server database for customer data.

## User Preferences

Preferred communication style: Simple, everyday language.
Deploy to production after every code change.

## System Architecture

### Frontend Architecture
- **Framework**: React with TypeScript
- **Routing**: Wouter for lightweight client-side routing
- **State Management**: TanStack Query (React Query) for server state management
- **UI Components**: shadcn/ui component library built on Radix UI primitives
- **Styling**: Tailwind CSS v4 with CSS variables for theming
- **Charts**: Recharts for data visualization
- **Animations**: Framer Motion for UI animations
- **Fonts**: Heebo (Hebrew) and JetBrains Mono

### Backend Architecture
- **Runtime**: Node.js with Express
- **Language**: TypeScript compiled with tsx
- **Build Tool**: Vite for frontend, esbuild for server bundling
- **API Structure**: RESTful endpoints under `/api/` prefix
- **Data Sync Pattern**: Hybrid approach where a local Python script syncs data from SQL Server to the Replit server via API calls, storing in an in-memory cache

### Data Storage Solutions
- **Primary Database**: PostgreSQL via Drizzle ORM with `synced_customers` table storing customer data as JSONB
- **External Data Source**: Microsoft SQL Server (accessed via local Python script, not directly from Replit)
- **Session Storage**: Memory-based storage (MemStorage class)

### Dashboard Features
- **Customer Score Card**: Displays customer grade (A-E) with breakdown scores for tenure, revenue, and purchase frequency
- **Financials Tab**: Revenue, discounts, orders, and quotes for 2023-2025
- **Invoices Tab**: Invoice data from Priority ERP with:
  - Summary cards per year showing total revenue and discounts
  - Invoices vs Orders comparison bar chart
  - Discount analysis area chart
  - Complete invoice list with number, date, net price, VAT, discount, and total
- **Orders Detail Tab**: Complete breakdown of all orders showing order number, quotation, date, description, serial number, discount, and amount
- **Inventory Tab**: Device inventory with calibration status and monthly distribution
- **Distribution Tab**: Calibration types pie chart and internal/external location split
- **Devices Tab**: Complete device list with serial numbers, model, manufacturer, calibration dates, and status badges

### Authentication and Authorization
- Basic user schema defined with username/password in PostgreSQL
- Passport.js available as dependency for authentication implementation
- Currently minimal auth implementation

### Key Design Patterns
- **Monorepo Structure**: Client (`client/`), server (`server/`), and shared code (`shared/`)
- **Path Aliases**: `@/` for client source, `@shared/` for shared modules
- **Component Organization**: UI components in `components/ui/`, layout components separate
- **Type Safety**: Zod schemas with drizzle-zod for validation

## External Dependencies

### Database Integrations
- **PostgreSQL**: Primary database configured via `DATABASE_URL` environment variable, using Drizzle ORM
- **SQL Server**: External database accessed via local Python scripts using pyodbc (connection details in `attached_assets/config_*.py`)

### Third-Party Services
- **Google Custom Search API**: Configured with API key and CSE ID (see attached config)
- **Ship API (UPS Israel)**: Shipment cost tracking via https://newbetaapi.ship.co.il; WAF blocks Replit IPs so data must be synced via local script (`--ship` / `--ship-discover` flags in sync-customer-data.py); Credentials via env vars (SHIP_API_EMAIL, SHIP_API_PASSWORD, SHIP_CUSTOMER_ID)
- **OpenAI**: Available as dependency for AI features
- **Google Generative AI**: Available as dependency

### Key Runtime Dependencies
- Express for HTTP server
- Drizzle ORM for database operations
- TanStack Query for data fetching
- Radix UI primitives for accessible components
- mssql package for SQL Server types (used in local scripts)

### Environment Variables Required
- `DATABASE_URL`: PostgreSQL connection string
- `SQL_SERVER_ADDR`: SQL Server address (for local sync scripts)
- `SQL_UID`, `SQL_PWD`, `SQL_DATABASE`: SQL Server credentials (for local sync scripts)
- `SHIP_API_EMAIL`, `SHIP_API_PASSWORD`: Ship API credentials (for UPS shipment sync)
- `SHIP_CUSTOMER_ID`: Ship API customer ID (default: 699226)

### Customer Scoring System
Customer scores are calculated during sync based on three weighted metrics:
- **Tenure (25%)**: Months since first purchase (max 60 months = 100%)
- **Revenue (40%)**: Total net revenue in last 24 months (max ₪500,000 = 100%)
- **Frequency (35%)**: Active months with invoices/orders out of last 24

Grades based on weighted score: A≥85, B≥70, C≥55, D≥40, E<40
Grade colors: A=emerald, B=blue, C=amber, D=orange, E=red