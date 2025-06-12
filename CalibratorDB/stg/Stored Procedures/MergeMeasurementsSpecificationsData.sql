-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 12/06/2025
-- Description:	
-- JiraLink: 
-- =============================================
CREATE PROCEDURE stg.MergeMeasurementsSpecificationsData
AS
BEGIN

SET NOCOUNT ON;

	MERGE INTO [dbo].[MeasurementsSpecifications] AS dest
	USING (
		SELECT 
			 s.[Name]
			,d.ID as [DepartmentId]
			,s.[DescriptionHeb]
			,s.[DescriptionEng]
			,s.[Version]
			,s.[VersionDate]
			,GETDATE() as [UpdatedDate]
			,0 as [UpdateUserID]
			,s.[MeasurementsSpecificationSourceId]
		FROM [stg].[stg_MeasurementsSpecifications] as s
		JOIN [dbo].[Departments] as d ON s.[Department] = d.DepartmentName
		) AS source
		ON dest.[MeasurementsSpecificationSourceId] = source.[MeasurementsSpecificationSourceId]
	WHEN MATCHED AND
		(
			   dest.[Name] <> source.[Name]
			OR dest.[DepartmentId] <> source.[DepartmentId]
			OR COALESCE(dest.[DescriptionHeb],'') <> COALESCE(source.[DescriptionHeb],'')
			OR COALESCE(dest.[DescriptionEng],'') <> COALESCE(source.[DescriptionEng],'')
			OR dest.[Version] <> source.[Version]
			OR dest.[VersionDate] <> source.[VersionDate]
		)
		THEN
			UPDATE
			SET  dest.[Name] = source.[Name]
				,dest.[DepartmentId] = source.[DepartmentId]
				,dest.[DescriptionHeb] = source.[DescriptionHeb]
				,dest.[DescriptionEng] = source.[DescriptionEng]
				,dest.[Version] = source.[Version]
				,dest.[VersionDate] = source.[VersionDate]
				,dest.[UpdateUserID] = source.[UpdateUserID]
	WHEN NOT MATCHED BY TARGET
		THEN
			INSERT (
				 [Name]
				,[DepartmentId]
				,[DescriptionHeb]
				,[DescriptionEng]
				,[Version]
				,[VersionDate]
				,[UpdateUserID]
				,[MeasurementsSpecificationSourceId]
				)
			VALUES (
				 source.[Name]
				,source.[DepartmentId]
				,source.[DescriptionHeb]
				,source.[DescriptionEng]
				,source.[Version]
				,source.[VersionDate]
				,source.[UpdateUserID]
				,source.[MeasurementsSpecificationSourceId]
				);


END