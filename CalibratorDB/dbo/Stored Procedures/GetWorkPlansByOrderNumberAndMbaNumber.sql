
-- =============================================
-- Author:		Shamailov Slavik
-- Create date: 24/12/2024
-- Description:	Get work plan data by 'OrderNumber' and 'MbaNumber'
-- =============================================
CREATE PROCEDURE [dbo].[GetWorkPlansByOrderNumberAndMbaNumber]
	@OrderNumber VARCHAR(20),	
	@MbaNumber VARCHAR(20)
AS
BEGIN

	DECLARE @sql NVARCHAR(MAX);
	SET @sql = 
	   'SELECT	dbo.Users.FirstName, dbo.Users.LastName
		FROM	dbo.WorkPlan INNER JOIN
				dbo.CalibratorsToWorkPlan ON dbo.WorkPlan.Id = dbo.CalibratorsToWorkPlan.WorkPlanId INNER JOIN
				dbo.Calibrators ON dbo.CalibratorsToWorkPlan.CalibratorsId = dbo.Calibrators.ID INNER JOIN
				dbo.Users ON dbo.Calibrators.UserId = dbo.Users.ID
		WHERE	(dbo.WorkPlan.OrderNumber = @OrderNumber) AND (dbo.WorkPlan.MbaNumber = @MbaNumber )';
	
	EXEC sp_executesql @sql, N'@OrderNumber varchar(20), @MbaNumber varchar(20)', @OrderNumber,  @MbaNumber


	SET @sql = 
	   'SELECT	dbo.SpecialCare_wp.Name
		FROM	dbo.WorkPlan INNER JOIN
				dbo.SpecialCareToWorkPlan ON dbo.WorkPlan.Id = dbo.SpecialCareToWorkPlan.WorkPlanId INNER JOIN
				dbo.SpecialCare_wp ON dbo.SpecialCareToWorkPlan.SpecialCareId = dbo.SpecialCare_wp.ID		
		WHERE	(dbo.WorkPlan.OrderNumber = @OrderNumber) AND (dbo.WorkPlan.MbaNumber = @MbaNumber)';
	
	EXEC sp_executesql @sql, N'@OrderNumber varchar(20) , @MbaNumber varchar(20)', @OrderNumber,  @MbaNumber


END
