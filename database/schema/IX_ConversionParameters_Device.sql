/*
    IX_ConversionParameters_Device                                                     MBA-816
    ---------------------------------------------------------------------------------------------
    Every read of dbo.ConversionParameters asks "this sensor's newest set". The newest is the highest
    ConversionParameterId - rows are never updated, each save is a new row - so the key is ordered
    that way and the six coefficients are included, and the lookup never leaves the index.

    Run after dbo.ConversionParameters.MeasurementDevicesId.sql. Replayable.
*/
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_ConversionParameters_Device')
CREATE NONCLUSTERED INDEX IX_ConversionParameters_Device
    ON dbo.ConversionParameters (MeasurementDevicesId, ConversionParameterId DESC)
    INCLUDE (RTP, A4, B4, A7, B7, C7, IsDeleted);
GO
