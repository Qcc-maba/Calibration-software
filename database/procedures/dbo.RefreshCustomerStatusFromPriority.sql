/*
    dbo.RefreshCustomerStatusFromPriority
    ---------------------------------------------------------------------------------------------
    Copies Priority's own "customer is dead" flag into dbo.Customers.IsInactiveInSource.

    Priority holds it as CUSTOMERS.CUSTSTAT, resolved through CUSTSTATS.INACTIVE = 'Y'
    (-5 לא פעיל, -4 מוגבל, -3 אזהרת חסימה, -2 פעיל, -1 זמני). 1,535 of the 10,515 customers there
    are flagged inactive, and until this procedure existed none of that reached us: every one of
    them read as a live customer here.

    Why not the staging pipeline. stg.stg_Customers has no status column at all, so the flag is
    already gone before stg.MergeCustomersData runs, and the package that fills staging is SSIS -
    outside this database. Reading Priority directly over the linked server keeps the fix in one
    place and leaves the existing pipeline untouched. Same approach as
    dbo.RefreshCustomerRemarksFromPriority and dbo.RefreshPackingDataFromPriority.

    OPENQUERY so the join to CUSTSTATS runs on the Priority side rather than dragging the whole
    CUSTOMERS table across the link.

    Scope is SourceId = 1 (MABA) only. SEPHARM customers do not come from amaba and are left alone
    rather than being silently marked active by a source that knows nothing about them.

    Only rows whose flag actually differs are written, so a second run is a no-op. Run with
    @Apply = 0 first: it reports what would change and touches nothing.
*/
CREATE OR ALTER PROCEDURE dbo.RefreshCustomerStatusFromPriority
    @Apply BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    CREATE TABLE #Src (CUST INT PRIMARY KEY, Inactive BIT NOT NULL);

    INSERT INTO #Src (CUST, Inactive)
    SELECT CUST, Inactive
    FROM OPENQUERY([31.168.173.93], '
        SELECT C.CUST,
               CASE WHEN S.INACTIVE = ''Y'' THEN 1 ELSE 0 END AS Inactive
        FROM amaba.dbo.CUSTOMERS C
        LEFT JOIN amaba.dbo.CUSTSTATS S ON S.CUSTSTAT = C.CUSTSTAT');

    SELECT c.CustomerId, c.CustomerCode, c.CustomerName,
           c.IsInactiveInSource AS Current_, s.Inactive AS New_
    INTO #Diff
    FROM dbo.Customers AS c
    INNER JOIN #Src AS s ON s.CUST = c.CustomerIdFromSource
    WHERE c.SourceId = 1
      AND c.IsInactiveInSource <> s.Inactive;

    SELECT (SELECT COUNT(*) FROM dbo.Customers WHERE SourceId = 1)              AS MabaCustomers,
           (SELECT COUNT(*) FROM #Src)                                          AS FoundInPriority,
           (SELECT COUNT(*) FROM #Diff)                                         AS WouldChange,
           (SELECT COUNT(*) FROM #Diff WHERE New_ = 1)                          AS WouldFlagInactive,
           (SELECT COUNT(*) FROM #Diff WHERE New_ = 0)                          AS WouldFlagActive;

    IF @Apply = 1
    BEGIN
        UPDATE c
            SET c.IsInactiveInSource = d.New_
        FROM dbo.Customers AS c
        INNER JOIN #Diff AS d ON d.CustomerId = c.CustomerId;

        SELECT @@ROWCOUNT AS RowsUpdated;
    END
    ELSE
    BEGIN
        /* Dry run - show the first rows that would change, newest-looking first. */
        SELECT TOP (50) CustomerId, CustomerCode, CustomerName, Current_, New_
        FROM #Diff
        ORDER BY New_ DESC, CustomerCode;
    END

    DROP TABLE #Diff;
    DROP TABLE #Src;
END
