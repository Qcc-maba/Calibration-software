CREATE PROCEDURE [dbo].[ValidateUser]
    @email NVARCHAR(100),
    @password NVARCHAR(100)
AS
BEGIN
    SELECT 
        CASE 
            WHEN EXISTS (
                SELECT 1 
                FROM Users 
                WHERE Email = @email AND Password = @password
            ) 
            THEN 1 
            ELSE 0 
        END AS IsValid
END