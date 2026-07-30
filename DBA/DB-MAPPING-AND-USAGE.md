# מיפוי בסיס הנתונים MABA 2000 + ניתוח שימוש

> **מסד:** PostgreSQL 16 (container `maba2000-db`, DB `maba2000`, schema `public`)
> **תאריך הפקה:** 2026-06-03
> **מקור הנתונים:** `pg_catalog` / `information_schema` / `pg_stat_*` חיים מתוך ה-container
> **היקף:** 15 טבלאות בסיס, 150 עמודות, ~7.04M שורות, ~1.24 GB סה"כ

מסמך זה מורכב משלושה חלקים:
1. **מיפוי מלא** — כל טבלה, כל שדה, מפתחות ואינדקסים.
2. **ניתוח שימוש (לוגים/סטטיסטיקות)** — טבלאות בשימוש גבוה מול נמוך, ניצול אינדקסים.
3. **ממצאים והמלצות**.

⚠️ **הערת מהימנות לניתוח השימוש:** ה-container עלה לפני ~שעתיים בלבד וה-`stats_reset` ריק (מונים מצטברים מאז עליית המסד). מרבית הנתונים נטענו בייבוא bulk ולכן מוני ה-`n_tup_ins/upd/del` אופסו ל-0. בנוסף, `pg_stat_statements` **זמין אך לא מותקן** — ולכן אין ניתוח ברמת השאילתה. ניתוח השימוש מטה משלב שלושה אותות: (א) נפח נתונים, (ב) מוני סריקה חיים (seq/idx scan), (ג) שימוש תכנוני (אילו טבלאות האפליקציה קוראת/כותבת בפועל).

---

## 1. מיפוי טבלאות מלא

### סקירת נפחים

| טבלה | שורות (משוער) | גודל כולל | תיאור תמציתי |
|------|---:|---:|------|
| `mba_calib_status` | 5,938,168 | 1054 MB | היסטוריית סטטוס כיול — append-only (השורה הגדולה ביותר) |
| `mba_records` | 1,106,156 | 174 MB | רשומות כיול (מכשירים) |
| `mba_customers` | 6,824 | 7.5 MB | לקוחות |
| `mba_template_rows` | 310 | 88 kB | שורות תבנית דוח |
| `mba_users` | 260 | 128 kB | משתמשים/לוגינים |
| `mba_measurements` | 54 | 88 kB | מדידות מובנות (מערכת חדשה) |
| `mba_instrument_templates` | 43 | 40 kB | תבניות מכשור |
| `__EFMigrationsHistory` | 19 | 24 kB | היסטוריית מיגרציות EF |
| `mba_stat_codes` | 15 | 24 kB | קודי סטטוס (טבלת ייחוס) |
| `mba_app_config` | 12 | 48 kB | קונפיגורציה |
| `mba_instrument_types` | 9 | 48 kB | סוגי מכשור |
| `mba_sync_log` | 8 | 32 kB | לוג סנכרון Priority |
| `mba_audit_log` | 0 | 16 kB | לוג ביקורת (ריק) |
| `mba_report_templates` | 0 | 16 kB | תבניות דוח legacy (ריק) |
| `mba_documents` | 0 | 8 kB | מסמכים (ריק) |

---

### 1.1 `mba_records` — רשומות כיול (174 MB, ~1.1M שורות)

הטבלה המרכזית. כל שורה = מכשיר/פריט בכיול. שימו לב לקפיצה בעמודות (חסרים pos 29–30 — עמודות שהוסרו במיגרציה, ככל הנראה שדות סביבה שעברו ל-`mba_calib_status`).

| # | עמודה | טיפוס | אורך | NULL | ברירת מחדל |
|---|------|------|---|---|---|
| 1 | `id` | integer | | NO | identity |
| 2 | `mba_num` | varchar | 20 | NO | |
| 3 | `update_num` | varchar | 10 | NO | `'001'` |
| 4 | `full_num` | varchar | 32 | YES | |
| 5 | `doc` | integer | | YES | |
| 6 | `instrument_type` | varchar | 30 | NO | `'Generic'` |
| 7 | `language` | char | 2 | NO | `'HE'` |
| 8 | `customer_id` | integer | | YES | → FK |
| 9 | `created_at` | timestamptz | | NO | `now()` |
| 10 | `updated_at` | timestamptz | | NO | `now()` |
| 11 | `dev_type` | varchar | 5 | YES | (סוג סטייה FS/PT) |
| 12 | `full_scale` | numeric | 18 | YES | |
| 13 | `meas_unit` | varchar | 20 | YES | |
| 14 | `tolerance` | numeric | 10 | YES | |
| 15 | `calib_description` | varchar | 2000 | YES | |
| 16 | `calib_location` | varchar | 200 | YES | |
| 17 | `cert_notes` | varchar | 1000 | YES | |
| 18 | `item_condition` | varchar | 100 | YES | |
| 19 | `item_description` | varchar | 300 | YES | |
| 20 | `item_model` | varchar | 80 | YES | |
| 21 | `manufacturer` | varchar | 80 | YES | |
| 22 | `serial_number` | varchar | 50 | YES | |
| 23 | `standards_used` | varchar | 500 | YES | |
| 24 | `internal_notes` | text | | YES | |
| 25 | `quick_notes` | text | | YES | |
| 26 | `calib_standard` | text | | YES | |
| 27 | `resolution` | text | | YES | |
| 28 | `sensor_type` | text | | YES | |
| 31 | `ref_std_serial_number` | text | | YES | |
| 32 | `tolerance_offset` | numeric | | YES | |
| 33 | `calib_spec_num` | text | | YES | |
| 34 | `calib_device` | varchar | 100 | YES | |
| 35 | `calib_direction` | varchar | 10 | YES | |
| 36 | `exam_type` | varchar | 20 | YES | |
| 37 | `fluid_column_height` | numeric | 10 | YES | |
| 38 | `master_unit` | varchar | 20 | YES | |
| 39 | `precision_class` | varchar | 30 | YES | |
| 40 | `test_medium` | varchar | 100 | YES | |
| 41 | `test_position` | varchar | 20 | YES | |

**מפתחות:** PK `id` · UNIQUE `(mba_num, update_num)` · UNIQUE `mba_num` · UNIQUE `update_num` · FK `customer_id → mba_customers.id`
**אינדקסים:** `mba_records_pkey` (24 MB), `mba_records_mba_num_update_num_key` (33 MB), `idx_records_mba_num` (11 MB), `idx_records_customer` (7 MB)

---

### 1.2 `mba_calib_status` — היסטוריית סטטוס (1054 MB, ~5.9M שורות) ⭐ הטבלה הגדולה

טבלה **append-only**: כל שינוי סטטוס = שורה חדשה. הסטטוס ה"נוכחי" = השורה עם ה-`kline` הגבוה ביותר עבור `record_id` נתון. ~5.4 שורות סטטוס לכל רשומה בממוצע.

| # | עמודה | טיפוס | אורך | NULL | הערה |
|---|------|------|---|---|---|
| 1 | `id` | integer | | NO | identity |
| 2 | `record_id` | integer | | NO | → FK |
| 3 | `kline` | integer | | NO | מספר שורה/גרסה |
| 4 | `stat_code` | varchar | 5 | NO | → קוד סטטוס (AC/GR/UC…) |
| 5 | `status_name` | varchar | 50 | YES | |
| 6 | `user_login` | varchar | 20 | YES | |
| 7 | `auth_name` | varchar | 100 | YES | |
| 8 | `reject_notes` | varchar | 5 | YES | |
| 9 | `union_report` | varchar | 50 | YES | |
| 10 | `next_calib_date` | date | | YES | |
| 11 | `part_model` | varchar | 30 | YES | |
| 12 | `manufacturer_name` | varchar | 32 | YES | |
| 13 | `manufacturer_code` | varchar | 17 | YES | |
| 14 | `memo` | varchar | 10 | YES | |
| 15 | `c_date` | date | | YES | תאריך כיול |
| 16 | `created_at` | timestamptz | | NO | `now()` |
| 17 | `humidity_pct` | numeric | 6 | YES | תנאי סביבה |
| 18 | `mifrat_code` | varchar | 5 | YES | |
| 19 | `result` | varchar | 20 | YES | |
| 20 | `temp_celsius` | numeric | 6 | YES | |
| 21 | `barometric_pressure` | numeric | | YES | |
| 22 | `calibrator_id` | text | | YES | |
| 23 | `barometric_uncertainty` | numeric | | YES | |
| 24 | `humidity_uncertainty` | numeric | | YES | |
| 25 | `temp_uncertainty` | numeric | | YES | |

**מפתחות:** PK `id` · UNIQUE `(record_id, kline)` · FK `record_id → mba_records.id`
**אינדקסים:** `mba_calib_status_pkey` (131 MB), `mba_calib_status_record_id_kline_key` (131 MB), `idx_calib_record_kline` `(record_id, kline DESC)` (131 MB), `idx_calib_status_record` `(record_id)` (68 MB), `idx_calib_stat_code` (37 MB) — **סה"כ ~498 MB אינדקסים** (יותר מ-47% מגודל הטבלה).

---

### 1.3 `mba_customers` — לקוחות (7.5 MB, 6,824 שורות)

| # | עמודה | טיפוס | אורך | NULL | ברירת מחדל |
|---|------|------|---|---|---|
| 1 | `id` | integer | | NO | identity |
| 2 | `name_he` | varchar | 100 | NO | |
| 3 | `name_en` | varchar | 100 | YES | |
| 4 | `address_he` | varchar | 200 | YES | |
| 5 | `address_en` | varchar | 200 | YES | |
| 6 | `active` | boolean | | NO | `true` |
| 7 | `created_at` | timestamptz | | NO | `now()` |
| 8 | `updated_at` | timestamptz | | NO | `now()` |

**מפתחות:** PK `id` · UNIQUE `name_he` · **אינדקסים:** `pkey` (776 kB), `name_he_key` (1.9 MB)

---

### 1.4 `mba_measurements` — מדידות מובנות (88 kB, 54 שורות)

מבנה מדידות של המערכת החדשה. **נפח נמוך מאוד** (54 שורות מול 1.1M רשומות) — מאוכלס רק עבור רשומות שנוצרו/נערכו במערכת ה-Web החדשה; נתוני ה-legacy לא הומרו לטבלה זו.

| # | עמודה | טיפוס | אורך | NULL | ברירת מחדל |
|---|------|------|---|---|---|
| 1 | `id` | integer | | NO | identity |
| 2 | `record_id` | integer | | NO | → FK |
| 3 | `tag_name` | varchar | 100 | NO | |
| 4 | `tag_value` | text | | YES | |
| 5 | `sort_order` | integer | | NO | `0` |
| 6 | `created_at` | timestamptz | | NO | `now()` |
| 7 | `reading1` | numeric | 18 | YES | |
| 8 | `reading2` | numeric | 18 | YES | |
| 9 | `reading3` | numeric | 18 | YES | |
| 10 | `target_value` | numeric | 18 | YES | |

**מפתחות:** PK `id` · FK `record_id → mba_records.id` · **אינדקסים:** `pkey`, `idx_measurements_record`

---

### 1.5 `mba_documents` — מסמכים (ריק)

| # | עמודה | טיפוס | NULL |
|---|------|------|---|
| 1 | `id` | integer | NO |
| 2 | `record_id` | integer | NO (→ FK `mba_records`) |
| 3 | `stat_code` | varchar(5) | NO |
| 4 | `customer_id` | integer | YES (→ FK `mba_customers`) |
| 5 | `created_at` | timestamptz | NO |

**מפתחות:** PK `id` · FK `record_id`, `customer_id`. ⚠️ אין אינדקסים על עמודות ה-FK (לא קריטי בעוד הטבלה ריקה).

---

### 1.6 `mba_instrument_types` — סוגי מכשור (9 שורות)

| # | עמודה | טיפוס | אורך | NULL | ברירת מחדל |
|---|------|------|---|---|---|
| 1 | `id` | integer | | NO | identity |
| 2 | `type_code` | varchar | 30 | NO | |
| 3 | `name_he` | varchar | 100 | NO | |
| 4 | `name_en` | varchar | 100 | NO | |
| 5 | `template_fields` | jsonb | | NO | `'[]'` |

**מפתחות:** PK `id` · UNIQUE `type_code`

---

### 1.7 `mba_instrument_templates` — תבניות מכשור (43 שורות)

| # | עמודה | טיפוס | אורך | NULL |
|---|------|------|---|---|
| 1 | `id` | integer | | NO |
| 2 | `instrument_type` | varchar | 50 | NO |
| 3 | `meas_unit` | varchar | 20 | YES |
| 4 | `tolerance` | numeric | 10 | NO |
| 5 | `dev_type` | varchar | 5 | NO |
| 6 | `full_scale` | numeric | 18 | YES |
| 7 | `source_file` | varchar | 200 | YES |
| 8 | `created_at` | timestamptz | | NO |
| 9 | `updated_at` | timestamptz | | NO |

**מפתחות:** PK `id` · UNIQUE `instrument_type`

---

### 1.8 `mba_template_rows` — שורות תבנית (310 שורות)

| # | עמודה | טיפוס | אורך | NULL |
|---|------|------|---|---|
| 1 | `id` | integer | | NO |
| 2 | `template_id` | integer | | NO (→ FK `mba_instrument_templates`) |
| 3 | `sort_order` | integer | | NO |
| 4 | `label` | varchar | 100 | NO |
| 5 | `is_separator` | boolean | | NO |
| 6 | `detail` | text | | YES |
| 7 | `target_value` | numeric | | YES |

**מפתחות:** PK `id` · FK `template_id` · **אינדקס:** `ix_mba_template_rows_template_id`

---

### 1.9 `mba_stat_codes` — קודי סטטוס (15 שורות, טבלת ייחוס)

| # | עמודה | טיפוס | אורך | NULL |
|---|------|------|---|---|
| 1 | `code` | varchar | 5 | NO (PK) |
| 2 | `name_he` | varchar | 60 | NO |
| 3 | `name_en` | varchar | 60 | NO |
| 4 | `category` | varchar | 20 | NO |

**מפתחות:** PK `code`. 15 הקודים תואמים לטבלת הסטטוסים ב-`CLAUDE.md` (AC/GR/UC/UG/DM/DC/FC/UF/UM/UD/CD ...).

---

### 1.10 `mba_users` — משתמשים (260 שורות)

| # | עמודה | טיפוס | אורך | NULL | ברירת מחדל |
|---|------|------|---|---|---|
| 1 | `id` | integer | | NO | identity |
| 2 | `username` | varchar | 50 | NO | |
| 3 | `username_en` | varchar | 50 | YES | |
| 4 | `password_hash` | varchar | 255 | NO | |
| 5 | `active` | boolean | | NO | `true` |
| 6 | `created_at` | timestamptz | | NO | `now()` |
| 7 | `updated_at` | timestamptz | | NO | `now()` |
| 8 | `role` | text | | NO | `''` |

**מפתחות:** PK `id` · UNIQUE `username`. (260 שורות = ככל הנראה לוגינים שהומרו מהמערכת הישנה.)

---

### 1.11 `mba_app_config` — קונפיגורציה (12 שורות)

| # | עמודה | טיפוס | אורך | NULL |
|---|------|------|---|---|
| 1 | `id` | integer | | NO |
| 2 | `category` | varchar | 50 | NO |
| 3 | `key` | varchar | 100 | NO |
| 4 | `value` | varchar | 2000 | YES |
| 5 | `description` | varchar | 500 | YES |
| 6 | `updated_at` | timestamptz | | NO |
| 7 | `updated_by` | varchar | 50 | YES |

**מפתחות:** PK `id` · UNIQUE `(category, key)`

---

### 1.12 `mba_sync_log` — לוג סנכרון Priority (8 שורות)

| # | עמודה | טיפוס | אורך | NULL |
|---|------|------|---|---|
| 1 | `id` | integer | | NO |
| 2 | `sync_type` | varchar | 30 | NO |
| 3 | `status` | varchar | 20 | NO |
| 4 | `started_at` | timestamptz | | NO |
| 5 | `completed_at` | timestamptz | | YES |
| 6 | `items_synced` | integer | | NO |
| 7 | `error_message` | varchar | 2000 | YES |
| 8 | `initiated_by` | varchar | 50 | YES |

**מפתחות:** PK `id`

---

### 1.13 `mba_audit_log` — לוג ביקורת (ריק) ⚠️

| # | עמודה | טיפוס | NULL | ברירת מחדל |
|---|------|------|---|---|
| 1 | `id` | bigint | NO | identity |
| 2 | `table_name` | varchar(50) | NO | |
| 3 | `record_id` | integer | YES | |
| 4 | `action` | varchar(10) | NO | |
| 5 | `user_login` | varchar(50) | YES | |
| 6 | `changed_at` | timestamptz | NO | `now()` |
| 7 | `payload` | jsonb | YES | |

**מפתחות:** PK `id`. **הטבלה ריקה — אין כתיבת ביקורת בפועל** (ראו ממצא #5).

---

### 1.14 `mba_report_templates` — תבניות דוח (ריק)

| # | עמודה | טיפוס | אורך | NULL | ברירת מחדל |
|---|------|------|---|---|---|
| 1 | `id` | integer | | NO | identity |
| 2 | `name` | varchar | 100 | NO | |
| 3 | `language` | char | 2 | NO | `'HE'` |
| 4 | `instrument_type` | varchar | 30 | YES | |
| 5 | `content` | text | | YES | |
| 6 | `created_at` | timestamptz | | NO | `now()` |

**מפתחות:** PK `id`. ריק (מאוכלס ע"י `tools/SeedTemplates` בעת הצורך).

---

### 1.15 `__EFMigrationsHistory` — מיגרציות EF (19 שורות)

| # | עמודה | טיפוס | אורך | NULL |
|---|------|------|---|---|
| 1 | `migration_id` | varchar | 150 | NO (PK) |
| 2 | `product_version` | varchar | 32 | NO |

טבלת תשתית של EF Core. 19 שורות = 19 מיגרציות שהוחלו.

---

### מפת קשרים (Foreign Keys)

```
mba_customers ──┬─< mba_records ──┬─< mba_calib_status   (record_id, append-only)
                │                 ├─< mba_measurements   (record_id)
                │                 └─< mba_documents      (record_id)
                └────────────────────< mba_documents     (customer_id)

mba_instrument_templates ──< mba_template_rows           (template_id)

טבלאות ללא FK (עצמאיות/ייחוס): mba_stat_codes, mba_instrument_types,
mba_users, mba_app_config, mba_sync_log, mba_audit_log,
mba_report_templates, __EFMigrationsHistory
```

---

## 2. ניתוח שימוש (Logs / Statistics)

### 2.1 דירוג לפי נפח נתונים (אות מבני יציב)

| דרגה | טבלה | שורות | גודל | % מהמסד |
|------|------|---:|---:|---:|
| 🔴 גבוה מאוד | `mba_calib_status` | 5.94M | 1054 MB | ~85% |
| 🔴 גבוה | `mba_records` | 1.11M | 174 MB | ~14% |
| 🟡 בינוני | `mba_customers` | 6,824 | 7.5 MB | <1% |
| 🟢 נמוך | `template_rows`, `users`, `measurements`, `instrument_templates` | 43–310 | <128 kB | זניח |
| ⚪ ייחוס | `stat_codes`, `instrument_types`, `app_config` | 9–15 | <48 kB | זניח |
| ⚫ ריק | `mba_documents`, `mba_report_templates`, `mba_audit_log` | 0 | — | — |

**שתי טבלאות (`mba_calib_status` + `mba_records`) מהוות ~99% מנפח המסד.** כל השאר זניח.

### 2.2 מוני סריקה חיים (seq_scan / idx_scan)

| טבלה | seq_scan | idx_scan | פרשנות |
|------|---:|---:|------|
| `mba_calib_status` | 24 | 10 | פעילה — מעורבת seq+index |
| `mba_records` | 18 | 3 | פעילה |
| `mba_stat_codes` | 4 | 2 | נקראת כטבלת ייחוס |
| `mba_customers` | 1 | 0 | קריאה בודדת |
| כל השאר | 0 | 0 | לא נגעו בהן בחלון המדידה |

> שימו לב: המספרים נמוכים כי המסד עלה לפני ~שעתיים והאפליקציה כמעט לא הופעלה. אלה אינם נתוני production מלאים — ראו הערת המהימנות בראש המסמך.

### 2.3 ניצול אינדקסים (`pg_stat_user_indexes`)

**אינדקסים שכן שימשו:**
| אינדקס | טבלה | scans | tuples read |
|------|------|---:|---:|
| `idx_calib_status_record` | calib_status | 6 | 11,883,663 |
| `idx_records_mba_num` | records | 1 | 1,113,296 |
| `idx_calib_record_kline` | calib_status | 2 | 2 |
| `idx_calib_stat_code` | calib_status | 2 | 2 |
| `mba_records_pkey` | records | 2 | 2 |

**אינדקסים עם 0 שימושים (idx_scan=0) שתופסים מקום משמעותי:**
| אינדקס | גודל | הערה |
|------|---:|------|
| `mba_calib_status_record_id_kline_key` | 131 MB | UNIQUE — נדרש לאכיפת ייחוד, לא לקריאה |
| `mba_calib_status_pkey` | 131 MB | PK — נדרש |
| `mba_records_mba_num_update_num_key` | 33 MB | UNIQUE — נדרש |
| `idx_records_customer` | 7 MB | FK lookup — צפוי להיות בשימוש בייצור |

> ה-0 על PK/UNIQUE צפוי בחלון מדידה קצר; אין להסיק מכך מיותרות.

### 2.4 טבלאות "בשימוש נמוך" — סיווג והסבר

| טבלה | סיבת השימוש הנמוך | פעולה מומלצת |
|------|------|------|
| `mba_audit_log` | ריקה — מנגנון ביקורת לא פעיל בקוד | לבדוק אם יש להפעיל trigger/קוד ביקורת |
| `mba_documents` | ריקה — פיצ'ר מסמכים לא בשימוש עדיין | תקין אם מתוכנן לעתיד |
| `mba_report_templates` | ריקה — מאוכלסת ע"י SeedTemplates לפי דרישה | תקין |
| `mba_measurements` | 54 שורות בלבד — נתוני legacy לא הומרו לכאן | להחליט אם להמיר מדידות היסטוריות |
| `mba_sync_log` | 8 שורות — Priority sync רץ רק כש-`PrioritySync:Enabled=true` | תקין |
| ייחוס (stat_codes/instrument_types/app_config) | נפח קבוע מטבעו | תקין |

---

## 3. ממצאים והמלצות

### 3.1 אינדקס מועמד למחיקה (חיסכון ~68 MB)
`idx_calib_status_record` על `(record_id)` הוא **תת-קבוצה מובילה** של:
- `idx_calib_record_kline` `(record_id, kline DESC)` — משרת גם חיפושי `record_id` בלבד
- `mba_calib_status_record_id_kline_key` `(record_id, kline)` — UNIQUE, מוביל גם הוא ב-`record_id`

לכאורה `idx_calib_status_record` **מיותר**. לפני מחיקה כדאי לוודא ב-production שאין שאילתה שמעדיפה דווקא אותו (הוא קטן יותר → לעיתים נבחר). מחיקה תחסוך ~68 MB ותקל על כתיבות ל-append-only.

### 3.2 ריבוי אינדקסים על `mba_calib_status` (498 MB אינדקסים על טבלה append-only)
שלושה אינדקסים בני 131 MB כל אחד (`pkey`, `unique(record_id,kline)`, `idx_calib_record_kline`). מאחר שהטבלה append-only ונקראת בעיקר לפי "סטטוס נוכחי", שקלו אינדקס חלקי/מותאם (למשל covering index ל-`(record_id, kline DESC) INCLUDE (stat_code, c_date)`) במקום ריבוי אינדקסים חופפים.

### 3.3 `pg_stat_statements` לא מותקן
לניתוח לוגים אמיתי ברמת השאילתה (שאילתות איטיות/תכופות) יש להתקין:
```sql
-- ב-postgresql.conf: shared_preload_libraries = 'pg_stat_statements'  (דורש restart)
CREATE EXTENSION pg_stat_statements;
```
ללא זה אין מדידת זמני שאילתה / TOP queries.

### 3.4 איפוס מונים למדידת production נקייה
המונים מצטברים מאז עליית ה-container ומעורבבים עם ה-bulk import. למדידת שימוש אמיתית:
```sql
SELECT pg_stat_reset();   -- ואז להריץ את האפליקציה יום-יומיים ולמדוד שוב
```

### 3.5 `mba_audit_log` ריקה
מבנה ביקורת (table/action/payload jsonb) קיים אך לא נכתב אליו דבר. אם ביקורת נדרשת — יש לוודא שהקוד/טריגרים מאכלסים אותה.

### 3.6 פערי עמודות ב-`mba_records`
חסרים pos 29–30 (עמודות שהוסרו). אין השפעה תפקודית; ציון לתיעוד בלבד.

---

## נספח: שאילתות שהפיקו מסמך זה

```sql
-- נפח ושימוש לכל טבלה
SELECT relname, n_live_tup, seq_scan, idx_scan, n_tup_ins, n_tup_upd, n_tup_del,
       pg_size_pretty(pg_total_relation_size(relid)) AS size
FROM pg_stat_user_tables ORDER BY n_live_tup DESC;

-- כל השדות
SELECT table_name, ordinal_position, column_name, data_type, is_nullable, column_default
FROM information_schema.columns WHERE table_schema='public'
ORDER BY table_name, ordinal_position;

-- ניצול אינדקסים
SELECT relname, indexrelname, idx_scan, idx_tup_read,
       pg_size_pretty(pg_relation_size(indexrelid))
FROM pg_stat_user_indexes ORDER BY idx_scan DESC;

-- מפתחות וקשרים
SELECT tc.table_name, tc.constraint_type, kcu.column_name, ccu.table_name AS ref
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu USING (constraint_name)
LEFT JOIN information_schema.constraint_column_usage ccu
  ON ccu.constraint_name=tc.constraint_name AND tc.constraint_type='FOREIGN KEY'
WHERE tc.table_schema='public';
```
