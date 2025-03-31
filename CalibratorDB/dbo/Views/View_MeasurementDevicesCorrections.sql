CREATE VIEW dbo.View_MeasurementDevicesCorrections
AS
SELECT DISTINCT dbo.MeasurementDevices.MabaID, MeasurementDevicesCorrections_1.Value1, MeasurementDevicesCorrections_1.Value2, MeasurementDevicesCorrections_1.Deviation
FROM            dbo.MeasurementDevicesCorrections AS MeasurementDevicesCorrections_1 INNER JOIN
                         dbo.MeasurementDevices INNER JOIN
                             (SELECT        MeasurementDevicesId, MAX(CorVersion) AS LastVersion
                               FROM            dbo.MeasurementDevicesCorrections
                               GROUP BY MeasurementDevicesId) AS TMaxCorrections ON dbo.MeasurementDevices.ID = TMaxCorrections.MeasurementDevicesId ON 
                         MeasurementDevicesCorrections_1.MeasurementDevicesId = TMaxCorrections.MeasurementDevicesId AND MeasurementDevicesCorrections_1.CorVersion = TMaxCorrections.LastVersion LEFT OUTER JOIN
                         dbo.Measurements ON MeasurementDevicesCorrections_1.MeasurementId = dbo.Measurements.ID

GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPane1', @value = N'[0E232FF0-B466-11cf-A24F-00AA00A3EFFF, 1.00]
Begin DesignProperties = 
   Begin PaneConfigurations = 
      Begin PaneConfiguration = 0
         NumPanes = 4
         Configuration = "(H (1[40] 4[19] 2[23] 3) )"
      End
      Begin PaneConfiguration = 1
         NumPanes = 3
         Configuration = "(H (1[50] 4[25] 3) )"
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
      ActivePaneConfig = 0
   End
   Begin DiagramPane = 
      Begin Origin = 
         Top = 0
         Left = 0
      End
      Begin Tables = 
         Begin Table = "MeasurementDevicesCorrections_1"
            Begin Extent = 
               Top = 0
               Left = 683
               Bottom = 289
               Right = 981
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "MeasurementDevices"
            Begin Extent = 
               Top = 0
               Left = 0
               Bottom = 306
               Right = 196
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "TMaxCorrections"
            Begin Extent = 
               Top = 0
               Left = 289
               Bottom = 97
               Right = 501
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "Measurements"
            Begin Extent = 
               Top = 0
               Left = 1080
               Bottom = 195
               Right = 1250
            End
            DisplayFlags = 280
            TopColumn = 0
         End
      End
   End
   Begin SQLPane = 
   End
   Begin DataPane = 
      Begin ParameterDefaults = ""
      End
      Begin ColumnWidths = 9
         Width = 284
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
         Column = 1440
         Alias = 900
         Table = 3180
         Output = 720
         Append = 1400
         NewValue = 1170
         SortType = 1350
         SortOrder = 1410
         GroupBy = 1350
         Filter = 1350
         Or = 1350
         ', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'View_MeasurementDevicesCorrections';


GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPane2', @value = N'Or = 1350
         Or = 1350
      End
   End
End
', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'View_MeasurementDevicesCorrections';


GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPaneCount', @value = 2, @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'View_MeasurementDevicesCorrections';

