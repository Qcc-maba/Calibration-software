-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE PROCEDURE [dbo].[GetMeasurementDevices]
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	SELECT	dbo.Departments.DepartmentName AS Department, dbo.MeasurementDevicesMainClasses.NameHebrew AS MainClasses, dbo.MeasurementDevicesSubClass.Name AS SubClass, dbo.MeasurementDevices.MabaID
	FROM	dbo.MeasurementDevicesMainClasses RIGHT OUTER JOIN
			dbo.MeasurementDevices ON dbo.MeasurementDevicesMainClasses.Id = dbo.MeasurementDevices.MainClass LEFT OUTER JOIN
			dbo.Departments ON dbo.MeasurementDevices.DepartmentId = dbo.Departments.ID LEFT OUTER JOIN
            dbo.MeasurementDevicesSubClass ON dbo.MeasurementDevices.SubClass = dbo.MeasurementDevicesSubClass.ID

END