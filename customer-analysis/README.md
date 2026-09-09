# Customer Analytics (QCC) — ניתוח לקוחות מ.ב.א

דשבורד לניתוח לקוחות של מעבדת הכיול: פיננסים, מלאי מכשירים, לוחות כיול, וציון לקוח.
עברית RTL. הועבר מ-Replit (2026-07-30).

> ⚠️ **סודות לא נכנסו ל-git**: `config.py` (פרטי SQL Server), `.env`, `.local/` (2.7GB מצב Replit),
> `node_modules`, `dist`, וארכיוני `*.tar.gz`/`*.zip` — הוחרגו. השתמש ב-`local-scripts/config.example.py`
> כתבנית ומלא מקומית.

## Stack
- **Frontend** (`client/`): React + TypeScript + Vite, Wouter, TanStack Query, shadcn/ui (Radix),
  Tailwind v4, Recharts, Framer Motion. גופנים Heebo (עברית) + JetBrains Mono.
- **Backend** (`server/`): Node.js + Express + TypeScript (tsx), esbuild. REST תחת `/api/`.
- **DB**: PostgreSQL דרך Drizzle ORM (`synced_customers`, JSONB). מקור חיצוני: MS SQL Server.
- **סנכרון נתונים**: סקריפט Python מקומי (`local-scripts/`, pyodbc) מושך מ-SQL Server ושולח ל-API
  של השרת (cache בזיכרון). כך מפני ש-Replit לא ניגש ל-SQL Server ישירות.
- **מבנה monorepo**: `client/` · `server/` · `shared/` (Zod + drizzle-zod).

## משתני סביבה (ל-`.env` / config מקומי)
`DATABASE_URL` (PostgreSQL) · `SQL_SERVER_ADDR` · `SQL_UID` / `SQL_PWD` / `SQL_DATABASE` ·
`SHIP_API_EMAIL` / `SHIP_API_PASSWORD` / `SHIP_CUSTOMER_ID` (UPS Israel).

## הרצה (מקומית)
> ⚠️ להרצה מלאה מחוץ ל-Replit ראה **`MIGRATION-NOTES.md`** (רשימת צ'קליסט + טבלת משתני סביבה
> + התאמות Replit). תקצירי המפתח: נדרש **Node 20 LTS** + **PostgreSQL 16**; סקריפט ה-`dev`
> משתמש בתחביר POSIX `NODE_ENV=…` ש**נכשל ב-cmd/PowerShell** — יש לתקן עם `cross-env` או
> להשתמש בעקיפה למטה.

```powershell
# דורש DATABASE_URL (PostgreSQL). אין טוען dotenv בשרת — קבע משתני סביבה בשל או הוסף dotenv.
$env:DATABASE_URL="postgresql://postgres:postgres@localhost:5432/qcc"
npm install
npm run db:push                              # יצירת סכימה מ-shared/schema.ts (אין SQL migrations)

# הרצת dev (עקיפה ל-Windows, ללא שינוי package.json):
$env:NODE_ENV="development"; npx tsx server/index.ts   # API + client על http://localhost:5000
# לאחר תיקון I-1 (cross-env) ניתן פשוט: npm run dev

# build + start ל-production (אופציונלי):
#   npm run build   # Vite → dist/public, esbuild → dist/index.cjs
#   $env:NODE_ENV="production"; node dist/index.cjs
```
> ⚠️ **auto-migration**: לאחר כל סנכרון השרת מנסה לדחוף את כל הנתונים ל-URL של Replit הישן
> (`PRODUCTION_URL` ב-`server/routes.ts`). קבע `PRODUCTION_URL` או השבת `autoMigrateEnabled`
> לפני הרצה מקומית. פרטים ב-`MIGRATION-NOTES.md` (I-3).

```powershell
# סנכרון נתונים (מריצים במחשב עם גישה ל-SQL Server + ODBC Driver for SQL Server):
copy local-scripts\config.example.py local-scripts\config.py   # ומלא פרטים
# בקובץ config.py: REPLIT_API_URL = http://localhost:5000/api/sync/customer-data
pip install pyodbc requests python-dateutil python-dotenv
python local-scripts\sync-customer-data.py --url http://localhost:5000
```

## ציון לקוח
משוקלל: Tenure 25% · Revenue 40% · Frequency 35%. דירוג: A≥85 · B≥70 · C≥55 · D≥40 · E<40.

## סטטוס מיגרציה
✅ קוד המקור הועבר (16MB, בלי סודות/artifacts). ⏳ טרם הותאם לבנייה/הרצה בפרויקט זה
(תלויות `npm install`, `.env`). קשור ל-`DBA/` (סנכרון) ו-`Systems/Priority/` (Priority OData).
