-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 02/04/2025
-- Description:	Get all calibration equipments
-- JiraLink: 
-- =============================================
CREATE   PROCEDURE dbo.GetAllEquipment
AS

SELECT c.[ID]
      ,c.[EquipmentName] AS Title
	  ,c.MainCategory
      ,s.[StatusId]
	  ,s.[StatusDescriptionENG]	
	  ,s.[StatusDescriptionHEB]   
      -----------------------------
	  ,'LA43342' as OrderNumber
	  ,1 as OrderId
FROM [dbo].[CalibEquipments] as c
JOIN [dbo].[Statuses] as s ON c.StatusId = s.StatusId