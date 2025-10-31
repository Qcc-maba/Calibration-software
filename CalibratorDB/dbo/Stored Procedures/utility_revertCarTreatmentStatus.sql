-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 31/10/2025
-- Description:	This SP designed for automatically roll back treatment status when current date more than TreatmentEndDate
-- JiraLink: https://calibration-maba.atlassian.net/browse/MABA-363
-- =============================================
CREATE    PROCEDURE [dbo].[utility_revertCarTreatmentStatus]
AS

SET NOCOUNT ON;

DECLARE 
	@AvailableStatusId INT,
	@TreatmentStatusId INT

SELECT 
@TreatmentStatusId = MAX(IIF(s.StatusDescriptionENG = 'Treatment', s.StatusId,NULL)),
@AvailableStatusId = MAX(IIF(s.StatusDescriptionENG = 'Available', s.StatusId,NULL))
FROM [dbo].[Statuses] AS s 
JOIN [dbo].[StatusesCategories] AS c ON s.[StatusCategoryId] = c.[StatusCategoryId]
WHERE c.StatusDescriptionENG = 'CarStatus'

;WITH GetUpdatedStatus
AS
(
SELECT ca.CarId, st.TreatmentEndDate,
IIF(GETDATE() > st.TreatmentEndDate,@AvailableStatusId,@TreatmentStatusId) as StatusId
FROM [dbo].[Cars] as ca
OUTER APPLY
(
SELECT TOP 1 c.TreatmentEndDate
FROM  [dbo].[CarsTreatmentTracking] as c
WHERE ca.CarId = c.CarId
ORDER BY c.DateOfChange DESC
) as st
WHERE 
	ca.CarStatusId = @TreatmentStatusId
	AND ca.IsDeleted = 0
	AND st.TreatmentEndDate IS NOT NULL)
UPDATE c
SET CarStatusId = us.StatusId,
	UpdatedDate	=GETDATE(),
	UpdateUserID = 0
FROM [dbo].[Cars] as c
JOIN GetUpdatedStatus as us ON c.CarId = us.CarId
WHERE c.CarStatusId <> us.StatusId