-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 10/03/2026
-- Description:	Get customer support data. 
--              We can define only one employee as customer support contact
-- =============================================
CREATE    PROCEDURE [dbo].[GetCustomerSupportData] 
@LoggedInUserEmail NVARCHAR(50)
AS

DECLARE @CustomerId INT = 0
DECLARE @SourceId TINYINT

SELECT 
	@CustomerId  = d.CustomerId 
	,@SourceId = d.SourceId
FROM [dbo].[CustomerContacts] as d
WHERE CustomerContactEmail = @LoggedInUserEmail 

SELECT 
	 u.FirstName
	,u.LastName
	,u.Email	
	,u.Phone
FROM [dbo].[Customers] as c
JOIN [dbo].[Users] as u ON c.[CustomerSupportContactId] = u.ID
WHERE c.CustomerId = @CustomerId