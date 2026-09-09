/*
    The nine customer-support agents                                                    MBA-945
    ---------------------------------------------------------------------------------------------
    Reference data. Priority assigns every customer an agent by e-mail, and dbo.Customers stores
    the resolved user in CustomerSupportContactId. If the agent has no row in dbo.Users, that
    column stays NULL and dbo.GetCustomerSupportData - an INNER JOIN - returns nothing, so the
    portal shows no agent at all.

    PROD had none of the nine, so CustomerSupportContactId was NULL on all 11,320 customers and
    every customer saw an empty agent card. STAGE has all nine and 7,919 customers resolve.

    Idempotent: inserts only what is missing, matched on e-mail. Re-running changes nothing.

    THE ROLE ID IS NOT THE SAME ON BOTH SERVERS
    -------------------------------------------
    'Customer support' is UserRoleId 9 on STAGE and 8 on PROD - the whole table is shifted, the
    way dbo.Measurements is. Copying the STAGE value across would have filed all nine under
    'Packing'. It is therefore looked up by name, never written as a number.

    PASSWORD: A RANDOM VALUE, DELIBERATELY, AND NEVER NULL
    -----------------------------------------------------
    dbo.GetLoginUser decides with:

        IF @StoredPass IS NULL AND @IsActive IS NULL   -> 'user does not exist'
        ELSE IF @StoredPass <> @password               -> 'wrong password'
        ELSE IF @IsActive = 0                          -> 'user is not active'
        ELSE                                           -> logged in

    For a row with Password NULL and IsActive 1, the first test is false, the second compares
    NULL to a string and yields UNKNOWN so it does not fire, the third is false - and the flow
    falls straight into the success branch. A user with no password would authenticate with ANY
    password. No row on either server is in that state today (0 of 2,137 on PROD), and these
    nine must not become the first.

    So each gets NEWID() as its password: a value no one holds, generated here rather than
    written down, which makes '<>' true for every input and the login fail properly. When an
    agent genuinely needs access, reset it through the normal screen.

    Phone is left NULL, exactly as on STAGE. The agent card shows name and e-mail; there are no
    numbers to import and inventing them would be worse than an empty field.

    AFTER THIS, RUN THE SYNC. The rows alone change nothing until
    stg.MergeCustomersData resolves them into Customers.CustomerSupportContactId.
*/

SET NOCOUNT ON;

DECLARE @SupportRoleId INT =
    (SELECT UserRoleId FROM dbo.UserRoles WHERE UserRoleName = N'CustomerSupport');

IF @SupportRoleId IS NULL
BEGIN
    RAISERROR(N'No UserRoles row named CustomerSupport - refusing to guess the role id.', 16, 1);
    RETURN;
END

DECLARE @Agents TABLE (Email NVARCHAR(100), FirstName NVARCHAR(100), LastName NVARCHAR(100));
INSERT INTO @Agents (Email, FirstName, LastName) VALUES
    (N'dovrat_le@mba.co.il',  N'דברת',   N'לוי'),
    (N'yonat_be@mba.co.il',   N'יונת',   N'יוסף'),
    (N'vered_le@mba.co.il',   N'ורד',    N'לב'),
    (N'vered_ga@mba.co.il',   N'ורד',    N'גנון'),
    (N'keren_sh@mba.co.il',   N'קרן',    N'שרעבי'),
    (N'ofir_ba@mba.co.il',    N'אופיר',  N'בסביץ'),
    (N'dorli_le@mba.co.il',   N'דורלי',  N'לוי-חלי'),
    (N'kosta_kl@mba.co.il',   N'קוסטיה', N'קליוקין'),
    (N'sharona_ko@mba.co.il', N'שרונה',  N'קורן');

INSERT INTO dbo.Users (FirstName, LastName, Email, Password, IsActive, UserRoleId, CreatedDate)
SELECT a.FirstName, a.LastName, a.Email,
       CAST(NEWID() AS NVARCHAR(50)),   /* unguessable, and never NULL - see the header */
       1, @SupportRoleId, GETDATE()
FROM @Agents AS a
WHERE NOT EXISTS (SELECT 1 FROM dbo.Users AS u
                  WHERE LOWER(LTRIM(RTRIM(u.Email))) = LOWER(LTRIM(RTRIM(a.Email))));

SELECT Inserted = @@ROWCOUNT, SupportRoleId = @SupportRoleId;

/* what the sync will now be able to resolve */
SELECT a.Email,
       Present   = CASE WHEN u.ID IS NULL THEN 'NO' ELSE 'yes' END,
       UserId    = u.ID,
       RoleId    = u.UserRoleId,
       Role      = r.UserRoleDescriptionHEB,
       IsActive  = u.IsActive,
       HasPwd    = CASE WHEN u.Password IS NULL THEN 'NULL - WRONG' ELSE 'set' END,
       Customers = (SELECT COUNT(*) FROM stg.stg_Customers s
                    WHERE LTRIM(RTRIM(s.AgentUserEmail)) = a.Email)
FROM @Agents AS a
LEFT JOIN dbo.Users AS u ON LOWER(LTRIM(RTRIM(u.Email))) = LOWER(LTRIM(RTRIM(a.Email)))
LEFT JOIN dbo.UserRoles AS r ON r.UserRoleId = u.UserRoleId
ORDER BY Customers DESC;
