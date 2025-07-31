-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 10/06/2025
-- Description:	
-- JiraLink: 
-- =============================================
CREATE   PROCEDURE [stg].[MergeMeasurementDeviceUnitGroupsData]
AS
BEGIN

SET NOCOUNT ON;

	MERGE INTO [dbo].[MeasurementDeviceUnitGroups] AS dest
	USING (
		SELECT
			ug.[NameEn],
			ug.[NameHe],
			ug.[Description],
			ug.[Symbol],
			ug.[HelpLink],
			ug.[MeasurementDevicesUnitGroupSourceId],
			GETDATE() as [UpdatedDate],
			0 as [UpdateUserID]
		FROM [stg].[stg_MeasurementDeviceUnitGroups] as ug
		) AS source
		ON dest.[MeasurementDevicesUnitGroupSourceId] = source.[MeasurementDevicesUnitGroupSourceId]
	WHEN MATCHED AND
			 (dest.[NameEn] <> source.[NameEn]
			 OR dest.[NameHe] <> source.[NameHe]
			 OR dest.[Description] <> source.[Description]
			 OR dest.[Symbol] <> source.[Symbol]
			 OR dest.[HelpLink] <> source.[HelpLink])
		THEN
			UPDATE
			SET  dest.[NameEn] = source.[NameEn]
				,dest.[NameHe] = source.[NameHe]
				,dest.[Description] = source.[Description]
				,dest.[Symbol] = source.[Symbol]
				,dest.[HelpLink] = source.[HelpLink]
				,dest.[UpdatedDate] = source.[UpdatedDate]
				,dest.[UpdateUserID] = source.[UpdateUserID]

	WHEN NOT MATCHED BY TARGET
		THEN
			INSERT (
				 [NameEn]
				,[NameHe]
				,[Description]
				,[Symbol]
				,[HelpLink]
				,[UpdateUserID]
				,[MeasurementDevicesUnitGroupSourceId]
				)
			VALUES (
				 source.[NameEn]
				,source.[NameHe]
				,source.[Description]
				,source.[Symbol]
				,source.[HelpLink]
				,source.[UpdateUserID]
				,source.[MeasurementDevicesUnitGroupSourceId]
				);
UPDATE u
SET u.MainCategoryId = mc.ID
FROM (VALUES
    (N'אורך', N'אורך וזווית'),
    (N'מסה', N'מסה'),
    (N'זמן', N'זמן'),
    (N'זרם', N'אלקטרוניקה'),
    (N'כמות חלקיקים', N'רדיומטריה'),
    (N'עוצמת האור', N'רדיומטריה'),
    (N'תאוצה', N'כוח'),
    (N'זווית', N'אורך וזווית'),
    (N'תאוצה זוויתית', N'מומנט'),
    (N'מהירות זוויתית', N'מומנט'),
    (N'תנע זוויתית', N'מומנט'),
    (N'שטח', N'אורך וזווית'),
    (N'צפיפות משטחית', N'כללי'),
    (N'צפיפות', N'כללי'),
    (N'מטען חשמלי', N'אלקטרוניקה'),
    (N'ההתנגדות חשמלית', N'אלקטרוניקה'),
    (N'אנרגיה', N'כללי'),
    (N'כח', N'כוח'),
    (N'תדירות', N'אלקטרוניקה'),
    (N'צפיפות קווית', N'כללי'),
    (N'שטף מגנטי', N'אלקטרוניקה'),
    (N'תנע', N'כוח'),
    (N'הספק', N'אלקטרוניקה'),
    (N'לחץ', N'לחץ'),
    (N'Solid angle', N'כללי'),
    (N'מהירות', N'מהירות אוויר'),
    (N'מומנט סיבוב', N'מומנט'),
    (N'מתח', N'אלקטרוניקה'),
    (N'נפח', N'נפח'),
    (N'עבודה', N'כללי'),
    (N'טמפרטורה', N'טמפרטורה ולחות'),
    (N'ריכוז', N'תמיסות'),
    (N'לחץ אבסולוטי', N'לחץ')
) AS ugd (UnitGroup, Department)
JOIN [dbo].[MainCategories] as mc ON ugd.Department = mc.MainCategoryName
JOIN [dbo].[MeasurementDeviceUnitGroups] as u ON ugd.UnitGroup = u.[NameHe]
WHERE u.MainCategoryId IS NULL
END