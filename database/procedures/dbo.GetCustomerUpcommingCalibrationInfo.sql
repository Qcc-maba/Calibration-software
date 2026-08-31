SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 02/03/2026
-- Description:	Get information about customer upcoming calibration
--
-- 2026-08-31 - MBA-943: the caller is a SET of customers, not one.
--
--              This card answers "who is coming next, and when". For a manager over several
--              company records the answer is the nearest visit across ALL of them - picking the
--              nearest visit to whichever company happened to have the lowest CustomerContactId
--              produced either the wrong date or, far more often, no card at all.
--
--              TOP 1 WITH TIES is kept: if two calibrators are assigned on the same earliest
--              date, both are returned, exactly as before. That now includes the case where the
--              two visits are to two different companies of the same caller.
--
--              @SourceId is removed - it was assigned from the contact row and never read.
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[GetCustomerUpcommingCalibrationInfo]
@LoggedInUserEmail NVARCHAR(100)
AS

DECLARE @CurrentDate DATETIME2(0) = CAST(GETDATE() AS DATE)

SELECT TOP 1 WITH TIES
 u.FirstName
,u.LastName
,u.Email
,u.Phone
,AssigmentDate
FROM dbo.GetPortalCustomerIds(@LoggedInUserEmail) as mine
JOIN [dbo].[OrderWorkPlans] as wp ON wp.CustomerId = mine.CustomerId
JOIN [dbo].[CalibratorsToWorkPlan] as ctwp ON ctwp.[OrderWorkPlanId] = wp.[OrderWorkPlanId] AND ctwp.IsDeleted = 0
JOIN [dbo].[Users] as u ON ctwp.CalibratorId = u.[ID]
WHERE ctwp.AssigmentDate >= @CurrentDate
AND wp.IsCancelled = 0
ORDER BY RANK() OVER( ORDER BY ctwp.AssigmentDate)
GO
