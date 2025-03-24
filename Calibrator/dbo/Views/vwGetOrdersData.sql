
/*CREATE VIEW [dbo].[vwGetOrdersData]
AS
SELECT        TOP (100) PERCENT DOCUMENTS.DOCNO AS OrderNumber, DATEADD(n, DOCUMENTS.CURDATE, '01/01/1988') AS OpenDate, CUSTOMERS.CUSTNAME AS CustomerID, 
                         dbo.tabula_hebconvert(CUSTOMERS.CUSTDES) AS CustomerName, CUSTOMERS.PHONE AS CustomerPhone, PHONEBOOK.NAME AS CustomerContactName, 
                         dbo.tabula_hebconvert(CUSTOMERS.STATE) AS CustomerCity, dbo.tabula_hebconvert(CUSTOMERS.ADDRESS) AS CustomerAddress, 
                         PHONEBOOK.PHONENUM AS CustomerContactPhone, AGENTS.AGENTNAME AS MBAContactName, AGENTS.PHONE AS MBAContactPhone, 
                         AGENTS.CELLPHONE AS MBAContactMobile, dbo.vwGetCustomersRemarks.Remarks AS ClientRemarks
FROM            dbo.vwGetCustomersRemarks INNER JOIN
                         [31.154.20.231].[amaba].[dbo].AGENTS INNER JOIN
                         [31.154.20.231].[amaba].[dbo].DOCUMENTS INNER JOIN
                         [31.154.20.231].[amaba].[dbo].CUSTOMERS ON DOCUMENTS.CUST = CUSTOMERS.CUST ON AGENTS.AGENT = CUSTOMERS.AGENT ON 
                         dbo.vwGetCustomersRemarks.CUST = CUSTOMERS.CUST INNER JOIN
                         [31.154.20.231].[amaba].[dbo].PHONEBOOK ON DOCUMENTS.PHONE = PHONEBOOK.PHONE
WHERE        (DOCUMENTS.TYPE = 'N')
ORDER BY OrderNumber

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
         Left = -36
      End
      Begin Tables = 
         Begin Table = "vwGetCustomersRemarks"
            Begin Extent = 
               Top = 0
               Left = 83
               Bottom = 96
               Right = 290
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "AGENTS (amaba.dbo)"
            Begin Extent = 
               Top = 174
               Left = 580
               Bottom = 399
               Right = 771
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "DOCUMENTS (amaba.dbo)"
            Begin Extent = 
               Top = 0
               Left = 811
               Bottom = 297
               Right = 1017
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "CUSTOMERS (amaba.dbo)"
            Begin Extent = 
               Top = 0
               Left = 320
               Bottom = 303
               Right = 550
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "PHONEBOOK (amaba.dbo)"
            Begin Extent = 
               Top = 0
               Left = 1046
               Bottom = 256
               Right = 1256
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
      Begin ColumnWidths = 16
         Width = 284
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
         Width ', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'vwGetOrdersData';


GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPane2', @value = N'= 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
      End
   End
   Begin CriteriaPane = 
      Begin ColumnWidths = 11
         Column = 3045
         Alias = 2115
         Table = 1170
         Output = 720
         Append = 1400
         NewValue = 1170
         SortType = 1350
         SortOrder = 1410
         GroupBy = 1350
         Filter = 3375
         Or = 1350
         Or = 1350
         Or = 1350
      End
   End
End
', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'vwGetOrdersData';


GO
EXECUTE sp_addextendedproperty @name = N'MS_DiagramPaneCount', @value = 2, @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'VIEW', @level1name = N'vwGetOrdersData';

*/