-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 24/03/2025
-- Description:	This SP should edit a calendar event. It must take the event title, start time, end time, and a string with participant ids divided by comma.
-- JiraLink: https://calibration-maba.atlassian.net/browse/MABA-170
-- =============================================
CREATE    PROCEDURE [dbo].[GetEquipmentManagementTableData]
@RowsPerPage INT = 50,
@PageNumber INT = 1,
@OrderBy NVARCHAR(30) = N'DepartmentName',
@OrderByAsc BIT = 1,
@DepartmentId INT = -1,
@EquipmentName NVARCHAR(255)= NULL,
@SerialNumber NVARCHAR(100)= NULL,
@StatusId INT = -1,
@CalibratorId INT = -1,
@CarId INT = -1,
@MainCategory NVARCHAR(100)= NULL,
@NextCalibrationDate DATE = NULL,
@CarLicenseNumber NVARCHAR(100)= NULL,
@CalibratorFullName NVARCHAR(200) = NULL,
@StatusDescription NVARCHAR(255) = NULL,
@DepartmentName NVARCHAR(255) = NULL
/*
EXEC dbo.GetEquipmentManagementTableData
@DepartmentId  = 1,
@EquipmentName = 'Test',
@SerialNumber = '00-00-11',
@StatusId  = 43,
@CalibratorId  = 107,
@CarId  = 1,
@MainCategory = 'Test category',
@NextCalibrationDate  = '2025-03-24'
*/

AS

IF @OrderBy NOT IN (N'ID',N'DepartmentId',N'DepartmentName',N'StatusId',N'StatusDescriptionENG',N'StatusDescriptionHEB',N'EquipmentName',N'SerialNumber',N'CalibratorId',N'CalibratorFullName',N'MainCategory',N'NextCalibrationDate',N'CarId',N'Model',N'LicenseNumber')
THROW 51000, 'Incorrect value for parameter @OrderBy.', 1;


if @DepartmentId > 0 AND NOT EXISTS (
SELECT 1 FROM dbo.Departments
WHERE ID = @DepartmentId
)
THROW 51000, 'Incorrect @DepartmentId', 1;

IF @StatusId > 0 AND @StatusId NOT IN (SELECT StatusId
				FROM [dbo].[Statuses] as s
				JOIN [dbo].[StatusesCategories] as c On s.[StatusCategoryId] = c.[StatusCategoryId]
				WHERE c.StatusDescriptionENG = 'EquipmentStatus' )
THROW 51000, 'Incorrect status was assigned.', 1;

if @CalibratorId > 0 AND NOT EXISTS (
SELECT 1 FROM [dbo].[Users] as u
WHERE (u.ID = @CalibratorId)  AND u.IsActive = 1
)
THROW 51000, 'Incorrect or inactive user assigned as calibrator.', 1;

if @CarId > 0 AND NOT EXISTS (
SELECT 1 FROM Cars WHERE CarId = @CarId
)
THROW 51000, 'Incorrect car was assigned.', 1;

IF @CalibratorFullName IS NOT NULL
BEGIN
DROP TABLE IF EXISTS #Calibrators
CREATE TABLE #Calibrators
(
CalibratorId INT
)
INSERT #Calibrators(CalibratorId)
SELECT u.ID FROM [dbo].[Users] as u 
JOIN [dbo].[UsersToUserRoles] as r ON u.ID = r.UserId
WHERE u.IsActive = 1 AND r.UserRoleId = 3 --Calibrator
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
	WHERE c.StatusDescriptionENG = 'CalibrationEquipmentStatus'
	AND (s.StatusDescriptionENG LIKE '%'+@StatusDescription+'%'
    OR s.StatusDescriptionHEB LIKE '%'+@StatusDescription+'%'
	)
END

DECLARE @sql NVARCHAR(MAX) =
CONCAT(
'SELECT ce.[ID] AS EquipmentId
      ,ce.[DepartmentId]
	  ,d.[DepartmentName]
      ,ce.[StatusId]
	  ,s.StatusDescriptionENG	
	  ,s.StatusDescriptionHEB
      ,ce.[EquipmentName]
      ,ce.[SerialNumber]
      ,ce.[CalibratorId]
	  ,CONCAT(u.FirstName, '' '', u.LastName) as CalibratorFullName
      ,ce.[MainCategory]
      ,ce.[NextCalibrationDate]
      ,ce.[CarId]
	  ,c.Model	
	  ,c.LicenseNumber
	  ,COUNT(1) OVER(PARTITION BY 1 ORDER BY ce.[ID] ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING ) as ItemsCount
  FROM [dbo].[CalibEquipments] as ce
  JOIN [dbo].[Departments] as d ON ce.DepartmentId = d.ID AND d.IsDeleted = 0
  LEFT JOIN [dbo].[Statuses] as s ON s.StatusId = ce.[StatusId]
  LEFT JOIN [dbo].[Users] as u ON ce.[CalibratorId] = u.ID AND u.IsActive = 0 
  LEFT JOIN [dbo].[Cars] as c ON ce.[CarId] = c.CarId AND c.IsDeleted = 0 '
  ,CASE WHEN @CalibratorFullName IS NOT NULL THEN ' JOIN #Calibrators as cf ON ce.[CalibratorId] = cf.[CalibratorId] ' ELSE ' ' END
  ,CASE WHEN @StatusDescription IS NOT NULL THEN ' JOIN #StatusDescriptions as sdf ON ce.[StatusId] = sdf.[StatusId] ' ELSE ' ' END
  ,'
  WHERE ce.IsDeleted = 0'
  ,CASE WHEN @EquipmentName IS NOT NULL THEN' AND ce.[EquipmentName] = '''+ @EquipmentName+''' 'ELSE ' ' END
  ,CASE WHEN @SerialNumber IS NOT NULL THEN' AND ce.[SerialNumber] LIKE ''%'+ @SerialNumber+'%'' 'ELSE ' ' END
  ,CASE WHEN @DepartmentName IS NOT NULL THEN' AND d.[DepartmentName] LIKE ''%'+ @DepartmentName+'%'' 'ELSE ' ' END
  ,CASE WHEN @CarLicenseNumber IS NOT NULL THEN' AND c.[LicenseNumber] LIKE ''%'+ @CarLicenseNumber+'%'' 'ELSE ' ' END
  ,CASE WHEN @MainCategory IS NOT NULL THEN' AND ce.[MainCategory] LIKE ''%'+ @MainCategory+'%'' 'ELSE ' ' END
  ,CASE WHEN @StatusId > 0 THEN' AND ce.[StatusId] = '+CAST(@StatusId as NVARCHAR(50))+' 'ELSE ' ' END
  ,CASE WHEN @CalibratorId > 0 THEN' AND ce.[CalibratorId] = '+CAST(@CalibratorId as NVARCHAR(50))+' 'ELSE ' ' END
  ,CASE WHEN @DepartmentId > 0 THEN' AND ce.[DepartmentId] = '+CAST(@DepartmentId as NVARCHAR(50))+' 'ELSE ' ' END
  ,CASE WHEN @CarId > 0 THEN' AND ce.[CarId] = '+CAST(@CarId as NVARCHAR(50))+' 'ELSE ' ' END
  ,CASE WHEN @NextCalibrationDate IS NOT NULL AND @NextCalibrationDate > '1900-01-01' THEN' AND ce.[NextCalibrationDate] = '''+CAST(@NextCalibrationDate as NVARCHAR(50))+''' 'ELSE ' ' END
,  'ORDER BY ' , QUOTENAME(@OrderBy) , CASE WHEN @OrderByAsc = 1 THEN ' ASC' ELSE ' DESC' END , '
    OFFSET ',(@PageNumber -1) * @RowsPerPage,' ROWS FETCH NEXT ', @RowsPerPage ,'ROWS ONLY OPTION(RECOMPILE); ')
PRINT @sql
EXEC sp_executesql @sql