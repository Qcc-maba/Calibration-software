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
      ,N'orders/SO25000296/a02cc88e-7182-4d1b-afc4-a7367aa15744.pdf' as [CustomerSpecialInstructionsAttachment]
  FROM [dbo].[CustomerRemarks]
  WHERE [IsDeleted] = 0 AND [CustomerId] = @CustomerId

END