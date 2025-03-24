CREATE VIEW dbo.View_1
AS
SELECT        dbo.MeasurementDevices.MabaID AS [Maba Number], dbo.MeasurementDevices.SerialNumber AS [Serial Number], dbo.MeasurementDevicesManufacturers.Name AS Manufacturers, dbo.MeasurementDevices.Model, 
                         dbo.MeasurementDevices.CalibrationDate AS [Last Calibration], dbo.MeasurementDevices.NextCalibration AS [Next Calibration], dbo.Users.FirstName + N' ' + dbo.Users.LastName AS [Calibrator Name], 
                         dbo.MeasurementDevices.ReportNumber AS [Report Number], dbo.MeasurementDevices.Description, dbo.MeasurementDevicesMainClasses.NameHebrew AS [Main class], 
                         dbo.MeasurementDevicesSubClass.Name AS [Sub Class], dbo.Measurements.NameHe AS [Measurement Name], dbo.Units.LongNameHe AS Unit, Units_1.LongNameHe AS [Work Unit], 
                         dbo.MeasurementDevices.WorkRangeMin AS [Work Range Min], dbo.MeasurementDevices.WorkRangeMax AS [Work Range Max], dbo.MeasurementDevices.DefaultPrecision AS [Precision low], 
                         dbo.MeasurementDevices.HighestPrecision AS [Precision high], dbo.MeasurementDevices.AllowMinOOR AS [Allow OOR Min], dbo.MeasurementDevices.AllowMaxOOR AS [Allow OOR Max]
FROM            dbo.MeasurementDevicesSubClass INNER JOIN
                         dbo.MeasurementDevices ON dbo.MeasurementDevicesSubClass.ID = dbo.MeasurementDevices.SubClass INNER JOIN
                         dbo.MeasurementDevicesMainClasses ON dbo.MeasurementDevices.MainClass = dbo.MeasurementDevicesMainClasses.Id LEFT OUTER JOIN
                         dbo.Users ON dbo.MeasurementDevices.CalibratorId = dbo.Users.ID LEFT OUTER JOIN
                         dbo.MeasurementDevicesManufacturers ON dbo.MeasurementDevices.ManufacturerId = dbo.MeasurementDevicesManufacturers.ID LEFT OUTER JOIN
                         dbo.Measurements ON dbo.MeasurementDevices.MeasurementId = dbo.Measurements.ID LEFT OUTER JOIN
                         dbo.Units ON dbo.MeasurementDevices.Unit = dbo.Units.ID LEFT OUTER JOIN
                         dbo.Units AS Units_1 ON dbo.MeasurementDevices.WorkRangeUnit = Units_1.ID
WHERE        (dbo.MeasurementDevices.MabaID = '10-112') OR
                         (dbo.MeasurementDevices.MabaID = '30-99-2')

GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPane1', @value = N'[0E232FF0-B466-11cf-A24F-00AA00A3EFFF, 1.00]
Begin DesignProperties = 
   Begin PaneConfigurations = 
      Begin PaneConfiguration = 0
         NumPanes = 4
         Configuration = "(H (1[38] 4[23] 2[11] 3) )"
      End
      Begin PaneConfiguration = 1
         NumPanes = 3
         Configuration = "(H (1[50] 4[30] 3) )"
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
         Begin Table = "MeasurementDevicesSubClass"
            Begin Extent = 
               Top = 229
               Left = 21
               Bottom = 357
               Right = 251
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "MeasurementDevices"
            Begin Extent = 
               Top = 0
               Left = 474
               Bottom = 402
               Right = 673
            End
            DisplayFlags = 280
            TopColumn = 9
         End
         Begin Table = "MeasurementDevicesMainClasses"
            Begin Extent = 
               Top = 0
               Left = 160
               Bottom = 179
               Right = 445
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "MeasurementDevicesManufacturers"
            Begin Extent = 
               Top = 0
               Left = 704
               Bottom = 113
               Right = 975
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "Users"
            Begin Extent = 
               Top = 317
               Left = 290
               Bottom = 499
               Right = 460
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "Measurements"
            Begin Extent = 
               Top = 123
               Left = 704
               Bottom = 253
               Right = 874
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "Units"
            Begin Extent = 
               Top = 356
               Left = 953
               Bottom = 504
', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'View_1';


GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPane2', @value = N'               Right = 1123
            End
            DisplayFlags = 280
            TopColumn = 8
         End
         Begin Table = "Units_1"
            Begin Extent = 
               Top = 376
               Left = 725
               Bottom = 506
               Right = 908
            End
            DisplayFlags = 280
            TopColumn = 9
         End
      End
   End
   Begin SQLPane = 
   End
   Begin DataPane = 
      Begin ParameterDefaults = ""
      End
      Begin ColumnWidths = 26
         Width = 284
         Width = 1140
         Width = 1170
         Width = 1275
         Width = 1290
         Width = 1980
         Width = 1980
         Width = 1440
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1440
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1485
         Width = 1530
         Width = 1500
         Width = 1500
         Width = 2385
         Width = 1500
         Width = 1500
         Width = 1500
      End
   End
   Begin CriteriaPane = 
      Begin ColumnWidths = 11
         Column = 3465
         Alias = 2535
         Table = 2895
         Output = 795
         Append = 1400
         NewValue = 1170
         SortType = 945
         SortOrder = 1035
         GroupBy = 1350
         Filter = 1005
         Or = 1350
         Or = 1350
         Or = 1350
      End
   End
End
', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'View_1';


GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPaneCount', @value = 2, @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'View_1';

