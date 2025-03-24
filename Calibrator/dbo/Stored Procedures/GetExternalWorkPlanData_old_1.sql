-- =============================================
-- Author:		Shamailov Slavik
-- Create date: 06/01/2025
-- Description:	Get work plan list from today
-- =============================================
CREATE PROCEDURE [dbo].[GetExternalWorkPlanData_old]
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	-- Get work plan list from today
/*	SELECT	dbo.WorkPlan.Id AS WorkPlanId, dbo.WorkPlan.RequiredCalibrationDate, dbo.WorkPlan.OrderNumber, dbo.WorkPlan.MbaNumber, 
			dbo.WorkPlan.OpenDate AS [Work Open Date], dbo.Orders.CustomerName, dbo.Orders.CustomerCity, dbo.Cars.LicenseNumber AS [Car Number]
	FROM	dbo.Cars INNER JOIN
			dbo.CarsToWorkplan ON dbo.Cars.ID = dbo.CarsToWorkplan.CarId RIGHT OUTER JOIN
			dbo.WorkPlan INNER JOIN
			dbo.Orders ON dbo.WorkPlan.OrderNumber = dbo.Orders.OrderNumber ON dbo.CarsToWorkplan.WorkPlanId = dbo.WorkPlan.Id
	WHERE   (dbo.WorkPlan.RequiredCalibrationDate >= DATEADD(dd, 0, DATEDIFF(dd, 0, GETDATE())))

	-- Get Special treatments
	SELECT	dbo.WorkPlan.Id AS WorkPlanId, dbo.SpecialCare_wp.Name AS [Special Treatment]
	FROM	dbo.WorkPlan INNER JOIN
			dbo.SpecialCareToWorkPlan ON dbo.WorkPlan.Id = dbo.SpecialCareToWorkPlan.WorkPlanId INNER JOIN
			dbo.SpecialCare_wp ON dbo.SpecialCareToWorkPlan.SpecialCareId = dbo.SpecialCare_wp.ID
	WHERE   (dbo.WorkPlan.RequiredCalibrationDate >= DATEADD(dd, 0, DATEDIFF(dd, 0, GETDATE())))

	-- Get calibrators in workplans
	SELECT	dbo.WorkPlan.Id AS WorkPlanId, dbo.Calibrators.ID AS [Calibrator Id], dbo.Users.FirstName, dbo.Users.LastName, dbo.Users.Email, dbo.Users.Mobile
	FROM	dbo.WorkPlan INNER JOIN
			dbo.CalibratorsToWorkPlan ON dbo.WorkPlan.Id = dbo.CalibratorsToWorkPlan.WorkPlanId INNER JOIN
			dbo.Calibrators ON dbo.CalibratorsToWorkPlan.CalibratorsId = dbo.Calibrators.ID INNER JOIN
			dbo.Users ON dbo.Calibrators.UserId = dbo.Users.ID
	WHERE   (dbo.WorkPlan.RequiredCalibrationDate >= DATEADD(dd, 0, DATEDIFF(dd, 0, GETDATE())))

	-- Get Equipments in workplans
	-- TODO: add filters
	SELECT	dbo.WorkPlan.Id AS WorkPlanId, dbo.CalibEquipments.Name, dbo.CalibEquipments.Quantity, dbo.Departments.DepartmentName
	FROM    dbo.WorkPlan INNER JOIN
			dbo.CalibEquipmentsToWorkplan ON dbo.WorkPlan.Id = dbo.CalibEquipmentsToWorkplan.WorkplanID INNER JOIN
			dbo.CalibEquipments ON dbo.CalibEquipmentsToWorkplan.EquipmentID = dbo.CalibEquipments.ID INNER JOIN
			dbo.Departments ON dbo.CalibEquipments.DepartmentId = dbo.Departments.ID
	WHERE   (dbo.WorkPlan.RequiredCalibrationDate >= DATEADD(dd, 0, DATEDIFF(dd, 0, GETDATE())))


	TODO:
	-- קטגוריית כיול ראשית

	-- רשימת כיילים לפי פילטרים
	*/
END