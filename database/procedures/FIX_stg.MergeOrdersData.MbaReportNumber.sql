/*
    FIX — stg.MergeOrdersData stops wiping OrderDetailsItems.MbaReportNumber   (PROD only)
    =====================================================================================

    THE BUG
    -------
    In the OrderDetailsItems MERGE, the source column is hard-coded to NULL:

        ,NULL AS [MbaReportNumber]          <-- line ~253 of the PROD definition

    and the matched branch assigns it straight back:

        ,dest.[MbaReportNumber] = source.[MbaReportNumber]

    The WHEN MATCHED predicate is a long OR chain that includes

        OR COALESCE(dest.[Doc],0) = source.[Doc]

    and the MERGE's ON clause already requires `source.[Doc] = dest.[Doc]`. That OR term is
    therefore ALWAYS TRUE, so the matched branch fires for every matched row — there is no
    "only when something changed" guard in practice.

    Net effect: every hourly sync actively erases MbaReportNumber for every item inside the
    sync window. Measured on CalibratorProd — 5 of 6,800 items hold a report number, and those
    five were written by the app, not by the sync. It is not that the value never arrives; it
    arrives and is then deleted.

    Because of this, a backfill run against PROD without this fix would be progressively wiped
    again, order by order, as each one re-enters the sync window. Apply this FIRST.

    THE FIX
    -------
    Pass the value the source view already carries. `stg.stg_Orders.MbaReportNumber` is fed from
    `amaba.dbo.vwGetOrders_WorkPlan_Full_new`, which selects it as

        mbad.MBANUM AS MbaReportNumber          -- mbad = amaba.dbo.MBA_DOCUMENTS

    so the correct value is already sitting in the staging table, unused.

        -    ,NULL AS [MbaReportNumber]
        +    ,o.[MbaReportNumber]

    RISK
    ----
    Low. This is not a new idea being tried on production: the STAGE database (`Calibrator`) has
    been running this exact line for some time, and there 3,622 of 3,726 items (97.2%) carry a
    correct report number with no reported side effects. The change makes PROD match STAGE.

    One consequence worth stating plainly: for an item whose row is present in the current
    stg_Orders window, Priority becomes the owner of MbaReportNumber and will overwrite what is
    in the table. That is the intended direction for archive-sourced reports. Report numbers
    minted by the calibration wizard live on items that Priority also knows about, so if the two
    ever disagree, Priority wins. If that turns out to be wrong for wizard-created reports, the
    assignment needs a guard:

        ,dest.[MbaReportNumber] = COALESCE(NULLIF(source.[MbaReportNumber], N''), dest.[MbaReportNumber])

    HOW TO APPLY
    ------------
    This file is intentionally NOT an executable ALTER. stg.MergeOrdersData is ~15,500 characters
    of production sync logic and must not be re-deployed from a partial copy. Instead:

      1. Script the CURRENT definition out of the target database:
             SELECT m.definition FROM sys.sql_modules m
             JOIN sys.objects o ON o.object_id = m.object_id
             WHERE o.name = 'MergeOrdersData';
      2. Change the single line inside the OrderDetailsItems MERGE source SELECT:
             NULL AS [MbaReportNumber]   ->   o.[MbaReportNumber]
         (Do NOT touch the identical-looking line in the OrderDetails MERGE, if present.)
      3. Diff the result against STAGE's definition — the two should now differ only in
         whatever else legitimately differs between the environments.
      4. Deploy as CREATE OR ALTER, then run the verification below after the next sync cycle.

    VERIFICATION (run before, and again ~1 hour after, deployment)
*/
SELECT
     COUNT(*)                                                                  AS Items
    ,SUM(CASE WHEN NULLIF(MbaReportNumber, N'') IS NOT NULL THEN 1 ELSE 0 END) AS WithReportNumber
    ,CAST(100.0 * SUM(CASE WHEN NULLIF(MbaReportNumber, N'') IS NOT NULL THEN 1 ELSE 0 END)
          / NULLIF(COUNT(*), 0) AS DECIMAL(5, 1))                              AS PctWithReportNumber
FROM dbo.OrderDetailsItems
WHERE IsDeleted = 0;
GO
