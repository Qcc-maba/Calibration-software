CREATE PROCEDURE [dbo].[GetUserNames]
AS
BEGIN
	SELECT Email 
	FROM Users 
	WHERE LEN(TRIM(Email))>0 and IsActive = 1 
		AND ID > 0--filter user defined as for ETL
	ORDER BY Email
END