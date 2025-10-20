-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 08/04/2025
-- Description:	This SP should delete car record
-- JiraLink: https://calibration-maba.atlassian.net/browse/MABA-210
-- =============================================
CREATE    PROCEDURE [dbo].[DeleteEquipmentsRecord]
@EquipmentsIDs NVARCHAR(MAX),
@LoggedInUserEmail NVARCHAR(50) = NULL
/*
EXEC [dbo].[DeleteEquipmentsRecord] 
   @EquipmentsIDs = '88,87'
*/

AS
BEGIN

SET NOCOUNT ON;

DECLARE @LoggedInUserId INT 
DECLARE @SourceId TINYINT

SELECT 
 @LoggedInUserId  = d.UserId 
,@SourceId = d.SourceId
FROM dbo.GetSourceFilterByEmail(@LoggedInUserEmail) as d

DROP TABLE IF EXISTS #EquipmentsIDs
CREATE TABLE #EquipmentsIDs
(
EquipmentId INT PRIMARY KEY
)

INSERT #EquipmentsIDs(EquipmentId)
SELECT Value FROM dbo.ParseCSVToTable(@EquipmentsIDs)
BEGIN TRY
	BEGIN TRAN

	UPDATE ce 
	SET ce.UpdatedDate = GETDATE(), ce.IsDeleted = 1, ce.UpdateUserID = @LoggedInUserId
	FROM dbo.CarsToEquipment as ce
	JOIN #EquipmentsIDs as d ON ce.MeasurementDeviceId = d.EquipmentId

	UPDATE c 
	SET c.UpdateDate = GETDATE(), c.IsDeleted = 1,c.UpdateUserID = @LoggedInUserId
	FROM [dbo].[MeasurementDevices] as c
	JOIN #EquipmentsIDs as d ON c.ID = d.EquipmentId


	COMMIT 
END TRY

BEGIN CATCH
ROLLBACK
END CATCH

END