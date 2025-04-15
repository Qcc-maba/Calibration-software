-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 30/03/2025
-- Description:	
-- JiraLink: 
-- =============================================
CREATE   PROCEDURE [dbo].[GetConversionParameter]

/*
EXEC dbo.GetConversionParameter
*/

AS

BEGIN


SELECT 
 cp.ConversionParameterId
,cp.[RTP]
,cp.[A4]
,cp.[B4]
,cp.[A7]
,cp.[B7]
,cp.[C7]
FROM [dbo].[ConversionParameters] as cp
WHERE cp.IsDeleted = 0
END