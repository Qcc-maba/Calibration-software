-- =============================================
-- Proc:        dbo.ApplyPartFamilyCategories
-- Jira:        MBA-882 / MBA-666 — derive the device category from the Priority family
--
-- Rewrites OrderDetails.MainCategoryId / SecondaryCategoryId from dbo.PartFamilyCategoryMap,
-- resolved through dbo.CrmPartInfo by CATALOG NUMBER (OrderDetails.PART is unreliable — see
-- dbo.RefreshCrmTextCache). Replaces the per-order-line value that came from Priority's
-- stg_Orders.MainCategorySourceId, which is inconsistent for the same catalog number and NULL most
-- of the time.
--
-- Rules, in order:
--   * family mapped to a discipline      -> set MainCategoryId (+ SecondaryCategoryId when the map
--                                           gives one; a secondary is only ever a temperature
--                                           sub-type, so it is NULL for everything else)
--   * IsCalibrationItem = 0              -> clear both (נסיעות / הדרכה / שרותי איכות are not devices)
--   * NeedsReview = 1, or no family      -> LEAVE UNTOUCHED. Never guess.
--
-- Reversible: the first run copies the current values into dbo.OrderDetailsCategoryBackup before
-- changing anything. That table is written once and never overwritten, so it always holds the
-- pre-derivation state.
--
-- Called at the end of stg.MergeOrdersData, because that sync writes MainCategoryId back from
-- staging for the ~1,073 rows in its rolling window and would otherwise undo this on those rows.
--
-- @WhatIf = 1 reports what would change without touching anything.
-- =============================================
CREATE OR ALTER PROCEDURE dbo.ApplyPartFamilyCategories
    @WhatIf BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    /* NOT keyed on OrderDetailId: it is not unique in dbo.OrderDetails. Measured on STAGE —
       4,262 rows but 4,261 distinct ids, because OrderDetailId 58 exists twice, on work plans 13
       and 14 with different catalog numbers. That single duplicate also makes
       OrderDetailsItems.OrderDetailId = 58 ambiguous, which is why the same item shows up under
       two different orders. Reported separately; this proc just has to survive it. */
    IF OBJECT_ID('dbo.OrderDetailsCategoryBackup') IS NULL
    BEGIN
        CREATE TABLE dbo.OrderDetailsCategoryBackup(
             OrderDetailId       INT NOT NULL
            ,MainCategoryId      INT NULL
            ,SecondaryCategoryId INT NULL
            ,CapturedAt          DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME());
        CREATE INDEX IX_OrderDetailsCategoryBackup_OrderDetailId
            ON dbo.OrderDetailsCategoryBackup(OrderDetailId);
    END

    -- capture anything not captured yet, so the pre-derivation state is always recoverable
    INSERT dbo.OrderDetailsCategoryBackup(OrderDetailId, MainCategoryId, SecondaryCategoryId)
    SELECT DISTINCT od.OrderDetailId, od.MainCategoryId, od.SecondaryCategoryId
    FROM dbo.OrderDetails AS od
    /* Key the dedup on OrderDetailId ALONE, not on the values. Keying it on
       (id, main, secondary) meant that once this proc had changed a row, the next run saw a triple
       it had not captured and stored the POST-change state as another backup row — so the table
       accumulated both states and a restore became ambiguous. A row is captured once, ever, and
       that capture is by definition the pre-derivation state. */
    WHERE NOT EXISTS (SELECT 1 FROM dbo.OrderDetailsCategoryBackup b WHERE b.OrderDetailId = od.OrderDetailId);

    ;WITH target AS (
        SELECT od.OrderDetailId,
               od.MainCategoryId      AS CurMain,
               od.SecondaryCategoryId AS CurSec,
               CASE WHEN m.IsCalibrationItem = 0 THEN NULL ELSE m.MainCategoryId      END AS NewMain,
               CASE WHEN m.IsCalibrationItem = 0 THEN NULL ELSE m.SecondaryCategoryId END AS NewSec
        FROM dbo.OrderDetails AS od
        JOIN dbo.CrmPartInfo AS c ON c.PartName = od.PartName
        JOIN dbo.PartFamilyCategoryMap AS m ON m.FamilyId = c.FamilyId
        WHERE ISNULL(od.IsDeleted, 0) = 0
          AND m.NeedsReview = 0                       -- never touch what a human still has to decide
          AND (m.MainCategoryId IS NOT NULL OR m.IsCalibrationItem = 0)
    )
    SELECT SUM(CASE WHEN ISNULL(CurMain,-1) <> ISNULL(NewMain,-1)
                      OR ISNULL(CurSec,-1)  <> ISNULL(NewSec,-1)  THEN 1 ELSE 0 END) AS rows_to_change,
           SUM(CASE WHEN CurMain IS NULL AND NewMain IS NOT NULL   THEN 1 ELSE 0 END) AS filling_a_blank,
           SUM(CASE WHEN CurMain IS NOT NULL AND NewMain IS NOT NULL
                     AND CurMain <> NewMain                        THEN 1 ELSE 0 END) AS correcting_a_wrong_one,
           SUM(CASE WHEN CurMain IS NOT NULL AND NewMain IS NULL    THEN 1 ELSE 0 END) AS clearing_a_non_device,
           COUNT(*) AS rows_considered
    FROM target;

    IF @WhatIf = 1 RETURN;

    UPDATE od
       SET od.MainCategoryId      = CASE WHEN m.IsCalibrationItem = 0 THEN NULL ELSE m.MainCategoryId      END,
           od.SecondaryCategoryId = CASE WHEN m.IsCalibrationItem = 0 THEN NULL ELSE m.SecondaryCategoryId END
    FROM dbo.OrderDetails AS od
    JOIN dbo.CrmPartInfo AS c ON c.PartName = od.PartName
    JOIN dbo.PartFamilyCategoryMap AS m ON m.FamilyId = c.FamilyId
    WHERE ISNULL(od.IsDeleted, 0) = 0
      AND m.NeedsReview = 0
      AND (m.MainCategoryId IS NOT NULL OR m.IsCalibrationItem = 0)
      AND (ISNULL(od.MainCategoryId, -1)      <> ISNULL(CASE WHEN m.IsCalibrationItem = 0 THEN NULL ELSE m.MainCategoryId      END, -1)
        OR ISNULL(od.SecondaryCategoryId, -1) <> ISNULL(CASE WHEN m.IsCalibrationItem = 0 THEN NULL ELSE m.SecondaryCategoryId END, -1));
END
GO
