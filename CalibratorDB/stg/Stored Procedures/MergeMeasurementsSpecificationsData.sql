-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 12/06/2025
-- Description:	
-- JiraLink: 
-- =============================================
CREATE PROCEDURE [stg].[MergeMeasurementsSpecificationsData]
AS
BEGIN

SET NOCOUNT ON;

	MERGE INTO [dbo].[MeasurementsSpecifications] AS dest
	USING (
		SELECT 
			 s.[Name]
			,d.ID as [MainCategoryId]
			,s.[DescriptionHeb]
			,s.[DescriptionEng]
			,s.[Version]
			,s.[VersionDate]
			,GETDATE() as [UpdatedDate]
			,0 as [UpdateUserID]
			,s.[MeasurementsSpecificationSourceId]
		FROM [stg].[stg_MeasurementsSpecifications] as s
		JOIN [dbo].[MainCategories] as d ON s.[Department] = d.[MainCategoryName]
		) AS source
		ON dest.[MeasurementsSpecificationSourceId] = source.[MeasurementsSpecificationSourceId]
	WHEN MATCHED AND
		(
			   dest.[Name] <> source.[Name]
			OR dest.[MainCategoryId] <> source.[MainCategoryId]
			OR COALESCE(dest.[DescriptionHeb],'') <> COALESCE(source.[DescriptionHeb],'')
			OR COALESCE(dest.[DescriptionEng],'') <> COALESCE(source.[DescriptionEng],'')
			OR dest.[Version] <> source.[Version]
			OR dest.[VersionDate] <> source.[VersionDate]
		)
		THEN
			UPDATE
			SET  dest.[Name] = source.[Name]
				,dest.[MainCategoryId] = source.[MainCategoryId]
				,dest.[DescriptionHeb] = source.[DescriptionHeb]
				,dest.[DescriptionEng] = source.[DescriptionEng]
				,dest.[Version] = source.[Version]
				,dest.[VersionDate] = source.[VersionDate]
				,dest.[UpdateUserID] = source.[UpdateUserID]
	WHEN NOT MATCHED BY TARGET
		THEN
			INSERT (
				 [Name]
				,[MainCategoryId]
				,[DescriptionHeb]
				,[DescriptionEng]
				,[Version]
				,[VersionDate]
				,[UpdateUserID]
				,[MeasurementsSpecificationSourceId]
				)
			VALUES (
				 source.[Name]
				,source.[MainCategoryId]
				,source.[DescriptionHeb]
				,source.[DescriptionEng]
				,source.[Version]
				,source.[VersionDate]
				,source.[UpdateUserID]
				,source.[MeasurementsSpecificationSourceId]
				);


END