/*
    dbo.MeasurmentPointsToCalibrationCycles                                                    MBA-999
    ---------------------------------------------------------------------------------------------
    The measurement points placed on a calibration cycle's chamber diagram: one row per point, with
    its position on the diagram (MeasurmentPointCoordX/Y), the sensor and channel that read it, and
    the values recorded for it. Written by dbo.AddCalibrationCycle / dbo.AssignMeasurmentPointsToCalibrationCycle,
    soft-deleted together with its cycle by dbo.DeleteCalibrationCycle.

    The table existed on both servers without a file in git. It was written down on 2026-10-25 for
    MBA-999, from the STAGE definition, after the 31/08 production package was found to have created
    it without the foreign key to its cycle. PROD got the key from
    database/deploy-prod/10-MBA-999-cache-and-cycle-constraints.sql (0 orphan rows of 52 at the time).

    The key is ON DELETE CASCADE, as on STAGE. Cycles are only ever soft-deleted (IsDeleted = 1), so the
    cascade does not fire in normal use; it only stops a hard delete from leaving points behind.
    The column names keep the schema's historical spelling ("Measurment", "Uncertancy").
*/
IF OBJECT_ID('dbo.MeasurmentPointsToCalibrationCycles', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.MeasurmentPointsToCalibrationCycles
    (
        MeasurmentPointsToCalibrationCycleId INT IDENTITY(1,1) NOT NULL,
        OrderDetailsItemId                   INT               NOT NULL,
        CalibrationCycleStartDate            DATETIME2(0)      NOT NULL,
        SensorMeasurementDeviceId            INT               NOT NULL,
        MeasurmentPointName                  NVARCHAR(200)     NOT NULL,
        MeasurmentPointCoordX                DECIMAL(10,4)     NOT NULL,
        MeasurmentPointCoordY                DECIMAL(10,4)     NOT NULL,
        ChannelNumber                        INT               NOT NULL,
        CreateDate                           DATETIME2(0)      NOT NULL
            CONSTRAINT DF_MeasurmentPointsToCalibrationCycles_CreateDate DEFAULT (GETDATE()),
        UpdatedDate                          DATETIME2(0)      NULL,
        UpdateUserID                         INT               NULL,
        IsDeleted                            BIT               NOT NULL
            CONSTRAINT DF_MeasurmentPointsToCalibrationCycles_IsDeleted DEFAULT (0),
        MasterValue                          DECIMAL(18,6)     NULL,
        MasterValueUnitId                    INT               NULL,
        AdditionalValue                      DECIMAL(10,4)     NULL,
        AdditionalValueUnitId                INT               NULL,
        StabilityValue                       DECIMAL(10,4)     NULL,
        UncertancyValue                      DECIMAL(10,4)     NULL,
        MeasuredValue                        DECIMAL(10,4)     NULL,
        MeasuredValueUnitId                  INT               NULL,

        CONSTRAINT PK_MeasurmentPointsToCalibrationCycles PRIMARY KEY CLUSTERED
            (OrderDetailsItemId, CalibrationCycleStartDate, SensorMeasurementDeviceId, ChannelNumber,
             MeasurmentPointsToCalibrationCycleId),
        CONSTRAINT FK_MeasurmentPointsToCalibrationCycles_CalibrationCycles
            FOREIGN KEY (OrderDetailsItemId, CalibrationCycleStartDate)
            REFERENCES dbo.CalibrationCycles (OrderDetailsItemId, CalibrationCycleStartDate)
            ON DELETE CASCADE
    );
END
GO
