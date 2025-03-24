-- =============================================
-- Author:		Shamailov Slavik
-- Create date: 29/12/2024
-- Description:	Get orders details screen data by 'OrderNumber' and 'MbaNum'
-- =============================================
CREATE PROCEDURE [dbo].[GetOrdersScreen_Details] 	
	@OrderNumber VARCHAR(20),
	@MbaNumber VARCHAR(20)
AS
BEGIN

DECLARE @sql NVARCHAR(MAX);	
	SET @sql = 
	'SELECT        TOP (100) PERCENT dbo.vwGetOrderDevices.[Part Description], dbo.vwGetOrderDevices.DEPTDES AS Department, dbo.vwGetOrderDevices.[Device Description] AS [Device Type], dbo.vwGetOrderDevices.[Device manufacturer], 
                         dbo.vwGetOrderDevices.[Serial Number] AS [Embedded Number], dbo.vwGetOrderDevices.NextCalibDate AS [Calibration last date], dbo.vwGetOrderDevices.[Device model], 
                         dbo.vwGetCustomersRemarks.Remarks AS ClientRemarks
	FROM            dbo.vwGetCustomersRemarks INNER JOIN
							 [31.154.20.231].amaba.dbo.DOCUMENTS ON dbo.vwGetCustomersRemarks.CUST = DOCUMENTS.CUST INNER JOIN
							 dbo.vwGetOrderDevices ON DOCUMENTS.DOCNO = dbo.vwGetOrderDevices.[Order Number]
	WHERE        (DOCUMENTS.DOCNO =  @OrderNumber) AND (dbo.vwGetOrderDevices.MBANUM = @MbaNumber)';
	
	EXEC sp_executesql @sql, N'@OrderNumber varchar(20) , @MbaNumber varchar(20)', @OrderNumber,  @MbaNumber

END
