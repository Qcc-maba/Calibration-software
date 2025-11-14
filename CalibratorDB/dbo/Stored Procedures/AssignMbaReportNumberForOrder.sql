-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 13/11/2025
-- Description:	Assing Maba report number for order and calibrator
-- JiraLink: https://calibration-maba.atlassian.net/browse/MABA-402
-- =============================================
CREATE   PROCEDURE [dbo].[AssignMbaReportNumberForOrder]
@OrderWorkPlanId INT,
@Data NVARCHAR(MAX)
/*json example*/
/*
[
{"CalibratorId":5,"OrderDetailsMbaReportNumber":1}
,{"CalibratorId":10,"OrderDetailsMbaReportNumber":1}
,{"CalibratorId":11,"OrderDetailsMbaReportNumber":1}
]
*/
AS
BEGIN

SET NOCOUNT ON;

UPDATE ctp
SET OrderDetailsMbaReportNumber = d.OrderDetailsMbaReportNumber
FROM OPENJSON(@Data) 
WITH (
	CalibratorId INT,
	OrderDetailsMbaReportNumber NVARCHAR(100)
) AS d
JOIN [dbo].[CalibratorsToWorkPlan] as ctp ON ctp.OrderWorkPlanId = @OrderWorkPlanId AND ctp.CalibratorId = d.CalibratorId

END