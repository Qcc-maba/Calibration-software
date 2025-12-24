CREATE PROCEDURE [dbo].[GetSensorByName]
    @MabaID NVARCHAR(50)
AS
BEGIN
;WITH LastVersion
AS
(
SELECT mdc.Value1, mdc.Value2, mdc.Deviation,mdc.CorVersion,/*MabaID,*/ RANK() OVER( PARTITION BY m.ID ,md.ID  ORDER BY mdc.CorVersion DESC) as rn
FROM dbo.MeasurementDevices as md
JOIN dbo.Measurements as m ON m.ID = md.MeasurementId
JOIN dbo.MeasurementDevicesCorrections as mdc ON m.ID = mdc.MeasurementId AND mdc.MeasurementDevicesId = md.ID
WHERE md.MabaID = @MabaID
)
SELECT DISTINCT Value1, Value2, Deviation,CorVersion
FROM LastVersion
WHERE rn = 1


END;