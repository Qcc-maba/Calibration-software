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
	@TreatmentStatusId INT

SELECT 
@TreatmentStatusId = MAX(IIF(s.StatusDescriptionENG = 'Treatment', s.StatusId,NULL)),
@AvailableStatusId = MAX(IIF(s.StatusDescriptionENG = 'Available', s.StatusId,NULL))
FROM [dbo].[Statuses] AS s 
JOIN [dbo].[StatusesCategories] AS c ON s.[StatusCategoryId] = c.[StatusCategoryId]
WHERE c.StatusDescriptionENG = 'CarStatus'


;WITH CarStatus
AS
(
SELECT c.CarId, IIF(st.TreatmentEndDate < GETDATE(),@AvailableStatusId,-1) as CarStatusId
FROM [dbo].[Cars] as c
JOIN [dbo].[Statuses] as s ON c.CarStatusId = s.StatusId
CROSS APPLY
(
SELECT TOP 1 ct.TreatmentEndDate
FROM  [dbo].[CarDowntimePeriodHistory] as ct
WHERE c.CarId = ct.CarId 
ORDER BY ct.DateOfChange DESC
) as st
WHERE s.StatusDescriptionENG IN (N'Treatment',N'UnAvailable')
)
UPDATE c
SET
    CarStatusId = @AvailableStatusId,
	UpdatedDate	=GETDATE(),
	UpdateUserID = 0
FROM [dbo].[Cars] as c
JOIN CarStatus as cs On c.CarId = cs.CarId AND cs.CarStatusId > 0