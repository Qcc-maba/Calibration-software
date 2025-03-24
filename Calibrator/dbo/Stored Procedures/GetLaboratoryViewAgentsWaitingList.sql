
-- ==================================================
-- Author:		Shamailov Slavik
-- Create date: 17/02/2025
-- Description:	Get Work waiting list for maba agents
-- ==================================================
CREATE   PROCEDURE [dbo].[GetLaboratoryViewAgentsWaitingList]
AS
BEGIN

	SET NOCOUNT ON;

	SELECT DISTINCT sv.[agent name] AS AgentName
		,sv.[Customer Number] AS CustomerNumber
		,sv.[Customer Name] AS CustomerName
		,sv.klita as Klita
	FROM [31.154.20.231].amaba.dbo.servcalls_view as sv
	INNER JOIN [31.154.20.231].amaba.dbo.DOCSTATS ON sv.[סטטוס תעודת קליטה] = DOCSTATS.STATDES
	WHERE DOCSTATS.DOCSTAT IN( 62,63,91,58)
	ORDER BY sv.[agent name]
		,sv.klita


END