/*
    MBA-1060: attach new corrections to the ACTIVE device only.

    The corrections sync (SSIS package MeasurmentDevicesSyncToAWS, which runs this procedure)
    joined the staging rows to dbo.MeasurementDevices on MabaID alone. Every row sharing a MabaID
    therefore got its own copy of each new correction: that is how 21-242 (19 rows), 21-260 (182)
    and 21-401 (9) came to carry identical certificates on 3-4 copies on PROD. Once the extra
    copies are retired (database/data/Retire-DuplicateMeasurementDevices.sql), the same join would
    keep feeding new corrections onto retired rows.

    Change: the device join of the corrections INSERT also requires md.IsDeleted = 0. With one
    active row per MabaID that inserts exactly what it inserted before, once. A MabaID with no
    active row is handled as an unknown one already was (MeasurementDevicesId NULL). The
    MeasurementId update above it is left as it was: it writes the same value to every copy.
    Otherwise this is the definition deployed on PROD and STAGE (identical on both, 2026-11-26).
*/
CREATE OR ALTER PROCEDURE [stg].[MergeMeasurementDevicesCorrection]
-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 25/12/2025
-- Description:	
-- JiraLink: 
-- =============================================
AS
BEGIN

SET NOCOUNT ON;

INSERT INTO [dbo].[Measurements]
           ([NameEn]
           ,[NameHe]
           ,[NoteEn]
           ,[NoteHe]
           ,[MainCategoryId]
           ,[IsDeleted]
           ,[UpdateUserID]
)
SELECT DISTINCT
 stg.ShortNameEn	
,stg.ShortNameHe	
,stg.MeasurementNameEn	
,stg.MeasurementNameHe	
,mc.ID
,0
,0
FROM [stg].[stg_MeasurementDevicesCorrections] as stg
JOIN [dbo].[MainCategories] as mc ON
        CASE stg.DepartmentHeb
            WHEN N'אלקטרוניקה' THEN N'אלקטרוניקה'
            WHEN N'טמפרטורה' THEN N'טמפרטורה ולחות'
            WHEN N'אורך וזווית' THEN N'אורך וזווית' 
            WHEN N'מסה' THEN N'מסה' 
        END = mc.MainCategoryName
LEFT JOIN [dbo].[Measurements] as dest ON dest.[NameEn] = stg.ShortNameEn
WHERE dest.[NameEn] IS NULL

;WITH cte
as
(
SELECT DISTINCT
stg.MabaID,
m.ID as MeasurementId
FROM [stg].[stg_MeasurementDevicesCorrections] as stg
JOIN [dbo].[Measurements] as m ON m.[NameEn] = stg.ShortNameEn
)
UPDATE md
SET MeasurementId = c.MeasurementId
FROM dbo.MeasurementDevices as md
JOIN cte as c ON md.MabaID = c.MabaID 
WHERE COALESCE(md.MeasurementId,0) <> COALESCE(c.MeasurementId,0)


INSERT INTO [dbo].[MeasurementDevicesCorrections]
           ([Value1]
           ,[Value2]
           ,[MeasurementDevicesId]
           ,[MeasurementId]
           ,[CorVersion]
           ,[MainCategoryId]
           ,[Equation]
           ,[CreatedDate]
           ,[IsDeleted]
           ,[UpdateUserID]
           ,[MeasurementDevicesCorrectionsSourceId]
           ,[Deviation])
SELECT 
 stg.RangeStart as [Value1]
,stg.RangeStop as [Value2]
,md.ID as [MeasurementDevicesId]
,m.ID as [MeasurementId]
,stg.CorVersion as [CorVersion]
,mc.ID as [MainCategoryId]
,stg.Value as [Equation]
,stg.DateAdded as [CreatedDate]
,0 as [IsDeleted]
,0 as [UpdateUserID]
,stg.[MeasurementDevicesCorrectionsSourceId]
,stg.[Deviation]
FROM [stg].[stg_MeasurementDevicesCorrections] as stg
JOIN [dbo].[MainCategories] as mc ON
        CASE stg.DepartmentHeb
            WHEN N'אלקטרוניקה' THEN N'אלקטרוניקה'
            WHEN N'טמפרטורה' THEN N'טמפרטורה ולחות'
            WHEN N'אורך וזווית' THEN N'אורך וזווית' 
            WHEN N'מסה' THEN N'מסה' 
        END = mc.MainCategoryName
JOIN [dbo].[Measurements] as m ON m.[NameEn] = stg.ShortNameEn
LEFT JOIN [dbo].[MeasurementDevices] as md ON md.MabaID = stg.MabaID AND md.IsDeleted = 0
LEFT JOIN [dbo].[MeasurementDevicesCorrections] as dest ON stg.[MeasurementDevicesCorrectionsSourceId] = dest.[MeasurementDevicesCorrectionsSourceId]
WHERE dest.[MeasurementDevicesCorrectionsSourceId] IS NULL


UPDATE mdc
SET MeasurementDevicesId = md.ID
FROM [dbo].[MeasurementDevicesCorrections] as mdc 
JOIN [dbo].[MeasurementDevices] as md  ON md.ID = mdc.MeasurementDevicesId
WHERE COALESCE(mdc.MeasurementDevicesId,0) <> COALESCE(md.ID,0)


END

