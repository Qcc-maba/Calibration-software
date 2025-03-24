

-- =============================================
-- Author:		<Slavik Shamailov>
-- Create date: <29/01/2025>
-- Description:	Returns all order with status:
--				"ס.המתנה חלקי","המתנה","המתנה חלקית","המתנה כ.חוץ"
-- =============================================

CREATE PROCEDURE [dbo].[GetOrdersforCustomerSupport]
AS
BEGIN
	
	--Get Orders
	--SELECT TOP (100) PERCENT DOCUMENTS.DOCNO AS OrderNumber, DOCUMENTS.CUST AS CustomerId, 
	--	dbo.tabula_hebconvert(CUSTOMERS.CUSTDES) AS CustomerName, AGENTS.AGENTNAME AS MabaContactName, 
	--	DATEADD(n,DOCUMENTS.CURDATE, '01/01/1988') AS OpenDate
	--FROM [31.154.20.231].amaba.dbo.DOCUMENTS INNER JOIN
	--	 [31.154.20.231].amaba.dbo.DOCUMENTSA ON DOCUMENTS.DOC = DOCUMENTSA.DOC INNER JOIN
	--	 [31.154.20.231].amaba.dbo.CUSTOMERS ON DOCUMENTS.CUST = CUSTOMERS.CUST INNER JOIN
	--	(SELECT STATDES, DOCSTAT
	--	 FROM  [31.154.20.231].amaba.dbo.DOCSTATS AS DOCSTATS_1
	--	 WHERE  (DOCSTAT = 63) OR
	--			(DOCSTAT = 91) OR
	--			(DOCSTAT = 58) OR
	--			(DOCSTAT = 62)) AS DOCSTATS ON DOCSTATS.DOCSTAT =DOCUMENTSA.ASSEMBLYSTATUS INNER JOIN
	--	[31.154.20.231].amaba.dbo.AGENTS ON CUSTOMERS.AGENT = AGENTS.AGENT
	--WHERE  (DOCUMENTS.TYPE = 'N')
	SELECT TOP (100) PERCENT * FROM vwCustomersOrders_FromERP

END
