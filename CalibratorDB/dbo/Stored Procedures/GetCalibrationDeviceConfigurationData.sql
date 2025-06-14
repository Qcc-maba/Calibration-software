-- =============================================
-- Author:		Shamailov Slavik
-- Create date: 07/01/2025
-- Description:	Get Calibration device configuration data 
-- =============================================
CREATE PROCEDURE [dbo].[GetCalibrationDeviceConfigurationData]
	@DeviceNumber NVARCHAR(20)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	-- Insert statements for procedure here
SELECT 
    dbo.MeasurementDevices.MabaID AS [Maba Number],
    dbo.MeasurementDevices.SerialNumber AS [Serial Number],
    dbo.MeasurementDevicesManufacturers.Name AS Manufacturers,
    dbo.MeasurementDevices.Model,
    dbo.MeasurementDevices.CalibrationDate AS [Last Calibration],
    dbo.MeasurementDevices.NextCalibration AS [Next Calibration],
    dbo.Users.FirstName + N' ' + dbo.Users.LastName AS [Calibrator Name],
    dbo.MeasurementDevices.ReportNumber AS [Report Number],
    dbo.MeasurementDevices.Description,
    dbo.MeasurementDevicesMainClasses.NameHebrew AS [Main class],
    dbo.MeasurementDevicesSubClass.Name AS [Sub Class],
    dbo.Measurements.NameHe AS [Measurement Name],
    [dbo].[MeasurementDeviceUnits].LongNameHe AS Unit,
    Units_1.LongNameHe AS [Work Unit],
    dbo.MeasurementDevices.WorkRangeMin AS [Work Range Min],
    dbo.MeasurementDevices.WorkRangeMax AS [Work Range Max],
    dbo.MeasurementDevices.DefaultPrecision AS [Precision low],
    dbo.MeasurementDevices.HighestPrecision AS [Precision high],
    dbo.MeasurementDevices.AllowMinOOR AS [Allow OOR Min],
    dbo.MeasurementDevices.AllowMaxOOR AS [Allow OOR Max]
FROM 
    [dbo].[MeasurementDeviceUnits] AS Units_1
        INNER JOIN dbo.MeasurementDevices ON Units_1.MeasurementDeviceUnitId = dbo.MeasurementDevices.WorkRangeUnitId
        RIGHT OUTER JOIN dbo.MeasurementDevicesSubClass ON dbo.MeasurementDevicesSubClass.ID = dbo.MeasurementDevices.SubClassId
        INNER JOIN dbo.MeasurementDevicesMainClasses ON dbo.MeasurementDevices.MainClassId = dbo.MeasurementDevicesMainClasses.Id
        INNER JOIN dbo.Users ON dbo.MeasurementDevices.CalibratorId = dbo.Users.ID 
    LEFT OUTER JOIN dbo.MeasurementDevicesManufacturers 
        ON dbo.MeasurementDevices.ManufacturerId = dbo.MeasurementDevicesManufacturers.ID
    LEFT OUTER JOIN dbo.Measurements 
        ON dbo.MeasurementDevices.MeasurementId = dbo.Measurements.ID
    LEFT OUTER JOIN [dbo].[MeasurementDeviceUnits]
        ON dbo.MeasurementDevices.UnitId = [dbo].[MeasurementDeviceUnits].MeasurementDeviceUnitId
WHERE	(dbo.MeasurementDevices.MabaID = @DeviceNumber)

END