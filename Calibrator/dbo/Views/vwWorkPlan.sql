
CREATE   VIEW [dbo].[vwWorkPlan]
AS
SELECT DISTINCT 
                         TOP (100) PERCENT dbo.Orders.OrderNumber, dbo.Orders.CalibDate, dbo.Orders.Klita, SpecialCareList.SpecialCares, dbo.Orders.CustomerName, dbo.Orders.CustomerCity, MainCategotiesList.MainCategoties, 
                         dbo.WorkPlan.OpenDate AS WorkPlanOpenDate, CarsList.Cars, UsersList.Calibrators, EquipmentsList.Equipments, dbo.WorkPlan.Notes, dbo.Orders.PartDescription AS PartName, dbo.Orders.DeviceDescription, 
                         dbo.Orders.DepartmentName, dbo.Orders.MbaReportNumber, dbo.Orders.SerialNumber, dbo.Orders.[Device manufacturer] AS DeviceManufacturer, dbo.Orders.DeviceModel
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
                             (SELECT        STRING_AGG(dbo.CalibEquipments.Name, ', ') AS Equipments, dbo.CalibEquipmentsToWorkplan.WorkplanID
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

GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPane1', @value = N'[0E232FF0-B466-11cf-A24F-00AA00A3EFFF, 1.00]
Begin DesignProperties = 
   Begin PaneConfigurations = 
      Begin PaneConfiguration = 0
         NumPanes = 4
         Configuration = "(H (1[27] 4[18] 2[20] 3) )"
      End
      Begin PaneConfiguration = 1
         NumPanes = 3
         Configuration = "(H (1[24] 4[46] 3) )"
      End
      Begin PaneConfiguration = 2
         NumPanes = 3
         Configuration = "(H (1[38] 2[28] 3) )"
      End
      Begin PaneConfiguration = 3
         NumPanes = 3
         Configuration = "(H (4 [30] 2 [40] 3))"
      End
      Begin PaneConfiguration = 4
         NumPanes = 2
         Configuration = "(H (1 [56] 3))"
      End
      Begin PaneConfiguration = 5
         NumPanes = 2
         Configuration = "(H (2 [66] 3))"
      End
      Begin PaneConfiguration = 6
         NumPanes = 2
         Configuration = "(H (4 [50] 3))"
      End
      Begin PaneConfiguration = 7
         NumPanes = 1
         Configuration = "(V (3))"
      End
      Begin PaneConfiguration = 8
         NumPanes = 3
         Configuration = "(H (1[56] 4[18] 2) )"
      End
      Begin PaneConfiguration = 9
         NumPanes = 2
         Configuration = "(H (1 [75] 4))"
      End
      Begin PaneConfiguration = 10
         NumPanes = 2
         Configuration = "(H (1[66] 2) )"
      End
      Begin PaneConfiguration = 11
         NumPanes = 2
         Configuration = "(H (4 [60] 2))"
      End
      Begin PaneConfiguration = 12
         NumPanes = 1
         Configuration = "(H (1) )"
      End
      Begin PaneConfiguration = 13
         NumPanes = 1
         Configuration = "(V (4))"
      End
      Begin PaneConfiguration = 14
         NumPanes = 1
         Configuration = "(V (2))"
      End
      ActivePaneConfig = 0
   End
   Begin DiagramPane = 
      Begin Origin = 
         Top = 0
         Left = 0
      End
      Begin Tables = 
         Begin Table = "SpecialCareList"
            Begin Extent = 
               Top = 125
               Left = 846
               Bottom = 223
               Right = 1000
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "Orders"
            Begin Extent = 
               Top = 0
               Left = 215
               Bottom = 245
               Right = 431
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "WorkPlan"
            Begin Extent = 
               Top = 78
               Left = 460
               Bottom = 211
               Right = 629
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "CarsList"
            Begin Extent = 
               Top = 216
               Left = 660
               Bottom = 313
               Right = 813
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "EquipmentsList"
            Begin Extent = 
               Top = 26
               Left = 845
               Bottom = 122
               Right = 998
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "MainCategotiesList"
            Begin Extent = 
               Top = 88
               Left = 7
               Bottom = 184
               Right = 179
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "UsersList"
            Begin Extent = 
               Top = 0
               Left = 659
               Bottom = 96
               Right = 818
            End
      ', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'vwWorkPlan';


GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPane2', @value = N'      DisplayFlags = 280
            TopColumn = 0
         End
      End
   End
   Begin SQLPane = 
   End
   Begin DataPane = 
      Begin ParameterDefaults = ""
      End
      Begin ColumnWidths = 35
         Width = 284
         Width = 1305
         Width = 1500
         Width = 915
         Width = 1755
         Width = 1500
         Width = 1290
         Width = 945
         Width = 2340
         Width = 1035
         Width = 1380
         Width = 1485
         Width = 1110
         Width = 4905
         Width = 1620
         Width = 1740
         Width = 1440
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1935
         Width = 1500
         Width = 1500
         Width = 1080
         Width = 1500
         Width = 750
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
      End
   End
   Begin CriteriaPane = 
      Begin ColumnWidths = 11
         Column = 2520
         Alias = 1785
         Table = 1440
         Output = 720
         Append = 1400
         NewValue = 1170
         SortType = 1350
         SortOrder = 1410
         GroupBy = 1350
         Filter = 1350
         Or = 1350
         Or = 1350
         Or = 1350
      End
   End
End
', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'vwWorkPlan';


GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPaneCount', @value = 2, @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'vwWorkPlan';

