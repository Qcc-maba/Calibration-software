-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 30/03/2025
-- Description:	
-- JiraLink: 
-- =============================================
CREATE   PROCEDURE dbo.CreateConversionParameter
 @RTP decimal(35,15)= NULL
,@A4 decimal(35,15)	= NULL
,@B4 decimal(35,15)	= NULL
,@A7 decimal(35,15)	= NULL
,@B7 decimal(35,15)	= NULL
,@C7 decimal(35,15)	= NULL

/*
EXEC dbo.CreateConversionParameter
 @RTP = 25.4011
,@A4  = -0.00010288
,@B4  = -0.0000052588
,@A7  = -0.00011873
,@B7  = -0.0000016079
,@C7  = -0.000003391
*/

AS

BEGIN

IF EXISTS 
(SELECT 1 FROM 
[dbo].[ConversionParameters]
WHERE 
   COALESCE([RTP],0) = COALESCE(@RTP,0)
AND COALESCE([A4],0) = COALESCE(@A4,0)
AND COALESCE([B4],0) = COALESCE(@B4,0)
AND COALESCE([A7],0) = COALESCE(@A7,0)
AND COALESCE([B7],0) = COALESCE(@B7,0)
AND COALESCE([C7],0) = COALESCE(@C7,0)
)
THROW 51000, 'Conversion parameter already exists.', 1;

INSERT INTO [dbo].[ConversionParameters]
           ([RTP]
           ,[A4]
           ,[B4]
           ,[A7]
           ,[B7]
           ,[C7])
     VALUES(
			 @RTP
			,@A4
			,@B4
			,@A7
			,@B7
			,@C7)
END