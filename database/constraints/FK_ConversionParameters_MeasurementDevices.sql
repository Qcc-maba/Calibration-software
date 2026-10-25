/*
    Constraints on dbo.ConversionParameters                                            MBA-816
    ---------------------------------------------------------------------------------------------
    FK_ConversionParameters_MeasurementDevices
        A coefficient set belongs to a sensor that exists. Without it, a set can outlive or miss its
        sensor and be found by nothing - the state 18,994 correction rows were found in (MBA-811).

    CK_ConversionParameters_RTP_Positive
        ITS-90 divides every reading by RTP (W = R / RTP). Zero cannot be divided by, and a negative
        resistance is not a measurement. The other five may be zero: that is how a sensor used in
        one range only is stored (Nofar, 29/09).

    Run after dbo.ConversionParameters.MeasurementDevicesId.sql. Replayable.
*/
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_ConversionParameters_MeasurementDevices')
    ALTER TABLE dbo.ConversionParameters
        ADD CONSTRAINT FK_ConversionParameters_MeasurementDevices
        FOREIGN KEY (MeasurementDevicesId) REFERENCES dbo.MeasurementDevices (ID);
GO

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = 'CK_ConversionParameters_RTP_Positive')
    ALTER TABLE dbo.ConversionParameters
        ADD CONSTRAINT CK_ConversionParameters_RTP_Positive CHECK (RTP > 0);
GO
