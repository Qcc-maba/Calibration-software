/*
    Test - AssignMeasurmentPointsToOrderDetailsItemsV2 writes back only the device's own rows (MBA-855)
    Run on STAGE with Invoke-CalibratorStageSqlFile.ps1. Every scenario runs in its own transaction that
    is rolled back, so nothing is kept. Expected:
      A: a row with another MABA No           -> device MABA No and serial unchanged
      B: a row with the device's MABA No      -> device serial follows that row
      C: a row with no MABA No                -> device serial follows that row
    Before the fix, A replaced the device's MABA No and serial with the other device's.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

-- Any device with a MABA No and at least two live rows; ids differ between servers, so look one up.
DECLARE @Item INT = (
    SELECT TOP 1 p.OrderDetailsItemId
    FROM dbo.MeasurmentPointsToOrderDetailsItems p
    JOIN dbo.OrderDetailsItems i ON i.OrderDetailsItemId = p.OrderDetailsItemId
    WHERE p.IsDeleted = 0 AND p.ChannelNumber IS NOT NULL AND i.MbaReportNumber LIKE '%/%'
    GROUP BY p.OrderDetailsItemId
    HAVING COUNT(*) >= 2
    ORDER BY p.OrderDetailsItemId DESC);
DECLARE @Email NVARCHAR(255) = (SELECT TOP 1 Email FROM dbo.Users WHERE Email LIKE 'ezequiel_lo%' ORDER BY ID);
DECLARE @DeviceMaba NVARCHAR(100) = (SELECT MbaReportNumber FROM dbo.OrderDetailsItems WHERE OrderDetailsItemId = @Item);
DECLARE @SecondRow INT = (SELECT MAX(MeasurmentPointsToOrderDetailsItemId) FROM dbo.MeasurmentPointsToOrderDetailsItems WHERE OrderDetailsItemId = @Item AND IsDeleted = 0);
DECLARE @Results TABLE (Item INT, Scenario NVARCHAR(60), DeviceMaba NVARCHAR(100), DeviceSerial NVARCHAR(100));
DECLARE @Cases TABLE (Id INT, Scenario NVARCHAR(60), RowMaba NVARCHAR(100), RowSerial NVARCHAR(100));
INSERT @Cases VALUES
 (1, N'A: row with another MABA No', N'0000000/0', N'AAA-OTHER-SN'),
 (2, N'B: row with the device''s MABA No', @DeviceMaba, N'NEW-OWN-SN'),
 (3, N'C: row with no MABA No', NULL, N'NEW-EMPTY-SN');

INSERT @Results SELECT @Item, N'before', MbaReportNumber, SerialNumber FROM dbo.OrderDetailsItems WHERE OrderDetailsItemId = @Item;

DECLARE @Id INT = 1, @Scenario NVARCHAR(60), @RowMaba NVARCHAR(100), @RowSerial NVARCHAR(100), @Points NVARCHAR(MAX), @Data NVARCHAR(MAX);
WHILE @Id <= 3
BEGIN
    SELECT @Scenario = Scenario, @RowMaba = RowMaba, @RowSerial = RowSerial FROM @Cases WHERE Id = @Id;
    BEGIN TRAN;
    SET @Points = (
        SELECT p.MeasurmentPointsToOrderDetailsItemId, p.MeasurmentPointName, p.MeasurmentPointCoordX, p.MeasurmentPointCoordY,
               p.SensorMeasurementDeviceId, p.ChannelNumber, p.MasterValue, p.MasterValueUnitId, p.AdditionalValue,
               p.AdditionalValueUnitId, p.StabilityValue, p.UncertancyValue, p.MeasuredValue, p.MeasuredValueUnitId,
               CASE WHEN p.MeasurmentPointsToOrderDetailsItemId = @SecondRow THEN @RowSerial ELSE p.SerialNumber END AS SerialNumber,
               CASE WHEN p.MeasurmentPointsToOrderDetailsItemId = @SecondRow THEN @RowMaba ELSE p.MbaReportNumber END AS MbaReportNumber,
               p.Tolerance, p.NominalValue
        FROM dbo.MeasurmentPointsToOrderDetailsItems p
        WHERE p.OrderDetailsItemId = @Item AND p.IsDeleted = 0
        FOR JSON PATH, INCLUDE_NULL_VALUES);
    SET @Data = N'[{"OrderDetailsItemId":' + CAST(@Item AS NVARCHAR(20)) + N',"Points":' + @Points + N'}]';
    EXEC dbo.AssignMeasurmentPointsToOrderDetailsItemsV2 @LoggedInUserEmail = @Email, @Data = @Data;
    INSERT @Results SELECT @Item, @Scenario, MbaReportNumber, SerialNumber FROM dbo.OrderDetailsItems WHERE OrderDetailsItemId = @Item;
    ROLLBACK;
    SET @Id += 1;
END

INSERT @Results SELECT @Item, N'after all rollbacks', MbaReportNumber, SerialNumber FROM dbo.OrderDetailsItems WHERE OrderDetailsItemId = @Item;
DECLARE @BeforeMaba NVARCHAR(100), @BeforeSerial NVARCHAR(100);
SELECT @BeforeMaba = DeviceMaba, @BeforeSerial = DeviceSerial FROM @Results WHERE Scenario = N'before';

SELECT r.Item, r.Scenario, r.DeviceMaba, r.DeviceSerial,
       CASE
         WHEN ISNULL(r.DeviceMaba, N'') <> ISNULL(@BeforeMaba, N'') THEN N'FAIL: device MABA No changed'
         WHEN r.Scenario LIKE N'B:%' AND r.DeviceSerial <> N'NEW-OWN-SN' THEN N'FAIL: serial did not follow the device''s row'
         WHEN r.Scenario LIKE N'C:%' AND r.DeviceSerial <> N'NEW-EMPTY-SN' THEN N'FAIL: serial did not follow the row with no MABA No'
         WHEN r.Scenario NOT LIKE N'[BC]:%' AND ISNULL(r.DeviceSerial, N'') <> ISNULL(@BeforeSerial, N'') THEN N'FAIL: device serial changed'
         ELSE N'PASS'
       END AS Result
FROM @Results r;
