/*
    dbo.GetLoginUser                                                                    MBA-947
    ---------------------------------------------------------------------------------------------
    Sign-in for the internal application.

    WHAT WAS WRONG: A NULL PASSWORD LOGGED YOU IN AS ANYONE
    ------------------------------------------------------
    The decision was a chain of three tests, and the middle one compared with <>:

        IF @StoredPass IS NULL AND @IsActive IS NULL   -> 'user does not exist'
        ELSE IF @StoredPass <> @password               -> 'wrong password'
        ELSE IF @IsActive = 0                          -> 'user is not active'
        ELSE                                           -> return the user

    Any comparison against NULL yields UNKNOWN, and IF treats UNKNOWN as false. So a caller
    passing @password = NULL fell past the password test, past the IsActive test, and into the
    success branch — for ANY e-mail on file, whatever that account's real password was. Verified
    against a live account on STAGE before this fix: a wrong password was correctly refused, and
    NULL returned the full user row, role and all.

    The mirror image failed the same way: a row whose stored Password is NULL accepted any
    password typed at it. No row on either server was in that state (0 of 2,137 on PROD), but a
    user created without a password would silently have become such an account.

    THE FIX, AND WHY IT IS SHAPED THIS WAY
    --------------------------------------
    Both NULLs are now tested explicitly instead of being left to a three-valued comparison, and
    "no password on either side" is a failed login rather than an unanswered question.

    "User not found" is also tested directly. It used to be inferred from Password and IsActive
    both being NULL — a proxy for the row's absence that happened to hold, until a row existed
    with a NULL password and it stopped holding. @UserId IS NULL says what is meant.

    The three messages, their order, and the returned columns are unchanged, so nothing calling
    this can tell the difference except in the cases that were wrong.

    STILL WORTH FIXING, AND NOT HERE: passwords are compared with = against a plain column, so
    they appear to be stored in the clear. That is a larger piece of work than this, but it is
    the reason a bug in this comparison is worth so much to an attacker.
*/
CREATE OR ALTER PROCEDURE [dbo].[GetLoginUser]
    @email    NVARCHAR(100),
    @password NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @IsActive   BIT;
    DECLARE @StoredPass NVARCHAR(50);
    DECLARE @UserId     INT;

    SELECT
        @StoredPass = [Password],
        @IsActive   = [IsActive],
        @UserId     = [ID]
    FROM dbo.Users
    WHERE Email = @email;

    /* Not found. Tested on the id, not inferred from the other two columns being NULL. */
    IF @UserId IS NULL
    BEGIN
        SELECT MessageHeb, MessageEng FROM UserMessages WHERE MessageEng = 'User is not exist';
        RETURN;
    END

    /*  Wrong password. The two NULL cases are named rather than left to <>, which would answer
        UNKNOWN and let the login through:
          @password   IS NULL  - the caller supplied nothing
          @StoredPass IS NULL  - the account has no password set, so nothing can match it  */
    IF @password IS NULL OR @StoredPass IS NULL OR @StoredPass <> @password
    BEGIN
        SELECT MessageHeb, MessageEng FROM UserMessages WHERE MessageEng = 'Wrong password';
        RETURN;
    END

    IF @IsActive = 0 OR @IsActive IS NULL
    BEGIN
        SELECT MessageHeb, MessageEng FROM UserMessages WHERE MessageEng = 'User is not active';
        RETURN;
    END

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
    ) as ud ON u.ID = ud.UserId
    WHERE u.ID = @UserId;

    UPDATE dbo.Users
    SET [LastLoginDate] = GETDATE()
    WHERE ID = @UserId;
END
