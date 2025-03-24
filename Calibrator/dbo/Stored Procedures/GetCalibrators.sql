
-- =============================================
-- Author:		Shamailov Slavik
-- Create date: 17/02/2024
-- Description:	Returns Calibrators list
-- =============================================
CREATE PROCEDURE [dbo].[GetCalibrators]
AS
BEGIN

	SET NOCOUNT ON;

    SELECT Calibrators.ID, Users.FirstName, Users.LastName, Calibrators.Availability, CalibratorsAvailability.Status, Calibrators.AvailbilityDateFrom, Calibrators.AvailbilityDateTo
	FROM Calibrators INNER JOIN
        Users ON Calibrators.UserId = Users.ID LEFT OUTER JOIN
        CalibratorsAvailability ON Calibrators.ID = CalibratorsAvailability.ID


END
