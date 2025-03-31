-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 31/03/2025
-- Description:	Get data from source and populate department table and CalibEquipments
-- JiraLink: 
-- =============================================
CREATE PROCEDURE stg.MergeCalibEquipmentData
AS

SET NOCOUNT ON;

BEGIN

DECLARE @dt DATETIME2(0)= GETDATE()

MERGE INTO [dbo].[Departments] as dest
USING (
	SELECT DISTINCT
	 EquipLab
	FROM stg.stg_Equip
) as source
ON dest.DepartmentName = source.EquipLab
 WHEN NOT MATCHED BY TARGET
 THEN INSERT ( [DepartmentName])
 VALUES (source.[EquipLab]);

MERGE INTO [dbo].[CalibEquipments] AS dest
USING (
	SELECT 
	     e.[EquipId] AS [SourceId]
		,d.ID AS [DepartmentId]
		,e. EquipCount AS [Quantity]
		,IIF(EquipIsActive = 1,30,32) as [StatusId]-- CalibrationEquipmentStatus 30,31,32 From [dbo].[Statuses] table
		,e.EquipCount AS [TotalQuantity]
		,e.EquipName AS [EquipmentName]
		,NULL AS [SerialNumber]
		,NULL AS [CalibratorId]
		,NULL AS [MainCategory]
		,NULL AS [NextCalibrationDate]
		,NULL AS [CarId]
		,0 AS [UpdatedByUserId]
FROM stg.stg_Equip as e
JOIN dbo.Departments as d ON e.EquipLab = d.DepartmentName
	) AS source
	ON dest.[SourceId] = source.[SourceId]
WHEN MATCHED
	THEN
		UPDATE
		SET  dest.[DepartmentId] = source.[DepartmentId]
			,dest.[Quantity] = source.[Quantity]
			,dest.[StatusId] = source.[StatusId]
			,dest.[TotalQuantity] = source.[TotalQuantity]
			,dest.[EquipmentName] = source.[EquipmentName]
			,dest.[UpdatedDate] = @dt
			,dest.[UpdatedByUserId] = 0
WHEN NOT MATCHED BY TARGET
	THEN
		INSERT (
			 [DepartmentId]
			,[Quantity]
			,[StatusId]
			,[TotalQuantity]
			,[EquipmentName]
			,[SourceId]
			,[UpdatedByUserId]
			)
		VALUES (
			 source.[DepartmentId]
			,source.[Quantity]
			,source.[StatusId]
			,source.[TotalQuantity]
			,source.[EquipmentName]
			,source.[SourceId]
			,source.[UpdatedByUserId]
			);

END