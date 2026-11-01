/*
    dbo.GetCalibrationRemarksLock                                                          MBA-848
    ---------------------------------------------------------------------------------------------
    Whether the report's remarks are still editable: one row, IsLocked + RemarksLockedDate. Needed
    because dbo.GetCalibrationRemarks returns nothing for a report with no remarks, and the screen
    still has to know whether to offer adding one.
*/
CREATE OR ALTER PROCEDURE dbo.GetCalibrationRemarksLock
    @OrderDetailsItemId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT OrderDetailsItemId = @OrderDetailsItemId,
           IsLocked           = CAST(CASE WHEN MAX(RemarksLockedDate) IS NOT NULL THEN 1 ELSE 0 END AS BIT),
           RemarksLockedDate  = MAX(RemarksLockedDate)
    FROM dbo.OrderDetailsItems
    WHERE OrderDetailsItemId = @OrderDetailsItemId;
END;
GO
