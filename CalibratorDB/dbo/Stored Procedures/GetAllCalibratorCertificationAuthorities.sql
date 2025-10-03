-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 01/09/2025
-- Description:	Get list of CalibratorCertificationAuthorities based on MainCategory
-- JiraLink: 
-- =============================================
CREATE   PROCEDURE [dbo].[GetAllCalibratorCertificationAuthorities]
@MainCategoryId NVARCHAR(MAX) = NULL
AS

DROP TABLE IF EXISTS #MainCategoryList
CREATE TABLE #MainCategoryList
(
[MainCategoryId] INT
)

INSERT #MainCategoryList([MainCategoryId])
SELECT value FROM string_split(@MainCategoryId,',')

IF @MainCategoryId IS NOT NULL
SELECT ca.[ID]
      ,ca.[AuthorityName]
      ,ca.[MainCategoryId]
  FROM [dbo].[CalibratorCertificationAuthorities] as ca
  JOIN #MainCategoryList as mc ON ca.MainCategoryId = mc.MainCategoryId
  WHERE ca.[IsDeleted] = 0 

ELSE 
SELECT ca.[ID]
      ,ca.[AuthorityName]
      ,ca.[MainCategoryId]
  FROM [dbo].[CalibratorCertificationAuthorities] as ca
  WHERE ca.[IsDeleted] = 0