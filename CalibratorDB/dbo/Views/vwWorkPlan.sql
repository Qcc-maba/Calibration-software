

--USE [Calibrator]
--GO

--/****** Object:  View [dbo].[vwWorkPlan]    Script Date: 3/24/2025 1:43:00 PM ******/
--SET ANSI_NULLS ON
--GO

--SET QUOTED_IDENTIFIER ON
--GO


CREATE     VIEW [dbo].[vwWorkPlan]
AS
SELECT DISTINCT 
                         TOP (100) PERCENT dbo.Orders.OrderNumber, dbo.Orders.CalibDate, dbo.Orders.Klita, SpecialCareList.SpecialCares, dbo.Orders.CustomerName, dbo.Orders.CustomerCity, MainCategotiesList.MainCategoties, 
                         dbo.WorkPlan.OpenDate AS WorkPlanOpenDate, CarsList.Cars, UsersList.Calibrators, EquipmentsList.Equipments, dbo.WorkPlan.Notes, dbo.Orders.PartDescription AS PartName, dbo.Orders.DeviceDescription, 
                         dbo.Orders.DepartmentName, dbo.Orders.MbaReportNumber, dbo.Orders.SerialNumber, dbo.Orders.[DeviceManufacturer] AS DeviceManufacturer, dbo.Orders.DeviceModel, dbo.Orders.IsCancelled
FROM            (SELECT        STRING_AGG(dbo.SpecialCare_wp.Name, ', ') AS SpecialCares, dbo.SpecialCareToWorkPlan.WorkPlanId
                          FROM            dbo.SpecialCare_wp INNER JOIN
                                                    dbo.SpecialCareToWorkPlan ON dbo.SpecialCareToWorkPlan.SpecialCareId = dbo.SpecialCare_wp.ID
                          GROUP BY dbo.SpecialCareToWorkPlan.WorkPlanId) AS SpecialCareList RIGHT OUTER JOIN
                         dbo.Orders LEFT OUTER JOIN
                         dbo.WorkPlan ON dbo.Orders.OrderNumber = dbo.WorkPlan.OrderNumber ON SpecialCareList.WorkPlanId = dbo.WorkPlan.Id LEFT OUTER JOIN
                             (SELECT        STRING_AGG(dbo.Users.FirstName + ' ' + dbo.Users.LastName, ', ') AS Calibrators, CalibratorsToWorkPlan_1.WorkPlanId
                               FROM            dbo.Users INNER JOIN
                                                         dbo.CalibratorsToWorkPlan AS CalibratorsToWorkPlan_1 ON CalibratorsToWorkPlan_1.CalibratorsId = dbo.Users.ID
                               GROUP BY CalibratorsToWorkPlan_1.WorkPlanId) AS UsersList ON dbo.WorkPlan.Id = UsersList.WorkPlanId LEFT OUTER JOIN
                             (SELECT        STRING_AGG(dbo.Cars.LicenseNumber, ', ') AS Cars, CarsToWorkplan_1.WorkPlanId
                               FROM            dbo.Cars INNER JOIN
                                                         dbo.CarsToWorkplan AS CarsToWorkplan_1 ON CarsToWorkplan_1.CarId = dbo.Cars.CarId
                               GROUP BY CarsToWorkplan_1.WorkPlanId) AS CarsList ON dbo.WorkPlan.Id = CarsList.WorkPlanId LEFT OUTER JOIN
                             (SELECT        STRING_AGG(dbo.CalibEquipments.EquipmentName, ', ') AS Equipments, dbo.CalibEquipmentsToWorkplan.WorkplanID
                               FROM            dbo.CalibEquipments INNER JOIN
                                                         dbo.CalibEquipmentsToWorkplan ON dbo.CalibEquipmentsToWorkplan.EquipmentID = dbo.CalibEquipments.ID
                               GROUP BY dbo.CalibEquipmentsToWorkplan.WorkplanID) AS EquipmentsList ON dbo.WorkPlan.Id = EquipmentsList.WorkplanID LEFT OUTER JOIN
                             (SELECT        OrderNumber, STRING_AGG(DepartmentName, ', ') AS MainCategoties
                               FROM            (SELECT DISTINCT OrderNumber, DepartmentName
                                                         FROM            dbo.Orders AS Orders_1
                                                         WHERE        (DepartmentName IS NOT NULL)) AS t1
                               GROUP BY OrderNumber) AS MainCategotiesList ON dbo.Orders.OrderNumber = MainCategotiesList.OrderNumber
WHERE        (dbo.Orders.IsInHouse = 0)
ORDER BY dbo.Orders.OrderNumber, dbo.Orders.MbaReportNumber
