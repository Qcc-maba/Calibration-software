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
    SELECT dbo.Users.ID, dbo.Users.FirstName, dbo.Users.LastName, dbo.Users.Email, dbo.Users.Mobile, dbo.Roles.ID AS RoleId, dbo.Roles.RoleName
	FROM            dbo.Roles INNER JOIN
						dbo.UsersToRoles ON dbo.Roles.ID = dbo.UsersToRoles.RoleId  RIGHT OUTER JOIN
						dbo.Users ON dbo.UsersToRoles.UserId = dbo.Users.ID
	WHERE        (dbo.Users.Email = @email) AND (dbo.Users.Password = @password)

END