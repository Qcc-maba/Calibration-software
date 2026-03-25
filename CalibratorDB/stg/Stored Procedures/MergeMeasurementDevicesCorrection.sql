CREATE  PROCEDURE [stg].[MergeMeasurementDevicesCorrection]
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
LEFT JOIN [dbo].[MeasurementDevices] as md ON md.MabaID = stg.MabaID
LEFT JOIN [dbo].[MeasurementDevicesCorrections] as dest ON stg.[MeasurementDevicesCorrectionsSourceId] = dest.[MeasurementDevicesCorrectionsSourceId]
WHERE dest.[MeasurementDevicesCorrectionsSourceId] IS NULL


UPDATE mdc
SET MeasurementDevicesId = md.ID
FROM [dbo].[MeasurementDevicesCorrections] as mdc 
JOIN [dbo].[MeasurementDevices] as md  ON md.ID = mdc.MeasurementDevicesId
WHERE COALESCE(mdc.MeasurementDevicesId,0) <> COALESCE(md.ID,0)


END