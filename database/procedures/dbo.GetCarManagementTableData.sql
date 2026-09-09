-- =============================================
-- Proc:        dbo.GetCarManagementTableData
-- Jira:        MBA-159 (parent MBA-91 "Assign car to the order")
-- Description: Returns THE cars list. This is the SP behind the app's cars list:
--                * orders.getCalibratorRelatedData -> `EXEC dbo.GetCarManagementTableData;`
--                  (no params) supplies the car dropdown in the Assign-car-to-order flow (MBA-91).
--                * cars.getAll -> `EXEC GetCarManagementTableData <filters/paging>` drives the
--                  Car Management table.
--                * equipment router -> `EXEC dbo.GetCarManagementTableData @RowsPerPage = 100;`
--
--              One row per (non-deleted) car in dbo.Cars, with owner / status / assigned
--              calibrator names, associated equipment (STRING_AGG'd), current downtime window,
--              and a windowed ItemsCount for client-side paging. All filtering, sorting, search
--              and paging are applied server-side via the parameters below.
--
-- Inputs (all optional; sentinels: -1 = "no filter" for INT ids, NULL for the rest):
--   @LicenseNumber, @Model, @NumberOfSeats, @StatusId, @OwnerId, @AssignedCalibratorId,
--   @TreatmentPeriod, @NextTreatmentDate, @NextTestDate, @AssociatedEquipmentId (CSV of ids),
--   @RowsPerPage (default 50), @PageNumber (default 1),
--   @OrderBy (whitelisted column name; default N'Model'), @OrderByAsc (default 1),
--   @CalibratorFullName, @StatusDescription, @EquipmentName, @GlobalSearch.
--
-- Output columns (superset of the app's TRawCar; FE ignores the *ENG / UnvailabilityStatus extras):
--   CarId, Model, LicenseNumber, Seats, TreatmentPeriod, NextTreatmentDate, NextYearlyTestDate,
--   OwnerId, OwnerFullName, OwnerFullNameENG, CarStatusId, StatusDescriptionENG,
--   StatusDescriptionHEB, AssignedCalibratorId, CalibratorFullName, CalibratorFullNameENG,
--   EquipmentId, EquipmentName, DowntimePeriodStartDate, DowntimePeriodEndDate,
--   UnvailabilityStatus, ItemsCount.
--
-- Notes for review (Ariel):
--   * Body is preserved verbatim from the live prod definition (originally authored under
--     MABA-169) so behaviour is byte-for-byte identical; only the header/CREATE OR ALTER wrapper
--     is added for the MBA-159 reviewable checkpoint. Validated read-only on prod: default call
--     returns 32 cars; column set matches the app's TRawCar mapping (map-raw-to-cars.ts).
--   * @OrderBy is whitelisted (THROW on invalid) and interpolated via QUOTENAME; the string
--     filters are still concatenated into dynamic SQL, so keep inputs trusted / parameterise if
--     ever exposed to untrusted callers.
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[GetCarManagementTableData]
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
'
;WITH GetLastTreatment
AS
(
SELECT
	ct.[CarId],
	ROW_NUMBER() OVER (PARTITION BY ct.[CarId] ORDER BY ct.[DateOfChange] DESC) AS rn,
	ct.[TreatmentStartDate],
	ct.[TreatmentEndDate],
	s.[StatusDescriptionHEB]
FROM [dbo].[CarDowntimePeriodHistory] as ct
JOIN [dbo].[Statuses] as s ON ct.StatusId = s.StatusId
WHERE ct.IsDeleted = 0
)
SELECT c.[CarId]
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
	  ,MIN(ct.[TreatmentStartDate]) as DowntimePeriodStartDate
	  ,MIN(ct.[TreatmentEndDate]) as DowntimePeriodEndDate
	  ,MIN(ct.[StatusDescriptionHEB]) as UnvailabilityStatus
	  ,COUNT(1) OVER(PARTITION BY 1 ORDER BY c.[CarId] ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING ) as ItemsCount
  FROM [dbo].[Cars] as c
  JOIN [dbo].[Statuses] as s ON c.[CarStatusId] = s.[StatusId]
  LEFT JOIN GetLastTreatment as ct ON  c.[CarId] = ct.[CarId] AND ct.[rn] = 1
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
GO
