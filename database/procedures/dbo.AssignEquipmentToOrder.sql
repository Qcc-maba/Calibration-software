-- =============================================
-- Proc:        dbo.AssignEquipmentToOrder
-- Jira:        MBA-158 "Create a SP To save the equipment placement"
--              (parent MBA-89 "Assign equipment to the order")
-- Original:    Eduard Kudlaiev, 02/04/2025 (this is a reviewable CREATE OR ALTER
--              re-authoring of the live definition, with a header + SET NOCOUNT ON
--              hoisted above the first SELECT; logic is otherwise preserved).
--
-- Description: Saves ("upserts") the equipment placement for a single order. This is
--              the write behind api.equipment.assignEquipmentToOrder in the app
--              (external-calibrator "Assign equipment to order" pop-up, Save button).
--
--              Upsert strategy = replace-set: every currently-active placement row for
--              the order's work plan is soft-deleted (IsDeleted = 1), then the full
--              selected equipment set is re-inserted. Passing an empty @EquipmentIDs
--              therefore clears the order's placements.
--
-- Inputs:
--   @OrderID            NVARCHAR(100) - the ORDER NUMBER (OrderWorkPlans.OrderNumber,
--                                        e.g. 'SO25000153'), NOT the OrderWorkPlanId.
--   @EquipmentIDs       NVARCHAR(MAX) - CSV of MeasurementDevices.ID to place on the order.
--   @CheckDate          DATE          - assignment/placement date (AssigmentDate); nullable.
--   @LoggedInUserEmail  NVARCHAR(100) - caller; resolved to UserId + SourceId via
--                                        dbo.GetSourceFilterByEmail (audit stamp).
--   @CarId              INT           - optional car the equipment travels in; 0 -> NULL.
--
-- Output:      None (no result set). Raises error 51000 on validation failure.
--
-- Validation:  Every id in @EquipmentIDs must reference a MeasurementDevices row whose
--              status (Statuses.StatusDescriptionENG) is 'Available'; otherwise THROW 51000.
--
-- Side effects: writes dbo.MeasurementDevicesToOrderHeaders. AUTHORED ONLY - not executed.
--
-- OPEN QUESTIONS FOR REVIEWER:
--   1. Per-car scoping: the soft-delete clears ALL active rows for @OrderWorkPlanId
--      regardless of CarId, but the re-insert stamps only the single @CarId passed in.
--      When the app assigns equipment to more than one car on the same order (each Save
--      is a separate call), the later call wipes the earlier car's placement. If per-car
--      placements must coexist, the DELETE should be scoped
--      "AND (@CarId IS NULL OR CarId = NULLIF(@CarId,0))". Preserved as-is pending confirmation.
--   2. Concurrency: EquipmentAssignmentDialog fires one call per selected date via
--      Promise.all (parallel). Because each call does delete-all-then-insert on the same
--      work plan, concurrent calls race and can lose rows. If multi-date placement is a
--      real requirement, this SP should accept the date set (or the calls be serialized).
--   3. @OrderWorkPlanId is not validated: an unknown @OrderID yields NULL and the SP
--      silently inserts orphan rows (OrderWorkPlanId = NULL fails the NOT NULL column,
--      so it would error). Consider an explicit "order not found" THROW. Preserved as-is.
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[AssignEquipmentToOrder]
    @OrderID           NVARCHAR(100),
    @EquipmentIDs      NVARCHAR(MAX)  = '',
    @CheckDate         DATE           = NULL,
    @LoggedInUserEmail NVARCHAR(100)  = NULL,
    @CarId             INT            = NULL
/*
EXEC dbo.AssignEquipmentToOrder @OrderID = 'SO25000153', @EquipmentIDs = '578,579'
*/
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @LoggedInUserId INT;
    DECLARE @SourceId       TINYINT;

    SELECT
         @LoggedInUserId = d.UserId
        ,@SourceId       = d.SourceId
    FROM dbo.GetSourceFilterByEmail(@LoggedInUserEmail) AS d;

    DROP TABLE IF EXISTS #AssociatedEquipmentIDs;
    CREATE TABLE #AssociatedEquipmentIDs
    (
        EquipmentId INT
    );

    INSERT #AssociatedEquipmentIDs (EquipmentId)
    SELECT Value FROM dbo.ParseCSVToTable(@EquipmentIDs);

    --- Check equipment id's are valid and in an 'Available' state
    IF @EquipmentIDs IS NOT NULL AND EXISTS (
        SELECT 1
        FROM #AssociatedEquipmentIDs AS t
        JOIN [dbo].[MeasurementDevices] AS e ON e.ID = t.EquipmentId
        JOIN [dbo].[Statuses]           AS s ON e.MeasurementDeviceStatusId = s.StatusId
        WHERE s.StatusDescriptionENG <> 'Available'
    )
        THROW 51000, 'Incorrect or inactive equipment were found in list or equipment not in available state.', 1;

    DECLARE @OrderWorkPlanId INT;
    SELECT @OrderWorkPlanId = OrderWorkPlanId
    FROM [dbo].[OrderWorkPlans]
    WHERE OrderNumber = @OrderID;

    -- Replace-set upsert: clear the order's current placements, then re-insert the selection.
    UPDATE [dbo].[MeasurementDevicesToOrderHeaders]
    SET IsDeleted = 1, UpdateUserID = @LoggedInUserId
    WHERE OrderWorkPlanId = @OrderWorkPlanId;

    IF (SELECT COUNT(*) FROM #AssociatedEquipmentIDs WHERE EquipmentId > 0) >= 1
        INSERT [dbo].[MeasurementDevicesToOrderHeaders]
        (
            OrderWorkPlanId,
            MeasurementDeviceId,
            AssigmentDate,
            UpdateUserID,
            CarId
        )
        SELECT
             @OrderWorkPlanId
            ,aei.EquipmentId
            ,@CheckDate
            ,@LoggedInUserId
            ,NULLIF(@CarId, 0)
        FROM #AssociatedEquipmentIDs AS aei;
END
GO
