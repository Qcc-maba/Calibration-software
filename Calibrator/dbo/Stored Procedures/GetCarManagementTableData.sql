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
@AssignedCalibrator INT = -1,
@TreatmentPeriod INT = -1,
@NextTreatmentDate DATE = NULL,
@NextTestDate DATE = NULL,
@AssociatedEquipmentId NVARCHAR(200) = NULL, 
@RowsPerPage INT = 50,
@PageNumber INT = 1,
@OrderBy NVARCHAR(255) = N'Model',-- Only this list of valid values for parameter CarId|Model|LicenseNumber|Seats|TreatmentPeriod|NextTreatmentDate|NextYearlyTestDate|OwnerId|OwnerFullName|CarStatusId|StatusDescriptionENG|StatusDescriptionHEB|AssignedCalibratorId|CalibratorFullName|EquipmentId|EquipmentName
@OrderByAsc BIT = 1

/*
EXEC dbo.GetCarManagementTableData 
@OrderBy ='CarId', 
@Model = 'סקודה רומסטר',
@OrderByAsc = 1,
@RowsPerPage = 5000
*/

AS
BEGIN

IF @OrderBy NOT IN (N'CarId',N'Model',N'LicenseNumber',N'Seats',N'TreatmentPeriod',N'NextTreatmentDate',N'NextYearlyTestDate',N'OwnerId',N'OwnerFullName',N'CarStatusId',N'StatusDescriptionENG',N'StatusDescriptionHEB',N'AssignedCalibratorId',N'CalibratorFullName',N'EquipmentId',N'EquipmentName')
THROW 51000, 'Incorrect value for parameter @OrderBy.', 1;

DROP TABLE IF EXISTS #AssociatedEquipmentIDs
CREATE TABLE #AssociatedEquipmentIDs
(
EquipmentId INT
)
DECLARE @AssociatedEquipment NVARCHAR(200) = @AssociatedEquipmentId

INSERT #AssociatedEquipmentIDs(EquipmentId)
SELECT Value FROM dbo.ParseCSVToTable(@AssociatedEquipment)

DECLARE @sql NVARCHAR(MAX) =
CONCAT(
'SELECT c.[CarId]
      ,c.[Model]
      ,c.[LicenseNumber]
      ,c.[Seats]
      ,c.[TreatmentPeriod]
      ,c.[NextTreatmentDate]
      ,c.[NextYearlyTestDate]
      ,c.[OwnerId]
	  ,CONCAT(u1.LastName,'' '', u1.FirstName) as OwnerFullName
      ,c.[CarStatusId]
	  ,s.[StatusDescriptionENG]
	  ,s.[StatusDescriptionHEB]
      ,c.[AssignedCalibratorId]
	  ,CONCAT(u.LastName,'' '', u.FirstName) as CalibratorFullName
	  ,STRING_AGG(ce.EquipmentId,'','') as EquipmentId
	  ,STRING_AGG(e.EquipmentName,'','') as EquipmentName
	  ,COUNT(1) OVER(PARTITION BY 1 ORDER BY c.[CarId] ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING ) as ItemsCount
  FROM [dbo].[Cars] as c
  JOIN [dbo].[Statuses] as s ON c.[CarStatusId] = s.[StatusId]
  LEFT JOIN [dbo].[Users] as u ON c.[AssignedCalibratorId] = u.[ID]
  LEFT JOIN [dbo].[Users] as u1 ON c.[OwnerId] = u1.[ID]
  LEFT JOIN [dbo].[CarsToEquipment] as ce ON c.[CarId] = ce.[CarId] '
  ,CASE WHEN @AssociatedEquipmentId IS NOT NULL THEN ' JOIN #AssociatedEquipmentIDs as f ON ce.[EquipmentId] = f.[EquipmentId] ' ELSE ' ' END
  ,'LEFT JOIN [dbo].[CalibEquipments] as e ON ce.[EquipmentId] = e.ID
  WHERE  1=1 '
  ,CASE WHEN @LicenseNumber IS NOT NULL THEN' AND c.[LicenseNumber] = N'''+ @LicenseNumber+''' 'ELSE ' ' END
  ,CASE WHEN @Model IS NOT NULL THEN ' AND c.[Model] = N'''+ @Model+''' 'ELSE ' ' END
  ,CASE WHEN @NumberOfSeats > 0 THEN' AND c.[Seats] = '+CAST(@NumberOfSeats as NVARCHAR(50))+' 'ELSE ' ' END
  ,CASE WHEN @StatusId > 0 THEN' AND c.[CarStatusId] = '+CAST(@StatusId as NVARCHAR(50))+' 'ELSE ' ' END
  ,CASE WHEN @OwnerId > 0 THEN ' AND c.[OwnerId] = '+CAST(@OwnerId as NVARCHAR(50))+' 'ELSE ' ' END
  ,CASE WHEN @AssignedCalibrator > 0 THEN ' AND c.[AssignedCalibratorId] = '+CAST(@AssignedCalibrator as NVARCHAR(50))+' 'ELSE ' ' END
  ,CASE WHEN @TreatmentPeriod > 0 THEN ' AND c.[TreatmentPeriod] = '+CAST(@TreatmentPeriod as NVARCHAR(50))+' 'ELSE ' ' END
  ,CASE WHEN @NextTreatmentDate IS NOT NULL THEN ' AND c.[NextTreatmentDate] = '''+ CAST(@NextTreatmentDate AS NVARCHAR(20))+''' ' ELSE ' ' END
  ,CASE WHEN @NextTestDate IS NOT NULL THEN' AND c.[NextYearlyTestDate] = '''+ CAST(@NextTestDate AS NVARCHAR(20))+''' 'ELSE ' ' END
  ,'  GROUP BY 
	   c.[CarId]
      ,c.[Model]
      ,c.[LicenseNumber]
      ,c.[Seats]
      ,c.[TreatmentPeriod]
      ,c.[NextTreatmentDate]
      ,c.[NextYearlyTestDate]
      ,c.[OwnerId]
	  ,CONCAT(u1.LastName,'' '', u1.FirstName)
      ,c.[CarStatusId]
	  ,s.[StatusDescriptionENG]
	  ,s.[StatusDescriptionHEB]
      ,c.[AssignedCalibratorId]
	  ,CONCAT(u.LastName,'' '', u.FirstName)'
  ,  'ORDER BY ' , QUOTENAME(@OrderBy) , CASE WHEN @OrderByAsc = 1 THEN ' ASC' ELSE ' DESC' END , '
    OFFSET ',(@PageNumber -1) * @RowsPerPage,' ROWS FETCH NEXT ', @RowsPerPage ,'ROWS ONLY OPTION(RECOMPILE); ')
PRINT @sql
EXEC sp_executesql @sql

END