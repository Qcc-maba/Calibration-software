

/*CREATE VIEW [dbo].[vwCustomersOrders_FromERP]
AS
SELECT DISTINCT 
                         TOP (100) PERCENT DOCUMENTS.DOCNO AS OrderNumber, DOCUMENTS.CUST AS CustomerId, dbo.tabula_hebconvert(CUSTOMERS.CUSTDES) AS CustomerName, 
                         AGENTS.AGENTNAME AS MabaContactName, DEPT.DEPTDES AS Department, DATEADD(n, DOCUMENTS.CURDATE, '01/01/1988') AS OpenDate
FROM            [31.154.20.231].amaba.dbo.DEPT INNER JOIN
                         [31.154.20.231].amaba.dbo.MBA_DOCUMENTS ON DEPT.DEPT = MBA_DOCUMENTS.DEPT INNER JOIN
                         [31.154.20.231].amaba.dbo.DOCUMENTS INNER JOIN
                         [31.154.20.231].amaba.dbo.DOCUMENTSA ON DOCUMENTS.DOC = DOCUMENTSA.DOC INNER JOIN
                         [31.154.20.231].amaba.dbo.CUSTOMERS ON DOCUMENTS.CUST = CUSTOMERS.CUST INNER JOIN
                         [31.154.20.231].amaba.dbo.AGENTS ON AGENTS.AGENT = CUSTOMERS.AGENT ON DOCUMENTS.DOC = MBA_DOCUMENTS.DOC_N
WHERE        (DOCUMENTSA.ASSEMBLYSTATUS IN
                             (SELECT        DOCSTAT
                               FROM            [31.154.20.231].amaba.dbo.DOCSTATS
                               WHERE        (DOCSTAT = 63) OR
                                                         (DOCSTAT = 91) OR
                                                         (DOCSTAT = 58) OR
                                                         (DOCSTAT = 62)))

GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPane1', @value = N'[0E232FF0-B466-11cf-A24F-00AA00A3EFFF, 1.00]
Begin DesignProperties = 
   Begin PaneConfigurations = 
      Begin PaneConfiguration = 0
         NumPanes = 4
         Configuration = "(H (1[40] 4[20] 2[20] 3) )"
      End
      Begin PaneConfiguration = 1
         NumPanes = 3
         Configuration = "(H (1 [50] 4 [25] 3))"
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
         Begin Table = "DEPT (amaba.dbo)"
            Begin Extent = 
               Top = 6
               Left = 38
               Bottom = 136
               Right = 227
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "MBA_DOCUMENTS (amaba.dbo)"
            Begin Extent = 
               Top = 6
               Left = 265
               Bottom = 136
               Right = 435
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "DOCUMENTS (amaba.dbo)"
            Begin Extent = 
               Top = 6
               Left = 473
               Bottom = 136
               Right = 687
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "DOCUMENTSA (amaba.dbo)"
            Begin Extent = 
               Top = 6
               Left = 725
               Bottom = 136
               Right = 919
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "CUSTOMERS (amaba.dbo)"
            Begin Extent = 
               Top = 138
               Left = 38
               Bottom = 268
               Right = 268
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "AGENTS (amaba.dbo)"
            Begin Extent = 
               Top = 138
               Left = 306
               Bottom = 268
               Right = 497
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
   End
   Begin CriteriaP', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'vwCustomersOrders_FromERP';


GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPane2', @value = N'ane = 
      Begin ColumnWidths = 11
         Column = 1440
         Alias = 900
         Table = 1170
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
', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'vwCustomersOrders_FromERP';


GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPaneCount', @value = 2, @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'vwCustomersOrders_FromERP';

*/