
CREATE PROCEDURE [dbo].[GetLoginUser]
    @email NVARCHAR(100),
    @password NVARCHAR(100)
AS
BEGIN


	DECLARE @IsActive   bit
	DECLARE @StoredPass nvarchar(50)
	DECLARE @UserId INT 

	-- Single lookup — covers all three checks in one hit
	SELECT 
		@StoredPass = [Password],
		@IsActive   = [IsActive],
		@UserId     = [ID]
	FROM Users
	WHERE Email = @email

	-- User not found
	IF @StoredPass IS NULL AND @IsActive IS NULL
	BEGIN
		SELECT MessageHeb, MessageEng FROM UserMessages WHERE MessageEng = 'User is not exist'
		RETURN
	END
	ELSE
	-- Wrong password
	IF @StoredPass <> @password
	BEGIN
		SELECT MessageHeb, MessageEng FROM UserMessages WHERE MessageEng = 'Wrong password'
		RETURN
	END
	ELSE
	-- Account inactive
	IF @IsActive = 0
	BEGIN
		SELECT MessageHeb, MessageEng FROM UserMessages WHERE MessageEng = 'User is not active'
		RETURN
	END
	ELSE
    -- If user exists, is active, and password is correct
    BEGIN
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
		    SELECT ud.UserId, STRING_AGG(ud.MainCategoryId,',') as DepartmentId
		    FROM [dbo].[UsersToDepartments] as ud 
		    WHERE ud.IsDeleted = 0
		    GROUP BY ud.UserId
	    )as ud ON u.ID = ud.UserId
	    WHERE u.ID = @UserId
        
		UPDATE dbo.Users
		SET [LastLoginDate] = GETDATE()
		WHERE ID = @UserId

    END 

END