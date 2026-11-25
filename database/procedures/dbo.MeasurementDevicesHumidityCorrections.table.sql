/*
    dbo.MeasurementDevicesHumidityCorrections                                            MBA-950
    ---------------------------------------------------------------------------------------------
    A humidity master's certificate as POINTS: at a chamber temperature and a reference humidity,
    how far the master's humidity reading was off.

    Why a table of its own, and not more rows in dbo.MeasurementDevicesCorrections
    ------------------------------------------------------------------------------
    Humidity compensation depends on temperature. The master's humidity deviation is read off a
    surface over (temperature, humidity), interpolated over the triangle of certificate points that
    surrounds the reading - "triple interpolation" (Nofar, MBA-950, 25.11.2026). It is the method
    of the legacy Hydra code (CalibrationRepository.CalcDeviationForTemperatureAndHumidity).

    The correction table cannot hold that. Each of its rows is a one-axis RANGE, Value1..Value2,
    with a straight line over it; 24,508 rows have Value2 equal to the next row's Value1. Neither
    it nor its legacy source, kyulan.dbo.tblInstrCorrections (RangeStart, RangeStop, Value), has
    ever stored a humidity point together with the temperature it was taken at. Putting points
    in it would give Value1/Value2 a second meaning, and dbo.fnMasterValueAfterCorrection would
    read them as ranges - the exact misreading dbo.fnHumidityAfterCorrection was first written
    with. A separate table keeps each shape readable only one way.

    Measured on STAGE and PROD, 25.11.2026: in the newest certificate version of every master,
    only 30-1187-2 still carries a humidity curve laid out over temperature (2 ranges); 30-1165-1
    and 30-300-1 lost their humidity rows in later temperature-only versions. The humidity-only
    masters carry one-axis curves over humidity. So this table starts empty and is filled by the
    new data entry (dbo.SaveMasterHumidityCorrectionPoints).

    Columns
    -------
    Temperature        the chamber's reference temperature at the point, °C
    ReferenceHumidity  the reference humidity, %RH
    Deviation          master reading - reference, %RH. Computed by the save procedure, never
                       typed: the correction subtracts it, so a flipped sign doubles the error.
    ReadingHumidity    what the master showed, kept so the certificate can be shown as entered

    Versions work as in the correction table: each save is CorVersion = highest + 1, rows are
    never updated, and only the newest version is read. The version is per device and independent
    of the temperature certificate's versions, so saving one never retires the other.

    Keyed by MeasurementDevicesId, not by MabaID, so the merge of 30-1000-1 / 30-1000-2 into one
    device 30-1000 (MBA-1019) re-points rows by device id like every other certificate.
*/
/*
    QUOTED_IDENTIFIER / ANSI_NULLS must be ON: set explicitly so the object does not depend on the
    client that deploys it (sqlcmd defaults QUOTED_IDENTIFIER to OFF). The table's filtered unique
    index needs them ON when it is created and in every session that writes the table - a
    procedure keeps the settings it was created with. Same convention as
    dbo.CustomerDevices.table.sql.
*/
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO
IF OBJECT_ID('dbo.MeasurementDevicesHumidityCorrections', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.MeasurementDevicesHumidityCorrections
    (
        MeasurementDevicesHumidityCorrectionId INT IDENTITY(1,1) NOT NULL,
        MeasurementDevicesId INT           NOT NULL,
        CorVersion           INT           NOT NULL,
        Temperature          DECIMAL(18,6) NOT NULL,
        ReferenceHumidity    DECIMAL(18,6) NOT NULL,
        ReadingHumidity      DECIMAL(18,6) NOT NULL,
        Deviation            DECIMAL(18,6) NOT NULL,
        Note                 NVARCHAR(500) NULL,
        UpdateUserID         INT           NULL,
        CreatedDate          DATETIME2(3)  NOT NULL
            CONSTRAINT DF_MeasurementDevicesHumidityCorrections_CreatedDate DEFAULT (SYSUTCDATETIME()),
        IsDeleted            BIT           NOT NULL
            CONSTRAINT DF_MeasurementDevicesHumidityCorrections_IsDeleted DEFAULT (0),

        CONSTRAINT PK_MeasurementDevicesHumidityCorrections
            PRIMARY KEY CLUSTERED (MeasurementDevicesHumidityCorrectionId),
        CONSTRAINT FK_MeasurementDevicesHumidityCorrections_Device
            FOREIGN KEY (MeasurementDevicesId) REFERENCES dbo.MeasurementDevices (ID),
        CONSTRAINT FK_MeasurementDevicesHumidityCorrections_User
            FOREIGN KEY (UpdateUserID) REFERENCES dbo.Users (ID),
        CONSTRAINT CK_MeasurementDevicesHumidityCorrections_Humidity
            CHECK (ReferenceHumidity >= 0 AND ReferenceHumidity <= 100),
        CONSTRAINT CK_MeasurementDevicesHumidityCorrections_Deviation
            CHECK (Deviation = ReadingHumidity - ReferenceHumidity)
    );

    /* one point per (temperature, humidity) in a version - two would make a triangle of no area */
    CREATE UNIQUE NONCLUSTERED INDEX UX_MeasurementDevicesHumidityCorrections_Point
        ON dbo.MeasurementDevicesHumidityCorrections (MeasurementDevicesId, CorVersion, Temperature, ReferenceHumidity)
        WHERE IsDeleted = 0;
END
GO
