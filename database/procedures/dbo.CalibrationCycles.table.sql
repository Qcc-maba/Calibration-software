/*
    dbo.CalibrationCycles                                                                  MBA-980
    ---------------------------------------------------------------------------------------------
    A chamber calibration's cycles: one row per cycle of a device on an order line. Cycles have no
    id; the key is (OrderDetailsItemId, CalibrationCycleStartDate), and the app moves a cycle to a
    new start time by copying it to the new key and soft-deleting the old row. Cycles are only ever
    soft-deleted (IsDeleted = 1).

    The table existed on both servers without a file in git. It was written down on 2026-11-10 for
    MBA-980 from the STAGE definition (local STAGE copy of 2026-11-02), because the release gate
    requires a table to be deployed from its .table.sql. The default constraints carry
    system-generated names on the servers; they are named here, and Compare-Schema.ps1 compares
    defaults by content, not name.

    The seven chamber-settings columns at the end are MBA-980's: on an existing table they are added
    by database/schema/dbo.CalibrationCycles.ChamberSettings.sql and their sign rules by
    database/constraints/CK_CalibrationCycles_ChamberSettings.sql. This file creates them only when
    it creates the table. The eight Summary columns after them (DisplayValue ... CalculationResolution)
    are added the same way by database/schema/dbo.CalibrationCycles.SummarySettings.sql, and their
    foreign key by database/constraints/FK_CalibrationCycles_ControllerTypeStatusId.sql and the
    resolutions' sign rule by database/constraints/CK_CalibrationCycles_SummarySettings.sql.

    The fourteen Secondary* columns after those are MBA-800's: the chamber's second measured value
    (RH) in a Temperature + RH cycle. On an existing table they are added by
    database/schema/dbo.CalibrationCycles.SecondaryValue.sql and their rules and unit key by
    database/constraints/CK_CalibrationCycles_SecondaryValue.sql.

    Written by dbo.AddCalibrationCycle (an upsert on the key), dbo.SaveCalibrationCycleSettings
    (the settings columns only), dbo.SaveCalibrationCycleSecondarySettings (the Secondary* columns
    only) and the app's inline updateCalibrationCycle (devices.ts);
    soft-deleted by dbo.DeleteCalibrationCycle.
*/
IF OBJECT_ID('dbo.CalibrationCycles', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.CalibrationCycles
    (
        OrderDetailsItemId            INT            NOT NULL,
        CalibrationCycleStartDate     DATETIME2(0)   NOT NULL,
        CalibrationCycleEndDate       DATETIME2(0)   NOT NULL,
        CalibrationCycleStatusId      INT            NULL,
        CreatedUserID                 INT            NOT NULL,
        CreatedDate                   DATETIME2(0)   NOT NULL
            CONSTRAINT DF_CalibrationCycles_CreatedDate DEFAULT (GETDATE()),
        UpdatedDate                   DATETIME2(0)   NULL,
        IsDeleted                     BIT            NOT NULL
            CONSTRAINT DF_CalibrationCycles_IsDeleted DEFAULT (0),
        UpdateUserID                  INT            NULL,
        CalibrationCycleName          NVARCHAR(200)  NULL,
        UnitId                        INT            NULL,
        TestedValue                   DECIMAL(18,6)  NULL,
        SpecificationReferenceIds     NVARCHAR(100)  NULL,
        CalibrationCycleNameStatusId  INT            NULL,
        ToleranceValue                DECIMAL(18,6)  NULL,
        ToleranceStart                DECIMAL(18,6)  NULL
            CONSTRAINT CK_CalibrationCycles_ToleranceStart CHECK (ToleranceStart <= 0),
        ToleranceEnd                  DECIMAL(18,6)  NULL
            CONSTRAINT CK_CalibrationCycles_ToleranceEnd CHECK (ToleranceEnd >= 0),
        Resolution                    DECIMAL(18,6)  NULL,
        Uncertainty                   DECIMAL(18,6)  NULL,
        StabilityThreshold            DECIMAL(18,6)  NULL
            CONSTRAINT CK_CalibrationCycles_StabilityThreshold CHECK (StabilityThreshold >= 0),
        UniformityThreshold           DECIMAL(18,6)  NULL
            CONSTRAINT CK_CalibrationCycles_UniformityThreshold CHECK (UniformityThreshold >= 0),
        DisplayValue                  DECIMAL(18,6)  NULL,
        DisplayResolution             DECIMAL(18,6)  NULL
            CONSTRAINT CK_CalibrationCycles_DisplayResolution CHECK (DisplayResolution >= 0),
        IsDisplayEnabled              BIT            NULL,
        IsTargetValueEnabled          BIT            NULL,
        ControllerTypeStatusId        INT            NULL
            CONSTRAINT FK_CalibrationCycles_ControllerTypeStatusId
                FOREIGN KEY REFERENCES dbo.Statuses (StatusId),
        ControllerManufacturer        NVARCHAR(100)  NULL,
        ControllerModel               NVARCHAR(100)  NULL,
        CalculationResolution         DECIMAL(18,6)  NULL
            CONSTRAINT CK_CalibrationCycles_CalculationResolution CHECK (CalculationResolution >= 0),
        SecondaryUnitId               INT            NULL
            CONSTRAINT FK_CalibrationCycles_SecondaryUnitId
                FOREIGN KEY REFERENCES dbo.MeasurementDeviceUnits (MeasurementDeviceUnitId),
        SecondaryTestedValue          DECIMAL(18,6)  NULL,
        SecondaryToleranceValue       DECIMAL(18,6)  NULL,
        SecondaryToleranceStart       DECIMAL(18,6)  NULL
            CONSTRAINT CK_CalibrationCycles_SecondaryToleranceStart CHECK (SecondaryToleranceStart <= 0),
        SecondaryToleranceEnd         DECIMAL(18,6)  NULL
            CONSTRAINT CK_CalibrationCycles_SecondaryToleranceEnd CHECK (SecondaryToleranceEnd >= 0),
        SecondaryResolution           DECIMAL(18,6)  NULL,
        SecondaryUncertainty          DECIMAL(18,6)  NULL,
        SecondaryStabilityThreshold   DECIMAL(18,6)  NULL
            CONSTRAINT CK_CalibrationCycles_SecondaryStabilityThreshold CHECK (SecondaryStabilityThreshold >= 0),
        SecondaryUniformityThreshold  DECIMAL(18,6)  NULL
            CONSTRAINT CK_CalibrationCycles_SecondaryUniformityThreshold CHECK (SecondaryUniformityThreshold >= 0),
        SecondaryDisplayValue         DECIMAL(18,6)  NULL,
        SecondaryDisplayResolution    DECIMAL(18,6)  NULL
            CONSTRAINT CK_CalibrationCycles_SecondaryDisplayResolution CHECK (SecondaryDisplayResolution >= 0),
        SecondaryIsDisplayEnabled     BIT            NULL,
        SecondaryIsTargetValueEnabled BIT            NULL,
        SecondaryCalculationResolution DECIMAL(18,6) NULL
            CONSTRAINT CK_CalibrationCycles_SecondaryCalculationResolution CHECK (SecondaryCalculationResolution >= 0),

        CONSTRAINT PK_CalibrationCycles PRIMARY KEY CLUSTERED
            (OrderDetailsItemId, CalibrationCycleStartDate),
        CONSTRAINT FK_CalibrationCycles_CalibrationCycleStatusId
            FOREIGN KEY (CalibrationCycleStatusId) REFERENCES dbo.Statuses (StatusId),
        CONSTRAINT FK_CalibrationCycles_CreatedUserID
            FOREIGN KEY (CreatedUserID) REFERENCES dbo.Users (ID),
        CONSTRAINT FK_CalibrationCycles_UpdateUserID
            FOREIGN KEY (UpdateUserID) REFERENCES dbo.Users (ID),
        CONSTRAINT FK_CalibrationCycles_UnitId
            FOREIGN KEY (UnitId) REFERENCES dbo.MeasurementDeviceUnits (MeasurementDeviceUnitId)
    );
END
GO
