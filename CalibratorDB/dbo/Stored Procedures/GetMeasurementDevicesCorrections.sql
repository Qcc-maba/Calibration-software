-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 30/03/2025
-- Description:	
-- JiraLink: 
-- =============================================
CREATE   PROCEDURE [dbo].[GetMeasurementDevicesCorrections]

/*
EXEC dbo.GetMeasurementDevicesCorrections
*/

AS

BEGIN


SELECT mdc.[ID]
      ,mdc.[Value1]
      ,mdc.[Value2]
      ,mdc.[Deviation]
      ,mdc.[Note]
      ,mdc.[MeasurementDevicesId]
      ,mdc.[MeasurementId]
      ,mdc.[UnitID]
      ,mdc.[DateAdded]
      ,mdc.[CorVersion]
      ,mdc.[DepartmentId]
      ,mdc.[Equation]
  FROM [dbo].[MeasurementDevicesCorrections] as mdc
  WHERE mdc.IsDeleted = 0


END