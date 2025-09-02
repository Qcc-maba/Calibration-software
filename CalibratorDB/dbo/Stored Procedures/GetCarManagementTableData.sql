
-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 20/03/2025
-- Description:	This SP should get data for the car management table
-- JiraLink: https://calibration-maba.atlassian.net/browse/MABA-169
-- =============================================
CREATE   PROCEDURE [dbo].[GetCarManagementTableData]
@LicenseNumber NVARCHAR(50) = NULL,
@Model NVARCHAR(50) = NULL,
@NumberOfSeats INT = NULL,
@StatusId INT = -1,
@OwnerId INT = -1,
@AssignedCalibratorId INT = -1,
@TreatmentPeriod INT = -1,
@NextTreatmentDate DATE = NULL,
@NextTestDate DATE = NULL,
@AssociatedEquipmentId NVARCHAR(200) = NULL, 
@RowsPerPage INT = 50,
@PageNumber INT = 1,
@OrderBy NVARCHAR(255) = N'Model',-- Only this list of valid values for parameter CarId|Model|LicenseNumber|Seats|TreatmentPeriod|NextTreatmentDate|NextYearlyTestDate|OwnerId|OwnerFullName|CarStatusId|StatusDescriptionENG|StatusDescriptionHEB|AssignedCalibratorId|CalibratorFullName|EquipmentId|EquipmentName
@OrderByAsc BIT = 1,
@CalibratorFullName NVARCHAR(200) = NULL,
@StatusDescription NVARCHAR(255) = NULL, 
@EquipmentName NVARCHAR(255) = NULL,
@GlobalSearch NVARCHAR(200) = NULL

/*
EXEC dbo.GetCarManagementTableData 
@OrderBy ='CarId', 
@Model = 'סקודה רומסטר',
@OrderByAsc = 1,
@RowsPerPage = 5000
*/

AS
BEGIN

SET NOCOUNT ON;

IF @OrderBy NOT IN (N'CarId',N'Model',N'LicenseNumber',N'Seats',N'TreatmentPeriod',N'NextTreatmentDate',N'NextYearlyTestDate',N'OwnerId',N'OwnerFullName',N'CarStatusId',N'StatusDescriptionENG',N'StatusDescriptionHEB',N'AssignedCalibratorId',N'CalibratorFullName',N'EquipmentId',N'EquipmentName')
THROW 51000, 'Incorrect value for parameter @OrderBy.', 1;

DROP TABLE IF EXISTS #AssociatedEquipmentIDs
CREATE TABLE #AssociatedEquipmentIDs
(
EquipmentId INT
)
DECLARE @AssociatedEquipment NVARCHAR(200) = @AssociatedEquipmentId

INSERT #AssociatedEquipmentIDs(EquipmentId)
SELECT Value 
FROM dbo.ParseCSVToTable(@AssociatedEquipment)

IF @CalibratorFullName IS NOT NULL
BEGIN
DROP TABLE IF EXISTS #Calibrators
CREATE TABLE #Calibrators
(
CalibratorId INT
)
INSERT #Calibrators(CalibratorId)
SELECT u.ID FROM [dbo].[Users] as u 
JOIN [dbo].[UserRoles] as r ON u.UserRoleId = r.UserRoleId
WHERE u.IsActive = 1 AND r.UserRoleDescriptionENG = 'Calibrator'
      AND (
        u.LastName LIKE '%'+@CalibratorFullName+'%' 
		OR u.FirstName LIKE '%'+@CalibratorFullName+'%'
		OR u.FirstNameEng LIKE '%'+@CalibratorFullName+'%'
		OR u.LastNameEng LIKE '%'+@CalibratorFullName+'%'
		OR CONCAT(u.FirstName,' ',u.LastName) LIKE '%'+@CalibratorFullName+'%'
		OR CONCAT(u.FirstNameEng,' ',u.LastNameEng) LIKE '%'+@CalibratorFullName+'%'
		OR CONCAT(u.LastName,' ',u.FirstName) LIKE '%'+@CalibratorFullName+'%'
		OR CONCAT(u.LastNameEng,' ',u.FirstNameEng) LIKE '%'+@CalibratorFullName+'%'
)
END

IF @EquipmentName IS NOT NULL
BEGIN
DROP TABLE IF EXISTS #EquipmentName
CREATE TABLE #EquipmentName
(
EquipmentId INT
)
INSERT #EquipmentName(EquipmentId)
SELECT u.ID FROM [dbo].[MeasurementDevices] as u 
WHERE u.[Description] LIKE '%'+@EquipmentName+'%' and u.IsDeleted = 0
END

IF @StatusDescription IS NOT NULL
BEGIN
DROP TABLE IF EXISTS #StatusDescriptions
CREATE TABLE #StatusDescriptions
(
StatusId INT
)
INSERT #StatusDescriptions(StatusId)
SELECT s.StatusId
	FROM [dbo].[Statuses] as s
	JOIN [dbo].[StatusesCategories] as c On s.[StatusCategoryId] = c.[StatusCategoryId]
	WHERE c.StatusDescriptionENG = 'CarStatus'
	AND (s.StatusDescriptionENG LIKE '%'+@StatusDescription+'%'
    OR s.StatusDescriptionHEB LIKE '%'+@StatusDescription+'%'
	)
END

DECLARE @sql NVARCHAR(MAX) =
CONCAT(
'SELECT c.[CarId]
      ,c.[Model]
      ,c.[LicenseNumber]
      ,c.[Seats]
      ,c.[TreatmentPeriod]
      ,COALESCE(c.[NextTreatmentDate], ''1900-01-01'') as [NextTreatmentDate]
      ,COALESCE(c.[NextYearlyTestDate], ''1900-01-01'') as NextYearlyTestDate
      ,c.[OwnerId]
	  ,CONCAT(u1.LastName,'' '', u1.FirstName) as OwnerFullName
	  ,CONCAT(u1.LastNameEng,'' '', u1.FirstNameEng) as OwnerFullNameENG
      ,c.[CarStatusId]
	  ,s.[StatusDescriptionENG]
	  ,s.[StatusDescriptionHEB]
      ,c.[AssignedCalibratorId]
	  ,CONCAT(u.LastName,'' '', u.FirstName) as CalibratorFullName
	  ,CONCAT(u.FirstNameEng,'' '', u.LastNameEng) as CalibratorFullNameENG
	  ,STRING_AGG(ce.MeasurementDeviceId,'','') as EquipmentId
	  ,STRING_AGG(e.Description,'','') as EquipmentName
	  ,COUNT(1) OVER(PARTITION BY 1 ORDER BY c.[CarId] ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING ) as ItemsCount
  FROM [dbo].[Cars] as c
  JOIN [dbo].[Statuses] as s ON c.[CarStatusId] = s.[StatusId]
  LEFT JOIN [dbo].[Users] as u ON c.[AssignedCalibratorId] = u.[ID]
  LEFT JOIN [dbo].[Users] as u1 ON c.[OwnerId] = u1.[ID]
  LEFT JOIN [dbo].[CarsToEquipment] as ce ON c.[CarId] = ce.[CarId] AND ce.IsDeleted = 0'
  ,CASE WHEN @AssociatedEquipmentId IS NOT NULL THEN ' JOIN #AssociatedEquipmentIDs as f ON ce.[MeasurementDeviceId] = f.[EquipmentId] ' ELSE ' ' END
  ,CASE WHEN @CalibratorFullName IS NOT NULL THEN ' JOIN #Calibrators as cf ON c.[AssignedCalibratorId] = cf.[CalibratorId] ' ELSE ' ' END
  ,CASE WHEN @EquipmentName IS NOT NULL THEN ' JOIN #EquipmentName as cen ON ce.MeasurementDeviceId = cen.[EquipmentId] ' ELSE ' ' END
  ,CASE WHEN @StatusDescription IS NOT NULL THEN ' JOIN #StatusDescriptions as sdf ON c.[CarStatusId] = sdf.[StatusId] ' ELSE ' ' END
  ,'LEFT JOIN [dbo].[MeasurementDevices] as e ON ce.[MeasurementDeviceId] = e.ID  AND e.IsDeleted = 0
  WHERE c.IsDeleted = 0'
  ,CASE WHEN @LicenseNumber IS NOT NULL THEN' AND c.[LicenseNumber] = N'''+ @LicenseNumber+''' 'ELSE ' ' END
  ,CASE WHEN @Model IS NOT NULL THEN ' AND c.[Model] = N'''+ @Model+''' 'ELSE ' ' END
  ,CASE WHEN @NumberOfSeats > 0 THEN' AND c.[Seats] = '+CAST(@NumberOfSeats as NVARCHAR(50))+' 'ELSE ' ' END
  ,CASE WHEN @StatusId > 0 THEN' AND c.[CarStatusId] = '+CAST(@StatusId as NVARCHAR(50))+' 'ELSE ' ' END
  ,CASE WHEN @OwnerId > 0 THEN ' AND c.[OwnerId] = '+CAST(@OwnerId as NVARCHAR(50))+' 'ELSE ' ' END
  ,CASE WHEN @AssignedCalibratorId > 0 THEN ' AND c.[AssignedCalibratorId] = '+CAST(@AssignedCalibratorId as NVARCHAR(50))+' 'ELSE ' ' END
  ,CASE WHEN @TreatmentPeriod > 0 THEN ' AND c.[TreatmentPeriod] = '+CAST(@TreatmentPeriod as NVARCHAR(50))+' 'ELSE ' ' END
  ,CASE WHEN @NextTreatmentDate IS NOT NULL AND @NextTreatmentDate > '1900-01-01' THEN ' AND c.[NextTreatmentDate] = '''+ CAST(@NextTreatmentDate AS NVARCHAR(20))+''' ' ELSE ' ' END
  ,CASE WHEN @NextTestDate IS NOT NULL AND @NextTestDate > '1900-01-01' THEN' AND c.[NextYearlyTestDate] = '''+ CAST(@NextTestDate AS NVARCHAR(20))+''' 'ELSE ' ' END
  ,'  GROUP BY 
	   c.[CarId]
      ,c.[Model]
      ,c.[LicenseNumber]
      ,c.[Seats]
      ,c.[TreatmentPeriod]
      ,COALESCE(c.[NextTreatmentDate], ''1900-01-01'') 
      ,COALESCE(c.[NextYearlyTestDate], ''1900-01-01'')
      ,c.[OwnerId]
	  ,CONCAT(u1.LastName,'' '', u1.FirstName)
	  ,CONCAT(u1.LastNameEng,'' '', u1.FirstNameEng) 
      ,c.[CarStatusId]
	  ,s.[StatusDescriptionENG]
	  ,s.[StatusDescriptionHEB]
      ,c.[AssignedCalibratorId]
	  ,CONCAT(u.LastName,'' '', u.FirstName)
	  ,CONCAT(u.FirstNameEng,'' '', u.LastNameEng) '
	,CASE WHEN @GlobalSearch IS NOT NULL THEN ' HAVING CONCAT(c.[LicenseNumber],c.[Model],s.[StatusDescriptionHEB],CONCAT(u.LastName,'' '', u.FirstName),c.[TreatmentPeriod],STRING_AGG(e.Description,'','')) LIKE N''%'+ @GlobalSearch +'%'''ELSE ' ' END
  ,  'ORDER BY ' , QUOTENAME(@OrderBy) , CASE WHEN @OrderByAsc = 1 THEN ' ASC' ELSE ' DESC' END , '
    OFFSET ',(@PageNumber -1) * @RowsPerPage,' ROWS FETCH NEXT ', @RowsPerPage ,'ROWS ONLY OPTION(RECOMPILE); ')
PRINT @sql
EXEC sp_executesql @sql

END