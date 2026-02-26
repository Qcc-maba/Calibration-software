-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 16/06/2025
-- Description:	
-- JiraLink: 
-- =============================================
CREATE   PROCEDURE [dbo].[GetCustomerRemarks]
@CustomerId INT
AS
BEGIN

SET NOCOUNT ON;

SELECT [CustomerId]
      ,CAST(DECOMPRESS([CustomerRemark]) as NVARCHAR(MAX)) as [CustomerRemark]
      ,CustomerSpecialInstructionsAttachment
  FROM [dbo].[CustomerRemarks]
  WHERE [IsDeleted] = 0 AND [CustomerId] = @CustomerId

END

ALTER TABLE [dbo].[CustomerRemarks]
ADD CustomerSpecialInstructionsAttachment NVARCHAR(200) NULL