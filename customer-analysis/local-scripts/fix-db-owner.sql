-- מחזיר את הבעלות על כל האובייקטים ב-public לבעל ה-DB (אצלנו: qcc).
-- נדרש אחרי pg_restore --no-owner שרץ כ-postgres: הטבלאות נוצרות בבעלות postgres,
-- והאפליקציה שמתחברת כ-qcc מקבלת 42501 permission denied.
-- הרצה: psql -U postgres -h localhost -d qcc_analytics -f fix-db-owner.sql
DO $$
DECLARE
    dbowner text;
    r       record;
BEGIN
    SELECT pg_get_userbyid(datdba) INTO dbowner
    FROM pg_database WHERE datname = current_database();

    RAISE NOTICE 'reassigning public objects to %', dbowner;

    EXECUTE format('ALTER SCHEMA public OWNER TO %I', dbowner);

    FOR r IN SELECT c.relname, c.relkind
             FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
             WHERE n.nspname = 'public'
               AND c.relkind IN ('r', 'p', 'v', 'm', 'S')   -- table/partitioned/view/matview/sequence
               AND pg_get_userbyid(c.relowner) <> dbowner
    LOOP
        EXECUTE format(
            CASE r.relkind
                WHEN 'v' THEN 'ALTER VIEW public.%I OWNER TO %I'
                WHEN 'm' THEN 'ALTER MATERIALIZED VIEW public.%I OWNER TO %I'
                WHEN 'S' THEN 'ALTER SEQUENCE public.%I OWNER TO %I'
                ELSE          'ALTER TABLE public.%I OWNER TO %I'
            END, r.relname, dbowner);
    END LOOP;

    EXECUTE format('GRANT ALL ON SCHEMA public TO %I', dbowner);
    EXECUTE format('GRANT ALL ON ALL TABLES IN SCHEMA public TO %I', dbowner);
    EXECUTE format('GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO %I', dbowner);
END $$;

-- אימות: אמור להחזיר 0 שורות
SELECT c.relname, pg_get_userbyid(c.relowner) AS owner
FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public' AND c.relkind IN ('r','p','v','m','S')
  AND pg_get_userbyid(c.relowner) <> (SELECT pg_get_userbyid(datdba) FROM pg_database WHERE datname = current_database());
