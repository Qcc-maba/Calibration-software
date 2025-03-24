
/*CREATE VIEW [dbo].[vwGetOrderDevices]
AS
SELECT    TOP (100) PERCENT DOCUMENTS.DOCNO AS [Order Number], DATEADD(n, DOCUMENTS.CURDATE, '01/01/1988') AS [Open Date], MBA_DOCUMENTS.MBANUM, 
							SERNUMBERS.FREE1 AS [Serial Number], SERNUMBERS.FREE2 AS [Manufacturer Number], MBA_SERNUMBERS.SERNDES AS [Device Description], 
							MBA_SERNUMBERS.MODEL AS [Device model], DATEADD(n, SERVCALLS.AENDDATE, '01/01/1988') AS CalibDate, 
						 (CASE WHEN DOCUMENTS1.MBA_NEXTCALIBDATE = '' THEN NULL ELSE dateadd(n, DOCUMENTS1.MBA_NEXTCALIBDATE, '01/01/1988') END) AS NextCalibDate, 
						 MBA_SERNUMBERS.CALIBMONTH, 
						 (CASE WHEN DOCUMENTS.MBA_CALRETDATE = '' THEN NULL ELSE dateadd(n, DOCUMENTS.MBA_CALRETDATE, '01/01/1988') END) AS ReturnDate, 
						 PART.PARTNAME AS [Part Name], PART.PARTDES AS [Part Description], 
						 CASE WHEN RIGHT(PART.PARTNAME, 1) = '0' OR RIGHT(PART.PARTNAME, 1) = '1' THEN 1 ELSE 0 END AS IsInHouse, 
						 DEPT.DEPT, DEPT.DEPTDES,  CALLSTATUSES.CALLSTATUS AS StatusCode, CALLSTATUSES.CODE AS Status, dbo.tabula_hebconvert(MNFCTR.MNFDES) AS [Device manufacturer], 
						 SERNUMBERS.PART, DOCUMENTS1.DOCNO, MBA_SERNUMBERS.RANGESERNUM, MNFCTR.MNFNAME, MBA_SERNUMBERS.EQUIPTYPE
FROM      [31.154.20.231].[amaba].[dbo].[DOCUMENTS] INNER JOIN
                         [31.154.20.231].amaba.dbo.MBA_DOCUMENTS ON DOCUMENTS.DOC =MBA_DOCUMENTS.DOC_N INNER JOIN
                         [31.154.20.231].amaba.dbo.SERNUMBERS INNER JOIN
                         [31.154.20.231].amaba.dbo.SERVCALLS ON SERNUMBERS.SERN = SERVCALLS.SERN ON MBA_DOCUMENTS.DOC = SERVCALLS.DOC INNER JOIN
                         [31.154.20.231].amaba.dbo.MBA_SERNUMBERS ON SERNUMBERS.SERN = MBA_SERNUMBERS.SERN INNER JOIN
                         [31.154.20.231].amaba.dbo.DOCUMENTS AS DOCUMENTS1 ON SERVCALLS.DOC = DOCUMENTS1.DOC INNER JOIN
                         [31.154.20.231].amaba.dbo.PART ON SERVCALLS.PART = PART.PART INNER JOIN
                         [31.154.20.231].amaba.dbo.MBA_PART ON PART.PART = MBA_PART.PART INNER JOIN
                         [31.154.20.231].amaba.dbo.DEPT ON MBA_PART.DEPT = DEPT.DEPT INNER JOIN
                         [31.154.20.231].amaba.dbo.MNFCTR ON MBA_SERNUMBERS.MNF = MNFCTR.MNF INNER JOIN
                         [31.154.20.231].amaba.dbo.CALLSTATUSES ON SERVCALLS.CALLSTATUS = CALLSTATUSES.CALLSTATUS
WHERE     (DOCUMENTS.TYPE = 'N') AND (CALLSTATUSES.CALLSTATUS = 21)
ORDER BY [Order Number]


GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPane1', @value = N'[0E232FF0-B466-11cf-A24F-00AA00A3EFFF, 1.00]
Begin DesignProperties = 
   Begin PaneConfigurations = 
      Begin PaneConfiguration = 0
         NumPanes = 4
         Configuration = "(H (1[40] 4[28] 2[11] 3) )"
      End
      Begin PaneConfiguration = 1
         NumPanes = 3
         Configuration = "(H (1[50] 4[25] 3) )"
      End
      Begin PaneConfiguration = 2
         NumPanes = 3
         Configuration = "(H (1[50] 2[25] 3) )"
      End
      Begin PaneConfiguration = 3
         NumPanes = 3
         Configuration = "(H (4 [30] 2 [40] 3))"
      End
      Begin PaneConfiguration = 4
         NumPanes = 2
         Configuration = "(H (1[70] 3) )"
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
         Left = -25
      End
      Begin Tables = 
         Begin Table = "DOCUMENTS (amaba.dbo)"
            Begin Extent = 
               Top = 183
               Left = 1366
               Bottom = 506
               Right = 1580
            End
            DisplayFlags = 280
            TopColumn = 45
         End
         Begin Table = "MBA_DOCUMENTS (amaba.dbo)"
            Begin Extent = 
               Top = 98
               Left = 1143
               Bottom = 355
               Right = 1323
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "SERNUMBERS (amaba.dbo)"
            Begin Extent = 
               Top = 0
               Left = 535
               Bottom = 270
               Right = 720
            End
            DisplayFlags = 280
            TopColumn = 14
         End
         Begin Table = "SERVCALLS (amaba.dbo)"
            Begin Extent = 
               Top = 99
               Left = 749
               Bottom = 422
               Right = 949
            End
            DisplayFlags = 280
            TopColumn = 22
         End
         Begin Table = "MBA_SERNUMBERS (amaba.dbo)"
            Begin Extent = 
               Top = 0
               Left = 299
               Bottom = 323
               Right = 477
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "DOCUMENTS1"
            Begin Extent = 
               Top = 0
               Left = 979
               Bottom = 135
               Right = 1125
            End
            DisplayFlags = 280
            TopColumn = 25
         End
         Begin Table = "PART (amaba.dbo)"
            Begin Extent = 
               Top = 375
               Left = 979
     ', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'vwGetOrderDevices';


GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPane2', @value = N'          Bottom = 665
               Right = 1232
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "MBA_PART (amaba.dbo)"
            Begin Extent = 
               Top = 558
               Left = 798
               Bottom = 672
               Right = 951
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "DEPT (amaba.dbo)"
            Begin Extent = 
               Top = 541
               Left = 586
               Bottom = 706
               Right = 763
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "MNFCTR (amaba.dbo)"
            Begin Extent = 
               Top = 65
               Left = 90
               Bottom = 212
               Right = 269
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "CALLSTATUSES (amaba.dbo)"
            Begin Extent = 
               Top = 282
               Left = 570
               Bottom = 437
               Right = 720
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
      Begin ColumnWidths = 25
         Width = 284
         Width = 1350
         Width = 1980
         Width = 1005
         Width = 1320
         Width = 1980
         Width = 2775
         Width = 1380
         Width = 2250
         Width = 1140
         Width = 1140
         Width = 1095
         Width = 975
         Width = 4635
         Width = 900
         Width = 1095
         Width = 675
         Width = 675
         Width = 1995
         Width = 585
         Width = 1050
         Width = 1500
         Width = 4635
         Width = 1500
         Width = 1500
      End
   End
   Begin CriteriaPane = 
      Begin ColumnWidths = 11
         Column = 5565
         Alias = 2295
         Table = 3240
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
', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'vwGetOrderDevices';


GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPaneCount', @value = 2, @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'vwGetOrderDevices';

*/