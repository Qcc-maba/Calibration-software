-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 30/03/2025
-- Description:	Return corrections for measurment devices(history abd latest one)
-- JiraLink: 
-- =============================================
CREATE   PROCEDURE [dbo].[GetMeasurementDevicesCorrections]
@MabaID NVARCHAR(50),
@GetLatestVersionOnly BIT = 0
/*
EXEC dbo.GetMeasurementDevicesCorrections
*/

AS

BEGIN

DECLARE @CorVersion INT, @MeasurementDevicesId INT

SELECT
    @MeasurementDevicesId = md.[ID], 
    @CorVersion= MAX(mdc.CorVersion)
FROM [dbo].[MeasurementDevices] as md
JOIN [dbo].[MeasurementDevicesCorrections] as mdc ON md.[ID] = mdc.[MeasurementDevicesId]
WHERE md.[MabaID] = @MabaID
GROUP BY md.[ID]


SELECT mdc.[ID]
      ,mdc.[Value1]
      ,mdc.[Value2]
      ,mdc.[Deviation]
      ,mdc.[Note]
      ,mdc.[MeasurementDevicesId]
      ,mdc.[MeasurementId]
      ,mdc.[UnitID]
      ,mdc.[CreatedDate]
      ,mdc.[CorVersion]
      ,mdc.[MainCategoryId] as  [DepartmentId]
      ,mdc.[Equation]
  FROM [dbo].[MeasurementDevicesCorrections] as mdc
  WHERE mdc.IsDeleted = 0 AND mdc.[MeasurementDevicesId] = @MeasurementDevicesId AND (@GetLatestVersionOnly = 0 OR mdc.[CorVersion] = @CorVersion)


END