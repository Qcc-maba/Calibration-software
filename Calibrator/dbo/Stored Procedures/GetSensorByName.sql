CREATE PROCEDURE [dbo].[GetSensorByName]
    @MabaID VARCHAR(50)
AS
BEGIN
SELECT DISTINCT 
                         MeasurementDevicesCorrections_1.Value1, MeasurementDevicesCorrections_1.Value2, MeasurementDevicesCorrections_1.Deviation
FROM            dbo.MeasurementDevicesCorrections AS MeasurementDevicesCorrections_1 INNER JOIN
                         dbo.MeasurementDevices INNER JOIN
                             (SELECT        MeasurementDevicesId, MAX(CorVersion) AS LastVersion
                               FROM            dbo.MeasurementDevicesCorrections
                               GROUP BY MeasurementDevicesId) AS TMaxCorrections ON dbo.MeasurementDevices.ID = TMaxCorrections.MeasurementDevicesId ON 
                         MeasurementDevicesCorrections_1.MeasurementDevicesId = TMaxCorrections.MeasurementDevicesId AND MeasurementDevicesCorrections_1.CorVersion = TMaxCorrections.LastVersion INNER JOIN
                         dbo.Measurements ON MeasurementDevicesCorrections_1.MeasurementId = dbo.Measurements.ID
WHERE        (dbo.MeasurementDevices.MabaID = @MabaID)

END;
