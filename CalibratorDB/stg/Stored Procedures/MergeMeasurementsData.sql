-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 12/06/2025
-- Description:	
-- JiraLink: 
-- =============================================
CREATE PROCEDURE [stg].[MergeMeasurementsData]
AS
BEGIN

SET NOCOUNT ON;

MERGE INTO [dbo].[Measurements] AS dest
USING (
	SELECT
	     m.[NameEn]
		,m.[NameHe]
		,m.[NoteEn]
		,m.[NoteHe]
		,d.ID as [MainCategoryId]
		,GETDATE() AS [UpdatedDate]
		,0 AS [UpdateUserID]
		,m.[MeasurementIdFromSource]
	FROM [stg].[stg_Measurements] as m
	JOIN [dbo].[MainCategories] as d ON m.[Department] = d.[MainCategoryName]
	) AS source
	ON dest.[MeasurementIdFromSource] = source.[MeasurementIdFromSource]
WHEN MATCHED AND 
	(
	   COALESCE(dest.[NameEn],'') <> COALESCE(source.[NameEn],'')
	OR COALESCE(dest.[NameHe],'') <> COALESCE(source.[NameHe],'')
	OR COALESCE(dest.[NoteEn],'') <> COALESCE(source.[NoteEn],'')
	OR COALESCE(dest.[NoteHe],'') <> COALESCE(source.[NoteHe],'')
	OR dest.[MainCategoryId] <> source.[MainCategoryId]
	)
	THEN
		UPDATE
		SET  dest.[NameEn] = source.[NameEn]
			,dest.[NameHe] = source.[NameHe]
			,dest.[NoteEn] = source.[NoteEn]
			,dest.[NoteHe] = source.[NoteHe]
			,dest.[MainCategoryId] = source.[MainCategoryId]
			,dest.[UpdatedDate] = source.[UpdatedDate]
			,dest.[UpdateUserID] = source.[UpdateUserID]
WHEN NOT MATCHED BY TARGET
	THEN
		INSERT (
             [NameEn]
			,[NameHe]
			,[NoteEn]
			,[NoteHe]
			,[MainCategoryId]
			,[UpdateUserID]
			,[MeasurementIdFromSource]
			)
		VALUES (
			 source.[NameEn]
			,source.[NameHe]
			,source.[NoteEn]
			,source.[NoteHe]
			,source.[MainCategoryId]
			,source.[UpdateUserID]
			,source.[MeasurementIdFromSource]
			);

END