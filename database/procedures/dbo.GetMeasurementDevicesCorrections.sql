SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 30/03/2025
-- Description:	Return corrections for measurment devices(history abd latest one)
-- JiraLink:
-- =============================================
/*
    MBA-1060: resolve the MabaID to ONE active device, deterministically.

    The station loads a master's certificate through this procedure (CalibrationRepository,
    @GetLatestVersionOnly = 1). It used to resolve the MabaID with
        SELECT @MeasurementDevicesId = md.ID ... WHERE md.MabaID = @MabaID GROUP BY md.ID
    which, when several rows share the MabaID, assigns whichever group SQL Server returns last,
    including a soft-deleted row. On PROD 21-242, 21-260 and 21-401 carry identical corrections on
    3-4 copies each, so the pick was arbitrary but harmless. Once the extra copies are retired
    (database/data/Retire-DuplicateMeasurementDevices.sql), a certificate saved later goes only
    onto the kept copy, because the save procedures filter IsDeleted = 0, and the old resolution
    could keep serving the stale one.

    Now: only IsDeleted = 0 devices that have active corrections, the lowest ID if more than one,
    and the latest version taken over active corrections only. Measured on PROD 2026-11-26: the
    latest version is the same whether deleted rows count or not for every MabaID (0 differ), and
    no device has only deleted corrections. So today the output changes for no MabaID.
*/
CREATE OR ALTER PROCEDURE [dbo].[GetMeasurementDevicesCorrections]
@MabaID NVARCHAR(50),
@GetLatestVersionOnly BIT = 0
/*
EXEC dbo.GetMeasurementDevicesCorrections
*/

AS

BEGIN

DECLARE @CorVersion INT, @MeasurementDevicesId INT

SELECT TOP (1) @MeasurementDevicesId = md.[ID]
FROM [dbo].[MeasurementDevices] as md
WHERE md.[MabaID] = @MabaID
  AND md.[IsDeleted] = 0
  AND EXISTS (SELECT 1 FROM [dbo].[MeasurementDevicesCorrections] as c
              WHERE c.[MeasurementDevicesId] = md.[ID] AND c.[IsDeleted] = 0)
ORDER BY md.[ID]

SELECT @CorVersion = MAX(mdc.CorVersion)
FROM [dbo].[MeasurementDevicesCorrections] as mdc
WHERE mdc.[MeasurementDevicesId] = @MeasurementDevicesId AND mdc.IsDeleted = 0


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
