-- =============================================
-- Author:		Shamailov Slavik
-- Create date: 29/12/2024
-- Description:	Get orders details screen data by 'OrderNumber'
-- =============================================
CREATE PROCEDURE [dbo].[GetOrdersScreen_ShortList] 	
	@OrderNumber VARCHAR(20)
AS
BEGIN

	DECLARE @sql NVARCHAR(MAX);	
	SET @sql = 
	'SELECT [Part Description], DEPTDES AS Department, [Device Description] AS [Device Type], MBANUM, [Serial Number]
	 FROM dbo.vwGetOrderDevices
	 WHERE	([Order Number] = @OrderNumber)';
	
	EXEC sp_executesql @sql, N'@OrderNumber varchar(20)', @OrderNumber


END
