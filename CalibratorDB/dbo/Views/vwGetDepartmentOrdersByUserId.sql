/*CREATE VIEW dbo.vwGetDepartmentOrdersByUserId
AS
SELECT        dbo.UsersToDepartments.UserId, dbo.UsersToDepartments.DepartmentId, dbo.vwGetOrdersData.OrderNumber AS [Order Number], dbo.vwGetOrderDevices.[Open Date], dbo.vwGetOrdersData.CustomerName, 
                         dbo.vwGetOrdersData.CustomerPhone, dbo.vwGetOrdersData.CustomerContactName, dbo.vwGetOrdersData.CustomerCity, dbo.vwGetOrdersData.CustomerAddress, dbo.vwGetOrdersData.MBAContactName, 
                         dbo.vwGetOrdersData.MBAContactPhone, dbo.vwGetOrdersData.MBAContactMobile, dbo.vwGetOrdersData.ClientRemarks, dbo.vwGetOrderDevices.NextCalibDate, dbo.vwGetOrderDevices.MBANUM AS [MBA Number], 
                         dbo.vwGetOrderDevices.[Device Description], dbo.vwGetOrderDevices.[Device model], dbo.vwGetOrderDevices.[Serial Number], dbo.vwGetOrderDevices.[Device manufacturer], dbo.vwGetOrderDevices.DEPTDES
FROM            dbo.vwGetOrdersData INNER JOIN
                         dbo.vwGetOrderDevices ON dbo.vwGetOrdersData.OrderNumber = dbo.vwGetOrderDevices.[Order Number] INNER JOIN
                         dbo.UsersToDepartments ON dbo.vwGetOrderDevices.DEPT = dbo.UsersToDepartments.DepartmentId

GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPane1', @value = N'[0E232FF0-B466-11cf-A24F-00AA00A3EFFF, 1.00]
Begin DesignProperties = 
   Begin PaneConfigurations = 
      Begin PaneConfiguration = 0
         NumPanes = 4
         Configuration = "(H (1[44] 4[18] 2[10] 3) )"
      End
      Begin PaneConfiguration = 1
         NumPanes = 3
         Configuration = "(H (1[45] 4[29] 3) )"
      End
      Begin PaneConfiguration = 2
         NumPanes = 3
         Configuration = "(H (1 [50] 2 [25] 3))"
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
      ActivePaneConfig = 1
   End
   Begin DiagramPane = 
      Begin Origin = 
         Top = 0
         Left = 0
      End
      Begin Tables = 
         Begin Table = "vwGetOrdersData"
            Begin Extent = 
               Top = 0
               Left = 0
               Bottom = 284
               Right = 206
            End
            DisplayFlags = 280
            TopColumn = 1
         End
         Begin Table = "vwGetOrderDevices"
            Begin Extent = 
               Top = 0
               Left = 293
               Bottom = 363
               Right = 512
            End
            DisplayFlags = 280
            TopColumn = 1
         End
         Begin Table = "UsersToDepartments"
            Begin Extent = 
               Top = 5
               Left = 542
               Bottom = 118
               Right = 781
            End
            DisplayFlags = 280
            TopColumn = 0
         End
      End
   End
   Begin SQLPane = 
      PaneHidden = 
   End
   Begin DataPane = 
      Begin ParameterDefaults = ""
      End
      Begin ColumnWidths = 21
         Width = 284
         Width = 690
         Width = 1500
         Width = 1350
         Width = 1290
         Width = 2010
         Width = 1275
         Width = 1500
         Width = 1500
         Width = 2145
         Width = 1695
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
      End
   End
   Begin CriteriaPane = 
      Begin ColumnWidths = 11
         Column = 4665
         Alias = 1440
         Table = 1845
         Output = 720
         Append = 1400
         NewValue = 1170
         SortType = 1350
         SortOrder = 1410
         GroupBy = 1350
         Filter = 1350
         Or ', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'vwGetDepartmentOrdersByUserId';


GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPane2', @value = N'= 1350
         Or = 1350
         Or = 1350
      End
   End
End
', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'vwGetDepartmentOrdersByUserId';


GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPaneCount', @value = 2, @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'vwGetDepartmentOrdersByUserId';

*/