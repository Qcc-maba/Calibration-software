-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 27/02/2026
-- Description:	Without OrderDetailsItemId — seeds 2 mock rows; with OrderDetailsItemId — updates the row (TODO).
-- Column mapping → TSensorTableRow (SensorsTable):
--   Id, MbaReportNumber→orderNumber, SerialNumber→uutSerialNumber, ShortNameHe→unit,
--   ChannelNumber→channel, MabaID→masterSensorId, NominalValue→masterValue, Tolerance→tolerance,
--   MasterAfterOffset_mock→masterAfterOffset, MeasuredValue_mock→measuredValue,
--   AdditionalMeasuredValue_mock→additionalMeasuredValue, Deviation_mock→deviation,
--   PercentTolerance_mock→percentTolerance, Uncertainty_mock→uncertainty,
--   Drift_mock→drift, Stability_mock→stability, OffsetBefore_mock→offsetBefore, OffsetAfter_mock→offsetAfter.
-- JiraLink:
-- =============================================
CREATE OR ALTER PROCEDURE dbo.SetCalibrationValuesForOrderDetailItem
    @OrderDetailId              INT,
    @OrderDetailsItemId         INT            = NULL,
    @MbaReportNumber            NVARCHAR(50)   = NULL,
    @SerialNumber               NVARCHAR(100)  = NULL,
    @MeasurementUnitId          INT            = NULL,
    @ChannelNumber              INT            = NULL,
    @SensorMeasurementDeviceId  INT            = NULL,
    @Tolerance                  DECIMAL(10,4)  = NULL,
    @NominalValue               DECIMAL(18,6)  = NULL,
    @MasterAfterOffset_mock     DECIMAL(18,6)  = NULL,
    @MeasuredValue_mock         DECIMAL(18,6)  = NULL,
    @AdditionalMeasuredValue_mock DECIMAL(18,6) = NULL,
    @Deviation_mock              DECIMAL(18,6)  = NULL,
    @PercentTolerance_mock      DECIMAL(10,4)  = NULL,
    @Uncertainty_mock            DECIMAL(10,4)  = NULL,
    @Drift_mock                  DECIMAL(10,2)  = NULL,
    @Stability_mock              DECIMAL(10,2)  = NULL,
    @OffsetBefore_mock           DECIMAL(18,6)  = NULL,
    @OffsetAfter_mock            DECIMAL(18,6)  = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @OrderDetailsItemId IS NULL
    BEGIN
        DECLARE @InsertedIds TABLE (OrderDetailsItemId INT);
        DECLARE @Id1 INT, @Id2 INT;

        INSERT INTO [dbo].[OrderDetailsItems] ([OrderDetailId], [MbaReportNumber], [SerialNumber], [MeasurementUnitId])
        OUTPUT inserted.[OrderDetailsItemId] INTO @InsertedIds
        VALUES
            (@OrderDetailId, N'24103693/008', N'8NCIU48N', 1),
            (@OrderDetailId, N'24103693/009', N'8NCIU48N', 1);

        SELECT @Id1 = MIN(OrderDetailsItemId), @Id2 = MAX(OrderDetailsItemId) FROM @InsertedIds;

        INSERT INTO [dbo].[MeasurmentPointsToOrderDetailsItems] ([OrderDetailsItemId], [ChannelNumber], [SensorMeasurementDeviceId], [IsDeleted])
        VALUES (@Id1, 1, 1, 0), (@Id2, 2, 1, 0);

        INSERT INTO [dbo].[CalibrationEnvironmentalConditions] ([OrderDetailsItemId], [Tolerance], [NominalValue], [IsDeleted])
        VALUES (@Id1, 0.3, 149.169, 0), (@Id2, 0.3, 149.200, 0);

        SELECT OrderDetailsItemId FROM @InsertedIds ORDER BY OrderDetailsItemId;
    END
    ELSE
    BEGIN
        -- TODO: UPDATE OrderDetailsItems / MeasurmentPointsToOrderDetailsItems / CalibrationEnvironmentalConditions
        -- by @OrderDetailsItemId and passed parameters (@SerialNumber, @Tolerance, @NominalValue, *_mock, etc.)
    END
END
GO

-- Example calls:
-- EXEC dbo.SetCalibrationValuesForOrderDetailItem @OrderDetailId = 999;
-- EXEC dbo.SetCalibrationValuesForOrderDetailItem @OrderDetailId = 999, @OrderDetailsItemId = 123, @SerialNumber = N'NEW-SN', @Tolerance = 0.5;
