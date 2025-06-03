CREATE   PROCEDURE [dbo].[GetAllMeasurementDevicesMainClasses]
AS
-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 03/0/2025
-- Description:	
-- JiraLink: https://calibration-maba.atlassian.net/browse/MABA-43
-- =============================================

SELECT 
	Id, 
	NameHebrew,
	NameEnglish
FROM [dbo].[MeasurementDevicesMainClasses]