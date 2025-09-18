-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 01/09/2025
-- Description:	Get list of CalibratorCertificationAuthorities based on MainCategory
-- JiraLink: 
-- =============================================
CREATE   PROCEDURE [dbo].[GetAllCalibratorCertificationAuthorities]
@MainCategoryId INT = NULL
AS
SELECT ca.[ID]
      ,ca.[AuthorityName]
      ,ca.[MainCategoryId]
  FROM [dbo].[CalibratorCertificationAuthorities] as ca
  WHERE ca.[IsDeleted] = 0 AND ( @MainCategoryId IS NULL OR ca.[MainCategoryId] = @MainCategoryId)