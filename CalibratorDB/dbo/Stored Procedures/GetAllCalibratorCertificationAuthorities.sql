-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 01/09/2025
-- Description:	Get list of CalibratorCertificationAuthorities based on MainCategory
-- JiraLink: 
-- =============================================
CREATE   PROCEDURE [dbo].[GetAllCalibratorCertificationAuthorities]
@MainCategoryId INT = NULL
AS
SELECT [ID]
      ,[AuthorityName]
      ,[MainCategoryId]
  FROM [dbo].[CalibratorCertificationAuthorities]
  WHERE [IsDeleted] = 0 AND ( @MainCategoryId IS NULL OR [MainCategoryId] = @MainCategoryId)