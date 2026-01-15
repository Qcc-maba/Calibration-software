-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 15/01/2026
-- Description:	This SP set configuration for COM ports and PC related staff
-- JiraLink: https://calibration-maba.atlassian.net/browse/MABA-558
-- =============================================
CREATE    PROCEDURE [dbo].[GetWorkstationSettingsRecord]
 @CalibratorId INT
AS
SELECT
	d.CalibratorWorkstationName,
	cs.COMAddress,
	d.CalibratorId,
	cs.COMPortSettingId
FROM [dbo].[COMPortSettings] as cs
JOIN [dbo].[CalibratorWorkstationSettings] as d ON cs.CalibratorWorkstationSettingId = d.CalibratorWorkstationSettingId
WHERE cs.IsDeleted = 0 AND d.IsDeleted = 0
AND d.CalibratorId = @CalibratorId