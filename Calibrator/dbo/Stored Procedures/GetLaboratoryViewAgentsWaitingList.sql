-- ==================================================
-- Author:		Shamailov Slavik
-- Create date: 17/02/2025
-- Description:	Get Work waiting list for maba agents
-- ==================================================
CREATE PROCEDURE [GetLaboratoryViewAgentsWaitingList]
AS
BEGIN

	SET NOCOUNT ON;

	SELECT  distinct   servcalls_view.[agent name],servcalls_view.[Customer Number], servcalls_view.[Customer Name], servcalls_view.klita
	FROM            [31.154.20.231].amaba.dbo.servcalls_view INNER JOIN
							 [31.154.20.231].amaba.dbo.DOCSTATS ON servcalls_view.[סטטוס תעודת קליטה] = DOCSTATS.STATDES
	WHERE        (DOCSTATS.DOCSTAT = 62) OR
							 (DOCSTATS.DOCSTAT = 63) OR
							 (DOCSTATS.DOCSTAT = 91) OR
							 (DOCSTATS.DOCSTAT = 58)
	ORDER BY servcalls_view.[agent name], servcalls_view.klita

END
