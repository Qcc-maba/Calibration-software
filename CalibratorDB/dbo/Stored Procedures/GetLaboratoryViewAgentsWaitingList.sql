
-- ==================================================
-- Author:		Shamailov Slavik
-- Create date: 17/02/2025
-- Description:	Get Work waiting list for maba agents
-- ==================================================
CREATE   PROCEDURE [dbo].[GetLaboratoryViewAgentsWaitingList]
AS
BEGIN

	SET NOCOUNT ON;

	SELECT 
	 [AgentName]
	,[CustomerNumber]
	,[CustomerName]
	,[Klita]
	FROM [dbo].[AgentsWaitingList]


END