-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 31/10/2025
-- Description:	This SP designed for automatically roll back treatment status when current date more than TreatmentEndDate
-- JiraLink: https://calibration-maba.atlassian.net/browse/MABA-363
-- =============================================
CREATE   PROCEDURE [dbo].[utility_revertCarStatus]
AS

SET NOCOUNT ON;

DECLARE 
	@AvailableStatusId INT,
	@TreatmentStatusId INT,
	@UnAvailableStatusId INT

SELECT 
@TreatmentStatusId = MAX(IIF(s.StatusDescriptionENG = 'Treatment', s.StatusId,NULL)),
@UnAvailableStatusId = MAX(IIF(s.StatusDescriptionENG = 'UnAvailable', s.StatusId,NULL)),
@AvailableStatusId = MAX(IIF(s.StatusDescriptionENG = 'Available', s.StatusId,NULL))
FROM [dbo].[Statuses] AS s 
JOIN [dbo].[StatusesCategories] AS c ON s.[StatusCategoryId] = c.[StatusCategoryId]
WHERE c.StatusDescriptionENG = 'CarStatus'

UPDATE c
SET
c.CarStatusId = CASE 
					WHEN c.CarStatusId IN (@TreatmentStatusId,@UnAvailableStatusId) AND stt.StatusId IS NULL THEN @AvailableStatusId
					WHEN c.CarStatusId NOT IN (@TreatmentStatusId,@UnAvailableStatusId) AND stt.StatusId IS NOT NULL THEN stt.StatusId
					ELSE c.CarStatusId
				END 

FROM [dbo].[Cars] as c
LEFT JOIN
(
SELECT TOP 1 WITH TIES
ct.CarId, ct.StatusId, ct.TreatmentStartDate, ct.TreatmentEndDate
FROM  [dbo].[CarDowntimePeriodHistory] as ct
WHERE GETDATE() BETWEEN ct.TreatmentStartDate AND ct.TreatmentEndDate
AND ct.IsDeleted = 0
ORDER BY 
ROW_NUMBER() OVER
(
    PARTITION BY ct.CarId ORDER BY ct.CarId, ct.CreatedDate DESC
)
) as stt ON stt.CarId = c.CarId
WHERE c.CarStatusId <> CASE 
							WHEN c.CarStatusId IN (@TreatmentStatusId,@UnAvailableStatusId) AND stt.StatusId IS NULL THEN @AvailableStatusId
							WHEN c.CarStatusId NOT IN (@TreatmentStatusId,@UnAvailableStatusId) AND stt.StatusId IS NOT NULL THEN stt.StatusId
							ELSE c.CarStatusId
						END