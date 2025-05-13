

CREATE PROCEDURE [dbo].[GetLoginUser]
    @email NVARCHAR(100),
    @password NVARCHAR(100)
AS
BEGIN


	DECLARE @IsActive bit
    DECLARE @UserExists bit = 0
    DECLARE @CorrectPassword bit = 0

	-- First check if user exists with this email
    IF EXISTS (SELECT 1 FROM Users WHERE Email = @email)
    BEGIN
        -- User exists, now check password
        IF EXISTS (SELECT 1 FROM Users WHERE Email = @email AND Password = @password)
        BEGIN
            -- Get IsActive status for valid credentials
            SELECT @IsActive = IsActive, @UserExists = 1, @CorrectPassword = 1
            FROM Users 
            WHERE Email = @email AND Password = @password
        END
        ELSE
        BEGIN
            -- Wrong password case
            SELECT MessageHeb, MessageEng FROM UserMessages WHERE Id = 3
            RETURN
        END
    END
    
    
	-- If user doesn't exist
    IF @UserExists = 0
    BEGIN
        SELECT MessageHeb, MessageEng FROM UserMessages WHERE Id = 1
        RETURN
    END

    -- If user exists but is not active
    IF @IsActive = 0
    BEGIN
        SELECT MessageHeb, MessageEng FROM UserMessages WHERE Id = 2
        RETURN
    END

    -- If user exists, is active, and password is correct
	SELECT u.ID
		,u.FirstName
		,u.LastName
		,u.Email
		,u.Phone as Mobile
		,u.UserRoleId as RoleId
		,ud.DepartmentId
	FROM dbo.Users as u
	LEFT JOIN 
	(
		SELECT ud.UserId, STRING_AGG(ud.DepartmentId,',') as DepartmentId
		FROM [dbo].[UsersToDepartments] as ud 
		WHERE ud.IsDeleted = 0
		GROUP BY ud.UserId
	)as ud ON u.ID = ud.UserId
	WHERE u.Email = @email AND u.Password = @password
	AND u.ID > 0 and u.IsActive = 1


END