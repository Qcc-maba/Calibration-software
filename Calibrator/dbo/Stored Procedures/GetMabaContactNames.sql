-- =============================================
-- Author:		Shamailov Slavik
-- Create date: 03/02/2025
-- Description:	Return list of MABA contact names
-- =============================================
CREATE PROCEDURE [dbo].[GetMabaContactNames]
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	SELECT TOP (100) PERCENT AGENT Id, AGENTNAME MabaContactName
	FROM   [31.168.173.93].amaba.dbo.AGENTS
	WHERE  (AGENTNAME <> '')
	ORDER BY AGENTNAME

END