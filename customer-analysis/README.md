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
```bash
npm install
npm run dev          # Vite + Express (ראה package.json scripts)
# סנכרון נתונים (מריצים במקום עם גישה ל-SQL Server):
#   cp local-scripts/config.example.py local-scripts/config.py   # ומלא פרטים
#   python local-scripts/sync-customer-data.py
```

## ציון לקוח
משוקלל: Tenure 25% · Revenue 40% · Frequency 35%. דירוג: A≥85 · B≥70 · C≥55 · D≥40 · E<40.

## סטטוס מיגרציה
✅ קוד המקור הועבר (16MB, בלי סודות/artifacts). ⏳ טרם הותאם לבנייה/הרצה בפרויקט זה
(תלויות `npm install`, `.env`). קשור ל-`DBA/` (סנכרון) ו-`Systems/Priority/` (Priority OData).
