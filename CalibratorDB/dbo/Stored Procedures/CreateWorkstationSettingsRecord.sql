-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 15/01/2026
-- Description:	This SP set configuration for COM ports and PC related staff
-- JiraLink: https://calibration-maba.atlassian.net/browse/MABA-558
-- =============================================
CREATE    PROCEDURE [dbo].[CreateWorkstationSettingsRecord]
@json NVARCHAR(MAX)=''
,@LoggedInUserEmail NVARCHAR(50)
AS
SET NOCOUNT ON;

DECLARE @LoggedInUserId INT 
DECLARE @SourceId TINYINT

SELECT 
 @LoggedInUserId  = d.UserId 
,@SourceId = d.SourceId
FROM dbo.GetSourceFilterByEmail(@LoggedInUserEmail) as d

DROP TABLE IF EXISTS #feed
CREATE TABLE #feed
(
    CalibratorWorkstationName nvarchar(200) COLLATE Latin1_General_100_CI_AI_SC,
    CalibratorId int,      
    PCIsDeleted bit,
    COMAddress nvarchar(50) COLLATE Latin1_General_100_CI_AI_SC
)
INSERT #feed
(
CalibratorWorkstationName,
CalibratorId,
PCIsDeleted,
COMAddress
)
SELECT
    a.CalibratorWorkstationName COLLATE Latin1_General_100_CI_AI_SC,
    a.CalibratorId,
    a.PCIsDeleted,
    j.COMAddress COLLATE Latin1_General_100_CI_AI_SC
FROM OPENJSON(@json)
WITH
(
    CalibratorWorkstationName        nvarchar(200) '$.CalibratorWorkstationName',
    CalibratorId  int           '$.CalibratorId',
    PCIsDeleted   bit           '$.IsDeleted',
    COMInfo       nvarchar(max) '$.COMInfo' AS JSON
) a
OUTER APPLY OPENJSON(a.COMInfo)
WITH
(
    COMAddress   nvarchar(50) '$.COMAddress'
) j;


INSERT [dbo].[CalibratorWorkstationSettings](
[CalibratorWorkstationName], 
[CalibratorId]
)
SELECT DISTINCT
f.CalibratorWorkstationName,
f.CalibratorId
FROM #feed as f
LEFT JOIN [dbo].[CalibratorWorkstationSettings] as d ON f.CalibratorWorkstationName = d.CalibratorWorkstationName
WHERE d.CalibratorWorkstationName IS NULL


UPDATE d
SET
CalibratorId = f.CalibratorId,
UpdatedDate = GETDATE(),
UpdateUserID = @LoggedInUserId,
IsDeleted = f.PCIsDeleted
FROM #feed as f
JOIN [dbo].[CalibratorWorkstationSettings] as d ON f.CalibratorWorkstationName = d.CalibratorWorkstationName

INSERT [dbo].[COMPortSettings]
(
   [CalibratorWorkstationSettingId],
   [COMAddress] 
)
SELECT
d.CalibratorWorkstationSettingId,
f.COMAddress
FROM #feed as f
JOIN [dbo].[CalibratorWorkstationSettings] as d ON f.CalibratorWorkstationName = d.CalibratorWorkstationName
LEFT JOIN [dbo].[COMPortSettings] as cs ON d.CalibratorWorkstationSettingId = cs.CalibratorWorkstationSettingId AND cs.COMAddress = f.COMAddress AND cs.IsDeleted = 0
WHERE cs.COMAddress IS NULL AND d.IsDeleted = 0 

UPDATE cs
SET 
    IsDeleted = 1,
    UpdatedDate = GETDATE(),
    UpdateUserID = @LoggedInUserId
FROM [dbo].[COMPortSettings] as cs
JOIN [dbo].[CalibratorWorkstationSettings] as d ON cs.CalibratorWorkstationSettingId = d.CalibratorWorkstationSettingId
JOIN #feed as filt ON filt.CalibratorWorkstationName = d.CalibratorWorkstationName
LEFT JOIN #feed as f ON d.CalibratorWorkstationSettingId = cs.CalibratorWorkstationSettingId AND cs.COMAddress = f.COMAddress
WHERE f.CalibratorId IS NULL