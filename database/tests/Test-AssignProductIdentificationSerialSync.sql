/*
    Test - AssignProductIdentificationData copies a new UUT serial to the device's own table rows (MBA-855)
    Run on STAGE with Invoke-CalibratorStageSqlFile.ps1. Every scenario runs in its own transaction that
    is rolled back, so nothing is kept. Anything other than 'PASS' in Result is a failure.

    Setup inside each transaction: a device with at least three live sensor table rows, rearranged as
        row 1  the device's own MABA No      -> must follow the device's serial
        row 2  no MABA No                    -> must follow the device's serial
        row 3  another device's MABA No      -> must keep its own serial
    Scenarios, each sending only what page 1 or the sensor table sends for a serial change:
        S1  a new serial                                  -> rows 1 and 2 take it, row 3 does not
        S2  the same serial with only the letter case changed -> rows 1 and 2 take the new case
        S3  no serial at all (e.g. the logger step saving the chamber volume) -> no row changes
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

-- Any device with a MABA No and at least three live rows; ids differ between servers, so look one up.
DECLARE @Item INT = (
    SELECT TOP 1 p.OrderDetailsItemId
    FROM dbo.MeasurmentPointsToOrderDetailsItems p
    JOIN dbo.OrderDetailsItems i ON i.OrderDetailsItemId = p.OrderDetailsItemId
    WHERE p.IsDeleted = 0 AND i.MbaReportNumber LIKE '%/%'
    GROUP BY p.OrderDetailsItemId
    HAVING COUNT(*) >= 3
    ORDER BY p.OrderDetailsItemId DESC);
DECLARE @OrderDetailId INT = (SELECT OrderDetailId FROM dbo.OrderDetailsItems WHERE OrderDetailsItemId = @Item);
DECLARE @DeviceMaba NVARCHAR(100) = (SELECT LTRIM(RTRIM(MbaReportNumber)) FROM dbo.OrderDetailsItems WHERE OrderDetailsItemId = @Item);
DECLARE @Email NVARCHAR(255) = (SELECT TOP 1 Email FROM dbo.Users WHERE Email LIKE 'ezequiel_lo%' ORDER BY ID);

DECLARE @Row1 INT, @Row2 INT, @Row3 INT;
SELECT @Row1 = MIN(MeasurmentPointsToOrderDetailsItemId) FROM dbo.MeasurmentPointsToOrderDetailsItems WHERE OrderDetailsItemId = @Item AND IsDeleted = 0;
SELECT @Row2 = MIN(MeasurmentPointsToOrderDetailsItemId) FROM dbo.MeasurmentPointsToOrderDetailsItems WHERE OrderDetailsItemId = @Item AND IsDeleted = 0 AND MeasurmentPointsToOrderDetailsItemId > @Row1;
SELECT @Row3 = MIN(MeasurmentPointsToOrderDetailsItemId) FROM dbo.MeasurmentPointsToOrderDetailsItems WHERE OrderDetailsItemId = @Item AND IsDeleted = 0 AND MeasurmentPointsToOrderDetailsItemId > @Row2;

DECLARE @Results TABLE (Item INT, Scenario NVARCHAR(60), Device NVARCHAR(100), Row1Own NVARCHAR(100), Row2NoMaba NVARCHAR(100), Row3Other NVARCHAR(100), Result NVARCHAR(200));
DECLARE @Ignore TABLE (OrderDetailsItemId INT);
DECLARE @S INT = 1;

WHILE @S <= 3
BEGIN
    BEGIN TRAN;

    UPDATE dbo.MeasurmentPointsToOrderDetailsItems
    SET MbaReportNumber = CASE MeasurmentPointsToOrderDetailsItemId WHEN @Row1 THEN @DeviceMaba WHEN @Row2 THEN NULL ELSE N'0000000/0' END,
        SerialNumber    = CASE MeasurmentPointsToOrderDetailsItemId WHEN @Row3 THEN N'OTHER-DEVICE-SN' ELSE N'Old-Sn' END
    WHERE MeasurmentPointsToOrderDetailsItemId IN (@Row1, @Row2, @Row3);
    UPDATE dbo.OrderDetailsItems SET SerialNumber = N'Old-Sn' WHERE OrderDetailsItemId = @Item;

    IF @S = 1
        INSERT @Ignore EXEC dbo.AssignProductIdentificationData @UserEmail = @Email, @OrderDetailId = @OrderDetailId, @OrderDetailsItemId = @Item, @SerialNumber = N'New-Sn-1';
    IF @S = 2
        INSERT @Ignore EXEC dbo.AssignProductIdentificationData @UserEmail = @Email, @OrderDetailId = @OrderDetailId, @OrderDetailsItemId = @Item, @SerialNumber = N'OLD-SN';
    IF @S = 3
        INSERT @Ignore EXEC dbo.AssignProductIdentificationData @UserEmail = @Email, @OrderDetailId = @OrderDetailId, @OrderDetailsItemId = @Item, @Volume = 1;

    DECLARE @Expected NVARCHAR(100) = CASE @S WHEN 1 THEN N'New-Sn-1' WHEN 2 THEN N'OLD-SN' ELSE N'Old-Sn' END;
    DECLARE @Dev NVARCHAR(100) = (SELECT SerialNumber FROM dbo.OrderDetailsItems WHERE OrderDetailsItemId = @Item);
    DECLARE @R1 NVARCHAR(100) = (SELECT SerialNumber FROM dbo.MeasurmentPointsToOrderDetailsItems WHERE MeasurmentPointsToOrderDetailsItemId = @Row1);
    DECLARE @R2 NVARCHAR(100) = (SELECT SerialNumber FROM dbo.MeasurmentPointsToOrderDetailsItems WHERE MeasurmentPointsToOrderDetailsItemId = @Row2);
    DECLARE @R3 NVARCHAR(100) = (SELECT SerialNumber FROM dbo.MeasurmentPointsToOrderDetailsItems WHERE MeasurmentPointsToOrderDetailsItemId = @Row3);

    INSERT @Results
    SELECT @Item,
           CASE @S WHEN 1 THEN N'S1: new serial' WHEN 2 THEN N'S2: letter case only' ELSE N'S3: no serial sent' END,
           @Dev, @R1, @R2, @R3,
           CASE
             WHEN @Dev COLLATE Latin1_General_BIN2 <> @Expected COLLATE Latin1_General_BIN2 THEN N'FAIL: device serial'
             WHEN @R1 COLLATE Latin1_General_BIN2 <> @Expected COLLATE Latin1_General_BIN2 THEN N'FAIL: row with the device''s MABA No'
             WHEN @R2 COLLATE Latin1_General_BIN2 <> @Expected COLLATE Latin1_General_BIN2 THEN N'FAIL: row with no MABA No'
             WHEN @R3 COLLATE Latin1_General_BIN2 <> N'OTHER-DEVICE-SN' THEN N'FAIL: row of another MABA No was changed'
             ELSE N'PASS'
           END;

    ROLLBACK;
    SET @S += 1;
END

SELECT * FROM @Results;
