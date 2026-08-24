/*
    dbo.GetCalibrationReportFiles
    -----------------------------
    The calibration reports currently valid for a device, or for every device on one order.

    Parameters (exactly one must be supplied):
      @OrderDetailsItemId INT = NULL   -- one device; what the report popup opens with
      @OrderWorkPlanId    INT = NULL   -- the whole screen in one call, so the device grid does
                                          not fire one query per card

    Returns one row per VARIANT, each at its highest UpdateLevel:

      OrderDetailsItemId, CalibrationReportFileId, MbaReportNumber,
      Variant          -- '' | 'a' | 'b' ...  a domain-split sibling; all are valid together
      UpdateLevel      -- 0 | 1 | 2 ...       the winning re-issue for that variant
      SourceKind       -- 1 app · 2 Tomax archive · 3 manually linked
      StorageKey       -- S3 key to presign
      IsConsolidated, CoversFrom, CoversTo
      FileSize, ArchiveModifiedAt, SyncedAt

    Why one row per variant and not one row overall: 'a'/'b'/'c' are separate reports issued to
    split measurement domains, not versions of each other — returning only one would hide the
    rest. 'u1'/'u2' ARE versions, and the highest supersedes the others. See the header comment
    on dbo.CalibrationReportFile.

    Read-only.
*/
/* Matches the SET options dbo.CalibrationReportFile was created under — see that file's header. */
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

CREATE OR ALTER PROCEDURE dbo.GetCalibrationReportFiles
    @OrderDetailsItemId INT = NULL,
    @OrderWorkPlanId    INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @OrderDetailsItemId IS NULL AND @OrderWorkPlanId IS NULL
        RETURN;

    /* The devices in scope. Resolved first so the ranking below runs over a small set rather
       than the whole table. */
    DROP TABLE IF EXISTS #Items;
    CREATE TABLE #Items (OrderDetailsItemId INT PRIMARY KEY);

    IF @OrderDetailsItemId IS NOT NULL
    BEGIN
        INSERT #Items (OrderDetailsItemId) VALUES (@OrderDetailsItemId);
    END
    ELSE
    BEGIN
        INSERT #Items (OrderDetailsItemId)
        SELECT DISTINCT itm.OrderDetailsItemId
        FROM dbo.OrderDetailsItems AS itm
        JOIN dbo.OrderDetails      AS od ON od.OrderDetailId = itm.OrderDetailId
        WHERE od.OrderWorkPlanId = @OrderWorkPlanId
          AND itm.IsDeleted = 0
          AND od.IsDeleted  = 0;
    END

    SELECT
         f.OrderDetailsItemId
        ,f.CalibrationReportFileId
        ,f.MbaReportNumber
        ,f.Variant
        ,f.UpdateLevel
        ,f.SourceKind
        ,f.StorageKey
        ,f.IsConsolidated
        ,f.CoversFrom
        ,f.CoversTo
        ,f.FileSize
        ,f.ArchiveModifiedAt
        ,f.SyncedAt
    FROM
    (
        SELECT
             f.*
            ,ROW_NUMBER() OVER (
                 PARTITION BY f.OrderDetailsItemId, f.Variant
                 ORDER BY f.UpdateLevel DESC, f.SyncedAt DESC, f.CalibrationReportFileId DESC
             ) AS RevisionRank
        FROM dbo.CalibrationReportFile AS f
        JOIN #Items AS i ON i.OrderDetailsItemId = f.OrderDetailsItemId
        WHERE f.IsDeleted = 0
    ) AS f
    WHERE f.RevisionRank = 1
    ORDER BY f.OrderDetailsItemId, f.Variant;
END
GO
