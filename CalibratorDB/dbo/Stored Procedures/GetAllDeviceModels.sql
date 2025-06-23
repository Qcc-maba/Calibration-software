-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 15/05/2025
-- Description:	Get device models
-- JiraLink: 
-- =============================================
CREATE    PROCEDURE [dbo].[GetAllDeviceModels]
AS
SELECT DISTINCT DeviceModel
FROM [dbo].[OrderDetailsItems]