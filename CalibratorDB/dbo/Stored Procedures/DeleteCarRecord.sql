-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 08/04/2025
-- Description:	This SP should delete car record
-- JiraLink: https://calibration-maba.atlassian.net/browse/MABA-210
-- =============================================
CREATE    PROCEDURE [dbo].[DeleteCarRecord]
@CarIDs NVARCHAR(MAX)

/*
EXEC [dbo].[DeleteCarRecord] 
   @CarIDs = '88,87'
*/

AS
BEGIN

SET NOCOUNT ON;

DROP TABLE IF EXISTS #CarIDs
CREATE TABLE #CarIDs
(
CarId INT PRIMARY KEY
)

INSERT #CarIDs(CarId)
SELECT Value FROM dbo.ParseCSVToTable(@CarIDs)

BEGIN TRY
	BEGIN TRAN

	UPDATE ce
	SET CarId = NULL 
	FROM dbo.CalibEquipments as ce
	JOIN #CarIDs c ON c.CarId = ce.CarId


	UPDATE ce
	SET ce.UpdatedDate = GETDATE(), ce.IsDeleted = 1
	FROM dbo.CarsToEquipment as ce
	JOIN #CarIDs as d ON ce.CarId = d.CarId

	UPDATE c
	SET c.UpdatedDate = GETDATE(), c.IsDeleted = 1
	FROM [dbo].[Cars] as c
	JOIN #CarIDs as d ON c.CarId = d.CarId

	COMMIT 
END TRY

BEGIN CATCH
ROLLBACK
END CATCH
END