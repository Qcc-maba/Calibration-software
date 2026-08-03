-- =============================================
-- Proc:        dbo.AssignCalibratorsToOrder
-- Jira:        MBA-156 (parent MBA-95 "Assign calibrator to the order")
--              Supersedes the original insert-only version authored under MABA-180
--              (Eduard Kudlaiev, 17/03/2025). Kept the SAME NAME + SAME PARAMETER
--              SIGNATURE so the existing app call site keeps working unchanged:
--              src/server/api/routers/orders/orders.ts -> orders.assignCalibrators
--              EXEC dbo.AssignCalibratorsToOrder @OrderNumber, @CalibratorIDs,
--                   @StartDate, @Note, @LoggedInUserEmail, @CarId
--
-- Description: Saves ("places") one or more calibrators onto an order's work plan
--              for a given assignment date / car. MBA-156 asks for an INSERT/UPDATE
--              UPSERT (the original SP only ever inserted and silently skipped rows
--              that already existed, so a re-save could never re-activate a placement
--              that had been soft-deleted, nor refresh its audit columns).
--
--              A "placement" is one row in dbo.CalibratorsToWorkPlan. Its natural key
--              is (OrderWorkPlanId, CalibratorId, AssigmentDate, CarId): the same
--              calibrator legitimately gets several rows across different days/cars
--              (the app fires this SP once per car x date), so the upsert key MUST
--              include AssigmentDate and CarId, not just the calibrator.
--
-- Upsert semantics (per staged CalibratorId, for the resolved work plan):
--   * MATCH  -> row with the same natural key already exists:
--                UPDATE it -> re-activate (IsDeleted = 0), refresh UpdateUserID /
--                UpdatedDate. No duplicate row, no duplicate notification.
--   * NO MATCH -> INSERT a new placement (CreatedDate/IsDeleted fall to their column
--                defaults getdate()/0) and queue a "NewOrderNotification".
--
--   NULL-parameter matching is preserved from the original SP: a NULL @StartDate or
--   NULL @CarId acts as a wildcard when locating an existing row.
--
-- Params:
--   @OrderNumber        NCHAR(12)      order number -> resolves OrderWorkPlanId
--   @StartDate          DATETIME2(0)   assignment date (stored as DATE); NULL allowed
--   @CalibratorIDs      NVARCHAR(300)  CSV of active user ids, e.g. N'2,6,7,8'
--   @Note               NVARCHAR(255)  optional; when non-NULL overwrites work-plan Notes
--   @CarId              INT            optional car for this placement
--   @LoggedInUserEmail  NVARCHAR(100)  actor; resolved to UpdateUserID via GetSourceFilterByEmail
--
-- Output:      No result set. Rows affected in dbo.CalibratorsToWorkPlan
--              (+ dbo.CalibratorNotifications for newly inserted placements only).
--
-- Validation:  THROWs 51000 if any listed id is missing/inactive in dbo.Users
--              (unchanged from the original).
--
-- Review notes (Ariel / Ed):
--   1. Notifications now fire ONLY for genuinely NEW placements (the INSERT's OUTPUT),
--      not on every re-save. The old SP notified every calibrator in the list on every
--      call, producing duplicate "Order X was assigned" rows. Confirm this is desired.
--   2. Natural key treated as (WorkPlan, Calibrator, AssigmentDate, CarId). If business
--      rule is "one active placement per calibrator per order regardless of date/car",
--      the key should drop AssigmentDate/CarId - please confirm before deploy.
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[AssignCalibratorsToOrder]
    @OrderNumber        NCHAR(12),
    @StartDate          DATETIME2(0)  = NULL,
    @CalibratorIDs      NVARCHAR(300),
    @Note               NVARCHAR(255),
    @CarId              INT           = NULL,
    @LoggedInUserEmail  NVARCHAR(100) = NULL
--exec dbo.AssignCalibratorsToOrder @OrderNumber = N'LA25100557', @StartDate = '2025-03-17 16:23:00', @CalibratorIDs = '2,6,7,8', @Note = N'test record'
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @LoggedInUserId INT;
    DECLARE @SourceId       TINYINT;

    SELECT
         @LoggedInUserId = d.UserId
        ,@SourceId       = d.SourceId
    FROM dbo.GetSourceFilterByEmail(@LoggedInUserEmail) AS d;

    -- Normalise the assignment date once (column stores DATE precision).
    DECLARE @AssignDate DATE = CAST(@StartDate AS DATE);

    -- Stage the requested calibrator ids.
    DROP TABLE IF EXISTS #CalibratorIDs;
    CREATE TABLE #CalibratorIDs (CalibratorID INT PRIMARY KEY);

    INSERT #CalibratorIDs (CalibratorID)
    SELECT DISTINCT Value
    FROM dbo.ParseCSVToTable(@CalibratorIDs)
    WHERE Value > 0;

    -- Reject unknown / inactive calibrators (unchanged behaviour).
    IF EXISTS (
        SELECT 1
        FROM #CalibratorIDs AS u
        LEFT JOIN [dbo].[Users] AS ul ON u.CalibratorID = ul.ID
        WHERE ul.ID IS NULL OR ul.IsActive = 0
    )
        THROW 51000, 'Incorrect or inactive calibrators were found in list.', 1;

    DECLARE @WorkPlanId INT;

    SELECT @WorkPlanId = wp.OrderWorkPlanId
    FROM [dbo].[OrderWorkPlans] AS wp
    WHERE wp.OrderNumber = @OrderNumber;

    IF @WorkPlanId IS NULL
        THROW 51001, 'Order number was not found.', 1;

    -- Optional note overwrite (unchanged behaviour).
    UPDATE [dbo].[OrderWorkPlans]
    SET Notes = IIF(@Note IS NULL, Notes, @Note)
    WHERE OrderWorkPlanId = @WorkPlanId;

    BEGIN TRAN;

    -- ---- UPDATE side of the upsert -------------------------------------------
    -- Re-activate + refresh any placement that already matches the natural key.
    -- NULL @AssignDate / @CarId behave as wildcards, mirroring the original
    -- NOT EXISTS dedup predicate.
    UPDATE cwp
    SET  cwp.IsDeleted    = 0,
         cwp.UpdateUserID = @LoggedInUserId,
         cwp.UpdatedDate  = GETDATE(),
         cwp.CarId        = ISNULL(@CarId, cwp.CarId),
         cwp.AssigmentDate= ISNULL(@AssignDate, cwp.AssigmentDate)
    FROM dbo.CalibratorsToWorkPlan AS cwp
    JOIN #CalibratorIDs AS c ON c.CalibratorID = cwp.CalibratorId
    WHERE cwp.OrderWorkPlanId = @WorkPlanId
      AND (@AssignDate IS NULL OR cwp.AssigmentDate = @AssignDate)
      AND (@CarId      IS NULL OR cwp.CarId         = @CarId);

    -- ---- INSERT side of the upsert -------------------------------------------
    -- Insert placements that still have no matching row, capturing which
    -- calibrators were genuinely added so only they get notified.
    DECLARE @Inserted TABLE (CalibratorID INT);

    INSERT dbo.CalibratorsToWorkPlan
        (OrderWorkPlanId, CalibratorId, AssigmentDate, UpdateUserID, CarId)
    OUTPUT inserted.CalibratorId INTO @Inserted (CalibratorID)
    SELECT DISTINCT @WorkPlanId, c.CalibratorID, @AssignDate, @LoggedInUserId, @CarId
    FROM #CalibratorIDs AS c
    WHERE NOT EXISTS (
        SELECT 1
        FROM dbo.CalibratorsToWorkPlan AS cwp
        WHERE cwp.OrderWorkPlanId = @WorkPlanId
          AND cwp.CalibratorID    = c.CalibratorID
          AND (@AssignDate IS NULL OR cwp.AssigmentDate = @AssignDate)
          AND (@CarId      IS NULL OR cwp.CarId         = @CarId)
    );

    -- Notify only the calibrators that received a brand-new placement.
    INSERT INTO [dbo].[CalibratorNotifications]
        ([CalibratorId]
        ,[OrderWorkPlanId]
        ,[NotificationText]
        ,[CreatedDate]
        ,[CreateUserId]
        ,[IsDeleted]
        ,[NotificationTypeId])
    SELECT
         i.CalibratorID
        ,@WorkPlanId
        ,CONCAT('Order ', @OrderNumber, ' was assigned.')
        ,GETDATE()
        ,ISNULL(@LoggedInUserId, 0)
        ,0
        ,(SELECT StatusId FROM [dbo].[Statuses] WHERE StatusDescriptionENG = 'NewOrderNotification')
    FROM @Inserted AS i;

    COMMIT TRAN;
END
GO
