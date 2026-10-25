/*
    Tests for the portal profile write procedures                                       MBA-627
        dbo.AssignCustomerContactsData, dbo.AssignCustomerSitesData
    ---------------------------------------------------------------------------------------------
    Run against a database where both procedures and dbo.GetPortalCustomerIds are deployed.
    Anything other than 'PASS' in Result is a failure; 'SKIP' means the database holds no row that
    fits the case, and says which.

    Every case runs in its own transaction and is rolled back, so the file leaves the database as it
    found it. The procedures run with XACT_ABORT ON, so a THROW dooms the transaction: each case
    reads what it needs into variables, rolls back, and only then records its result.

    Fixtures are picked from the data, never hard-coded - identities differ between STAGE and PROD.
    No address is printed; the output names cases, not people.

        @Me          an active address that is a contact of at least two customers
        @OtherEmail  an active address of somebody else
        @Staff       an MBA user (dbo.Users) who is not a customer contact
        @OwnSite     a live site of a customer in @Me's portal set
        @ForeignSite a live site of a customer @Me is not a contact of
*/
SET NOCOUNT ON;
SET XACT_ABORT OFF;   /* the procedures set their own; the harness must survive their THROWs */

DECLARE @Out TABLE (Seq INT IDENTITY, Section NVARCHAR(10), Test NVARCHAR(100),
                    Expected NVARCHAR(60), Actual NVARCHAR(60), Result NVARCHAR(80));

DROP TABLE IF EXISTS #C;
CREATE TABLE #C (customerContactId INT, customerId INT, customerName NVARCHAR(200), name NVARCHAR(100),
                 role NVARCHAR(100), phone NVARCHAR(100), additionalPhone NVARCHAR(100),
                 email NVARCHAR(100), customerSiteId INT);
DROP TABLE IF EXISTS #S;
CREATE TABLE #S (customerSiteId INT, customerId INT, customerName NVARCHAR(200), description NVARCHAR(100),
                 address NVARCHAR(160), state NVARCHAR(80), zip NVARCHAR(20), phone NVARCHAR(60),
                 siteCode INT, descriptionENG NVARCHAR(100), addressENG NVARCHAR(160),
                 stateENG NVARCHAR(80), isDeleted BIT);

/* ---------------------------------------------------------------------------------------------
   Fixtures
   --------------------------------------------------------------------------------------------- */
DECLARE @Me NVARCHAR(100), @OtherEmail NVARCHAR(100), @Staff NVARCHAR(100),
        @OwnSite INT, @OwnSiteCustomer INT, @ForeignSite INT, @PrimaryCust INT,
        @OwnCount INT, @SetCount INT;

DECLARE @Own TABLE (CustomerContactId INT PRIMARY KEY, CustomerId INT);

SELECT TOP (1) @Me = x.e
FROM (SELECT LOWER(LTRIM(RTRIM(cc.CustomerContactEmail))) AS e,
             COUNT(DISTINCT cc.CustomerId) AS n,
             MAX(CASE WHEN sited.CustomerId IS NOT NULL THEN 1 ELSE 0 END) AS sited
      FROM dbo.CustomerContacts AS cc
      LEFT JOIN (SELECT DISTINCT CustomerId FROM dbo.CustomerSites WHERE IsDeleted = 0) AS sited
          ON sited.CustomerId = cc.CustomerId
      WHERE ISNULL(cc.IsDeleted, 0) = 0 AND ISNULL(cc.IsActive, 1) = 1
        AND cc.CustomerContactEmail LIKE N'%_@_%._%'
        AND cc.CustomerContactEmail NOT LIKE N'%@%@%'
        AND cc.CustomerContactEmail NOT LIKE N'% %'
      GROUP BY LOWER(LTRIM(RTRIM(cc.CustomerContactEmail)))
      HAVING COUNT(DISTINCT cc.CustomerId) >= 2) AS x
ORDER BY x.sited DESC, x.n, x.e;

INSERT @Own (CustomerContactId, CustomerId)
SELECT cc.CustomerContactId, cc.CustomerId
FROM dbo.CustomerContacts AS cc
WHERE ISNULL(cc.IsDeleted, 0) = 0 AND ISNULL(cc.IsActive, 1) = 1
  AND LOWER(LTRIM(RTRIM(cc.CustomerContactEmail))) = @Me;

SET @OwnCount = (SELECT COUNT(*) FROM @Own);
SET @SetCount = (SELECT COUNT(*) FROM dbo.GetPortalCustomerIds(@Me));
SELECT @PrimaryCust = CustomerId FROM dbo.GetPortalCustomerIds(@Me) WHERE IsPrimary = 1;

SELECT TOP (1) @OtherEmail = LOWER(LTRIM(RTRIM(cc.CustomerContactEmail)))
FROM dbo.CustomerContacts AS cc
WHERE ISNULL(cc.IsDeleted, 0) = 0 AND ISNULL(cc.IsActive, 1) = 1
  AND cc.CustomerContactEmail LIKE N'%_@_%._%'
  AND cc.CustomerContactEmail NOT LIKE N'%@%@%'
  AND cc.CustomerContactEmail NOT LIKE N'% %'
  AND LOWER(LTRIM(RTRIM(cc.CustomerContactEmail))) <> @Me
ORDER BY cc.CustomerContactId;

SELECT TOP (1) @Staff = LOWER(LTRIM(RTRIM(u.Email)))
FROM dbo.Users AS u
WHERE u.Email LIKE N'%_@_%'
  AND NOT EXISTS (SELECT 1 FROM dbo.CustomerContacts AS cc
                  WHERE LOWER(LTRIM(RTRIM(cc.CustomerContactEmail))) = LOWER(LTRIM(RTRIM(u.Email))))
ORDER BY u.ID;

SELECT TOP (1) @OwnSite = cs.CustomerSiteId, @OwnSiteCustomer = cs.CustomerId
FROM dbo.CustomerSites AS cs
INNER JOIN dbo.GetPortalCustomerIds(@Me) AS m ON m.CustomerId = cs.CustomerId
WHERE cs.IsDeleted = 0
ORDER BY cs.CustomerSiteId;

SELECT TOP (1) @ForeignSite = cs.CustomerSiteId
FROM dbo.CustomerSites AS cs
WHERE cs.IsDeleted = 0
  AND cs.CustomerId NOT IN (SELECT CustomerId FROM @Own)
ORDER BY cs.CustomerSiteId;


DECLARE @Err INT, @A NVARCHAR(60), @B NVARCHAR(60), @N1 INT, @N2 INT, @K1 INT, @K2 INT;
DECLARE @Unknown NVARCHAR(100) = N'mba627-nobody-' + CONVERT(NVARCHAR(36), NEWID()) + N'@example.invalid';
DECLARE @NewEmail NVARCHAR(50) = N'mba627.' + LEFT(CONVERT(NVARCHAR(36), NEWID()), 8) + N'@example.com';

INSERT @Out (Section, Test, Expected, Actual, Result)
SELECT N'fixtures', N'@Me found, own rows / portal set', N'>=2 / >=1',
       CONCAT(@OwnCount, N' / ', @SetCount),
       IIF(@Me IS NOT NULL AND @OwnCount >= 2 AND @SetCount >= 1, N'PASS', N'SKIP: no multi-customer address');

/* =============================================================================================
   AssignCustomerContactsData
   ============================================================================================= */

/* C1 - unknown address is refused */
BEGIN TRAN; SET @Err = 0;
BEGIN TRY DELETE #C; INSERT #C EXEC dbo.AssignCustomerContactsData @LoggedInUserEmail = @Unknown, @CustomerContactPhone = N'1'; END TRY
BEGIN CATCH SET @Err = ERROR_NUMBER(); END CATCH
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @Out SELECT N'contacts', N'C1 unknown address refused', N'54001', @Err, IIF(@Err = 54001, N'PASS', N'FAIL');

/* C2 - a staff user who is not a contact is refused (no staff path any more) */
IF @Staff IS NULL
    INSERT @Out SELECT N'contacts', N'C2 staff address refused', N'54001', NULL, N'SKIP: no staff-only user';
ELSE
BEGIN
    BEGIN TRAN; SET @Err = 0;
    BEGIN TRY DELETE #C; INSERT #C EXEC dbo.AssignCustomerContactsData @LoggedInUserEmail = @Staff, @CustomerContactPhone = N'1'; END TRY
    BEGIN CATCH SET @Err = ERROR_NUMBER(); END CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT @Out SELECT N'contacts', N'C2 staff address refused', N'54001', @Err, IIF(@Err = 54001, N'PASS', N'FAIL');
END

/* C3 - phone change lands on every own row, nobody else's row in those customers moves,
        and NULL parameters keep their values (name unchanged) */
BEGIN TRAN; SET @Err = 0;
SELECT @K1 = CHECKSUM_AGG(BINARY_CHECKSUM(cc.CustomerContactId, cc.CustomerContactName, cc.CustomerContactPersonRole,
                                          cc.CustomerContactPhone, cc.CustomerContactAdditionalPhoneNumber,
                                          cc.CustomerContactEmail, cc.UpdatedDate, cc.CustomerSiteId))
FROM dbo.CustomerContacts AS cc
WHERE cc.CustomerId IN (SELECT CustomerId FROM @Own) AND cc.CustomerContactId NOT IN (SELECT CustomerContactId FROM @Own);
SELECT @K2 = CHECKSUM_AGG(BINARY_CHECKSUM(cc.CustomerContactId, cc.CustomerContactName))
FROM dbo.CustomerContacts AS cc WHERE cc.CustomerContactId IN (SELECT CustomerContactId FROM @Own);
BEGIN TRY DELETE #C; INSERT #C EXEC dbo.AssignCustomerContactsData @LoggedInUserEmail = @Me, @CustomerContactPhone = N'03-6270627'; END TRY
BEGIN CATCH SET @Err = ERROR_NUMBER(); END CATCH
SET @N1 = (SELECT COUNT(*) FROM dbo.CustomerContacts AS cc
           WHERE cc.CustomerContactId IN (SELECT CustomerContactId FROM @Own) AND cc.CustomerContactPhone = N'03-6270627');
SET @N2 = (SELECT COUNT(*) FROM #C);
SET @A = IIF(@K1 = (SELECT CHECKSUM_AGG(BINARY_CHECKSUM(cc.CustomerContactId, cc.CustomerContactName, cc.CustomerContactPersonRole,
                                          cc.CustomerContactPhone, cc.CustomerContactAdditionalPhoneNumber,
                                          cc.CustomerContactEmail, cc.UpdatedDate, cc.CustomerSiteId))
                    FROM dbo.CustomerContacts AS cc
                    WHERE cc.CustomerId IN (SELECT CustomerId FROM @Own) AND cc.CustomerContactId NOT IN (SELECT CustomerContactId FROM @Own))
                OR (@K1 IS NULL AND NOT EXISTS (SELECT 1 FROM dbo.CustomerContacts AS cc
                    WHERE cc.CustomerId IN (SELECT CustomerId FROM @Own) AND cc.CustomerContactId NOT IN (SELECT CustomerContactId FROM @Own))),
             N'same', N'CHANGED');
SET @B = IIF(@K2 = (SELECT CHECKSUM_AGG(BINARY_CHECKSUM(cc.CustomerContactId, cc.CustomerContactName))
                    FROM dbo.CustomerContacts AS cc WHERE cc.CustomerContactId IN (SELECT CustomerContactId FROM @Own)),
             N'same', N'CHANGED');
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @Out SELECT N'contacts', N'C3 phone saved on every own row (rows / returned)', CONCAT(@OwnCount, N' / ', @OwnCount),
                   CONCAT(@N1, N' / ', @N2), IIF(@Err = 0 AND @N1 = @OwnCount AND @N2 = @OwnCount, N'PASS', N'FAIL');
INSERT @Out SELECT N'contacts', N'C3 other contacts of the same customers untouched', N'same', @A, IIF(@A = N'same', N'PASS', N'FAIL');
INSERT @Out SELECT N'contacts', N'C3 NULL name keeps the name', N'same', @B, IIF(@B = N'same', N'PASS', N'FAIL');

/* C4 - empty string clears an optional field */
BEGIN TRAN; SET @Err = 0;
BEGIN TRY DELETE #C; INSERT #C EXEC dbo.AssignCustomerContactsData @LoggedInUserEmail = @Me, @CustomerContactPersonRole = N''; END TRY
BEGIN CATCH SET @Err = ERROR_NUMBER(); END CATCH
SET @N1 = (SELECT COUNT(*) FROM dbo.CustomerContacts AS cc
           WHERE cc.CustomerContactId IN (SELECT CustomerContactId FROM @Own) AND cc.CustomerContactPersonRole IS NULL);
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @Out SELECT N'contacts', N'C4 empty role clears it', CONCAT(@OwnCount, N''), CONCAT(@N1, N''), IIF(@Err = 0 AND @N1 = @OwnCount, N'PASS', N'FAIL');

/* C5 - name cannot be cleared */
BEGIN TRAN; SET @Err = 0;
BEGIN TRY DELETE #C; INSERT #C EXEC dbo.AssignCustomerContactsData @LoggedInUserEmail = @Me, @CustomerContactName = N'  '; END TRY
BEGIN CATCH SET @Err = ERROR_NUMBER(); END CATCH
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @Out SELECT N'contacts', N'C5 empty name refused', N'54002', @Err, IIF(@Err = 54002, N'PASS', N'FAIL');

/* C6 - MBA-627: a new e-mail is refused for now, and nothing else in the same call is written */
BEGIN TRAN; SET @Err = 0;
BEGIN TRY DELETE #C; INSERT #C EXEC dbo.AssignCustomerContactsData @LoggedInUserEmail = @Me,
                                    @CustomerContactEmail = @NewEmail, @CustomerContactPhone = N'03-6270627'; END TRY
BEGIN CATCH SET @Err = ERROR_NUMBER(); END CATCH
IF @@TRANCOUNT > 0 ROLLBACK;
SET @N1 = (SELECT COUNT(*) FROM dbo.CustomerContacts AS cc
           WHERE cc.CustomerContactId IN (SELECT CustomerContactId FROM @Own) AND cc.CustomerContactPhone = N'03-6270627');
SET @N2 = (SELECT COUNT(*) FROM dbo.GetPortalCustomerIds(@Me));
INSERT @Out SELECT N'contacts', N'C6 new e-mail refused / phone not saved / set kept', CONCAT(N'54006 / 0 / ', @SetCount),
                   CONCAT(@Err, N' / ', @N1, N' / ', @N2), IIF(@Err = 54006 AND @N1 = 0 AND @N2 = @SetCount, N'PASS', N'FAIL');

/* C7 - another person's e-mail is refused the same way */
IF @OtherEmail IS NULL
    INSERT @Out SELECT N'contacts', N'C7 another contact''s e-mail refused', N'54006', NULL, N'SKIP: no second address';
ELSE
BEGIN
    BEGIN TRAN; SET @Err = 0;
    BEGIN TRY DELETE #C; INSERT #C EXEC dbo.AssignCustomerContactsData @LoggedInUserEmail = @Me, @CustomerContactEmail = @OtherEmail; END TRY
    BEGIN CATCH SET @Err = ERROR_NUMBER(); END CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT @Out SELECT N'contacts', N'C7 another contact''s e-mail refused', N'54006', @Err, IIF(@Err = 54006, N'PASS', N'FAIL');
END

/* C8 - the form sends the current address back (any case, padded): accepted, address untouched */
BEGIN TRAN; SET @Err = 0;
SET @A = N' ' + UPPER(@Me) + N' ';
SET @K1 = (SELECT CHECKSUM_AGG(BINARY_CHECKSUM(cc.CustomerContactEmail)) FROM dbo.CustomerContacts AS cc
           WHERE cc.CustomerContactId IN (SELECT CustomerContactId FROM @Own));
BEGIN TRY DELETE #C; INSERT #C EXEC dbo.AssignCustomerContactsData @LoggedInUserEmail = @Me,
                                    @CustomerContactEmail = @A, @CustomerContactPhone = N'03-6270627'; END TRY
BEGIN CATCH SET @Err = ERROR_NUMBER(); END CATCH
SET @N1 = (SELECT COUNT(*) FROM dbo.CustomerContacts AS cc
           WHERE cc.CustomerContactId IN (SELECT CustomerContactId FROM @Own) AND cc.CustomerContactPhone = N'03-6270627');
SET @K2 = (SELECT CHECKSUM_AGG(BINARY_CHECKSUM(cc.CustomerContactEmail)) FROM dbo.CustomerContacts AS cc
           WHERE cc.CustomerContactId IN (SELECT CustomerContactId FROM @Own));
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @Out SELECT N'contacts', N'C8 own address sent back: saved / address kept', CONCAT(@OwnCount, N' / same'),
                   CONCAT(@N1, N' / ', IIF(@K1 = @K2, N'same', N'CHANGED')),
                   IIF(@Err = 0 AND @N1 = @OwnCount AND @K1 = @K2, N'PASS', N'FAIL');

/* C9 - a site of a customer the caller is not a contact of is refused */
IF @ForeignSite IS NULL
    INSERT @Out SELECT N'contacts', N'C9 foreign site refused', N'54005', NULL, N'SKIP: no foreign site';
ELSE
BEGIN
    BEGIN TRAN; SET @Err = 0;
    BEGIN TRY DELETE #C; INSERT #C EXEC dbo.AssignCustomerContactsData @LoggedInUserEmail = @Me, @CustomerSiteId = @ForeignSite; END TRY
    BEGIN CATCH SET @Err = ERROR_NUMBER(); END CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT @Out SELECT N'contacts', N'C9 foreign site refused', N'54005', @Err, IIF(@Err = 54005, N'PASS', N'FAIL');
END

/* C10 - own site is written only on the caller's row of that customer */
IF @OwnSite IS NULL
    INSERT @Out SELECT N'contacts', N'C10 own site on that customer''s row only', NULL, NULL, N'SKIP: no site in the caller''s set';
ELSE
BEGIN
    BEGIN TRAN; SET @Err = 0;
    BEGIN TRY DELETE #C; INSERT #C EXEC dbo.AssignCustomerContactsData @LoggedInUserEmail = @Me, @CustomerSiteId = @OwnSite; END TRY
    BEGIN CATCH SET @Err = ERROR_NUMBER(); END CATCH
    SET @N1 = (SELECT COUNT(*) FROM dbo.CustomerContacts AS cc
               WHERE cc.CustomerContactId IN (SELECT CustomerContactId FROM @Own) AND cc.CustomerSiteId = @OwnSite);
    SET @N2 = (SELECT COUNT(*) FROM @Own WHERE CustomerId = @OwnSiteCustomer);
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT @Out SELECT N'contacts', N'C10 own site on that customer''s row only', CONCAT(@N2, N''), CONCAT(@N1, N''),
                       IIF(@Err = 0 AND @N1 = @N2, N'PASS', N'FAIL');
END

/* C11 - the removed parameters fail loudly instead of being half-honoured */
SET @Err = 0;
BEGIN TRY
    EXEC sp_executesql N'EXEC dbo.AssignCustomerContactsData @LoggedInUserEmail = @e, @CustomerContactsIdsToRemove = N''1''',
                       N'@e NVARCHAR(100)', @e = @Me;
END TRY
BEGIN CATCH SET @Err = ERROR_NUMBER(); END CATCH
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @Out SELECT N'contacts', N'C11 @CustomerContactsIdsToRemove no longer accepted', N'8145', @Err, IIF(@Err = 8145, N'PASS', N'FAIL');

/* C12 - Priority marks the caller inactive: refused, and nothing moves. Simulated inside the case's
   own transaction (STAGE holds no inactive-only address); GetPortalCustomerIds and the own-row lookup
   both filter on IsActive, and this keeps them from drifting apart into a silent "saved". */
BEGIN TRAN; SET @Err = 0;
UPDATE dbo.CustomerContacts SET IsActive = 0 WHERE CustomerContactId IN (SELECT CustomerContactId FROM @Own);
BEGIN TRY DELETE #C; INSERT #C EXEC dbo.AssignCustomerContactsData @LoggedInUserEmail = @Me, @CustomerContactPhone = N'03-6270627'; END TRY
BEGIN CATCH SET @Err = ERROR_NUMBER(); END CATCH
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @Out SELECT N'contacts', N'C12 inactive contact refused', N'54001', @Err, IIF(@Err = 54001, N'PASS', N'FAIL');
/* =============================================================================================
   AssignCustomerSitesData
   ============================================================================================= */

/* S1 - unknown address is refused */
BEGIN TRAN; SET @Err = 0;
BEGIN TRY DELETE #S; INSERT #S EXEC dbo.AssignCustomerSitesData @LoggedInUserEmail = @Unknown, @CustomerSitesIdsToRemove = N'1'; END TRY
BEGIN CATCH SET @Err = ERROR_NUMBER(); END CATCH
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @Out SELECT N'sites', N'S1 unknown address refused (even for removal)', N'54101', @Err, IIF(@Err = 54101, N'PASS', N'FAIL');

/* S2 - removing another customer's site is refused and the site survives */
IF @ForeignSite IS NULL
    INSERT @Out SELECT N'sites', N'S2 foreign site removal refused', N'54102', NULL, N'SKIP: no foreign site';
ELSE
BEGIN
    BEGIN TRAN; SET @Err = 0;
    DECLARE @List NVARCHAR(400) = CONCAT(@ForeignSite, N'');
    BEGIN TRY DELETE #S; INSERT #S EXEC dbo.AssignCustomerSitesData @LoggedInUserEmail = @Me, @CustomerSitesIdsToRemove = @List; END TRY
    BEGIN CATCH SET @Err = ERROR_NUMBER(); END CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    SET @N1 = (SELECT CAST(IsDeleted AS INT) FROM dbo.CustomerSites WHERE CustomerSiteId = @ForeignSite);
    INSERT @Out SELECT N'sites', N'S2 foreign site removal refused / still live', N'54102 / 0', CONCAT(@Err, N' / ', @N1),
                       IIF(@Err = 54102 AND @N1 = 0, N'PASS', N'FAIL');
END

/* S3 - own + foreign in one list: all or nothing, the own site is not removed either */
IF @ForeignSite IS NULL OR @OwnSite IS NULL
    INSERT @Out SELECT N'sites', N'S3 mixed list refused whole', N'54102', NULL, N'SKIP: needs own and foreign site';
ELSE
BEGIN
    BEGIN TRAN; SET @Err = 0;
    SET @List = CONCAT(@OwnSite, N',', @ForeignSite);
    BEGIN TRY DELETE #S; INSERT #S EXEC dbo.AssignCustomerSitesData @LoggedInUserEmail = @Me, @CustomerSitesIdsToRemove = @List; END TRY
    BEGIN CATCH SET @Err = ERROR_NUMBER(); END CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    SET @N1 = (SELECT CAST(IsDeleted AS INT) FROM dbo.CustomerSites WHERE CustomerSiteId = @OwnSite);
    INSERT @Out SELECT N'sites', N'S3 mixed list refused whole / own still live', N'54102 / 0', CONCAT(@Err, N' / ', @N1),
                       IIF(@Err = 54102 AND @N1 = 0, N'PASS', N'FAIL');
END

/* S4 - junk and empty lists are refused, not turned into 0 */
BEGIN TRAN; SET @Err = 0;
BEGIN TRY DELETE #S; INSERT #S EXEC dbo.AssignCustomerSitesData @LoggedInUserEmail = @Me, @CustomerSitesIdsToRemove = N'abc'; END TRY
BEGIN CATCH SET @Err = ERROR_NUMBER(); END CATCH
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @Out SELECT N'sites', N'S4 non-numeric id refused', N'54102', @Err, IIF(@Err = 54102, N'PASS', N'FAIL');

BEGIN TRAN; SET @Err = 0;
BEGIN TRY DELETE #S; INSERT #S EXEC dbo.AssignCustomerSitesData @LoggedInUserEmail = @Me, @CustomerSitesIdsToRemove = N' , '; END TRY
BEGIN CATCH SET @Err = ERROR_NUMBER(); END CATCH
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @Out SELECT N'sites', N'S4 empty list refused', N'54102', @Err, IIF(@Err = 54102, N'PASS', N'FAIL');

/* S5 - removing an own site soft-deletes it; removing it again is accepted and changes nothing;
   S6 - a removed site cannot be edited (there is no revert any more) */
IF @OwnSite IS NULL
    INSERT @Out SELECT N'sites', N'S5/S6 own site remove, re-remove, edit removed', NULL, NULL, N'SKIP: no site in the caller''s set';
ELSE
BEGIN
    DECLARE @Stamp1 DATETIME2(6), @Stamp2 DATETIME2(6), @Err2 INT = 0, @Err3 INT = 0;
    BEGIN TRAN; SET @Err = 0;
    SET @List = CONCAT(@OwnSite, N'');
    BEGIN TRY DELETE #S; INSERT #S EXEC dbo.AssignCustomerSitesData @LoggedInUserEmail = @Me, @CustomerSitesIdsToRemove = @List; END TRY
    BEGIN CATCH SET @Err = ERROR_NUMBER(); END CATCH
    SELECT @N1 = CAST(IsDeleted AS INT), @Stamp1 = UpdatedDate FROM dbo.CustomerSites WHERE CustomerSiteId = @OwnSite;
    IF @Err = 0
    BEGIN TRY DELETE #S; INSERT #S EXEC dbo.AssignCustomerSitesData @LoggedInUserEmail = @Me, @CustomerSitesIdsToRemove = @List; END TRY
    BEGIN CATCH SET @Err2 = ERROR_NUMBER(); END CATCH
    SELECT @Stamp2 = UpdatedDate FROM dbo.CustomerSites WHERE CustomerSiteId = @OwnSite;
    SET @N2 = (SELECT COUNT(*) FROM #S);
    IF @Err = 0 AND @Err2 = 0
    BEGIN TRY DELETE #S; INSERT #S EXEC dbo.AssignCustomerSitesData @LoggedInUserEmail = @Me, @CustomerSiteId = @OwnSite, @CustomerSitePhone = N'1'; END TRY
    BEGIN CATCH SET @Err3 = ERROR_NUMBER(); END CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT @Out SELECT N'sites', N'S5 own site removed', N'1', CONCAT(@N1, N''), IIF(@Err = 0 AND @N1 = 1, N'PASS', N'FAIL');
    INSERT @Out SELECT N'sites', N'S5 re-remove: accepted / rows written / stamp', N'0 / 0 / same',
                       CONCAT(@Err2, N' / ', @N2, N' / ', IIF(@Stamp1 = @Stamp2, N'same', N'CHANGED')),
                       IIF(@Err2 = 0 AND @N2 = 0 AND @Stamp1 = @Stamp2, N'PASS', N'FAIL');
    INSERT @Out SELECT N'sites', N'S6 removed site cannot be edited', N'54103', @Err3, IIF(@Err3 = 54103, N'PASS', N'FAIL');
END

/* S7 - editing another customer's site is refused */
IF @ForeignSite IS NULL
    INSERT @Out SELECT N'sites', N'S7 foreign site edit refused', N'54103', NULL, N'SKIP: no foreign site';
ELSE
BEGIN
    BEGIN TRAN; SET @Err = 0;
    BEGIN TRY DELETE #S; INSERT #S EXEC dbo.AssignCustomerSitesData @LoggedInUserEmail = @Me, @CustomerSiteId = @ForeignSite, @CustomerSitePhone = N'1'; END TRY
    BEGIN CATCH SET @Err = ERROR_NUMBER(); END CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT @Out SELECT N'sites', N'S7 foreign site edit refused', N'54103', @Err, IIF(@Err = 54103, N'PASS', N'FAIL');
END

/* S8 - editing an own site saves, NULL keeps the rest */
IF @OwnSite IS NULL
    INSERT @Out SELECT N'sites', N'S8 own site edit', NULL, NULL, N'SKIP: no site in the caller''s set';
ELSE
BEGIN
    BEGIN TRAN; SET @Err = 0;
    SET @K1 = (SELECT BINARY_CHECKSUM(CustomerSiteAddress, CustomerSiteDescription) FROM dbo.CustomerSites WHERE CustomerSiteId = @OwnSite);
    BEGIN TRY DELETE #S; INSERT #S EXEC dbo.AssignCustomerSitesData @LoggedInUserEmail = @Me, @CustomerSiteId = @OwnSite, @CustomerSitePhone = N'03-6270627'; END TRY
    BEGIN CATCH SET @Err = ERROR_NUMBER(); END CATCH
    SET @A = (SELECT CustomerSitePhone FROM dbo.CustomerSites WHERE CustomerSiteId = @OwnSite);
    SET @K2 = (SELECT BINARY_CHECKSUM(CustomerSiteAddress, CustomerSiteDescription) FROM dbo.CustomerSites WHERE CustomerSiteId = @OwnSite);
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT @Out SELECT N'sites', N'S8 own site edit saved, rest kept', N'03-6270627 / same', CONCAT(@A, N' / ', IIF(@K1 = @K2, N'same', N'CHANGED')),
                       IIF(@Err = 0 AND @A = N'03-6270627' AND @K1 = @K2, N'PASS', N'FAIL');
END

/* S9 - add goes to the primary customer, with no site code (the code is Priority's) */
BEGIN TRAN; SET @Err = 0;
BEGIN TRY DELETE #S; INSERT #S EXEC dbo.AssignCustomerSitesData @LoggedInUserEmail = @Me,
                                    @CustomerSiteDescription = N'MBA-627 test site'; END TRY
BEGIN CATCH SET @Err = ERROR_NUMBER(); END CATCH
SELECT TOP (1) @N1 = customerId, @N2 = siteCode FROM #S;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @Out SELECT N'sites', N'S9 new site: customer / code', N'primary / NULL',
                   CONCAT(IIF(@N1 = @PrimaryCust, N'primary', N'other'), N' / ', ISNULL(CAST(@N2 AS NVARCHAR(12)), N'NULL')),
                   IIF(@Err = 0 AND @N1 = @PrimaryCust AND @N2 IS NULL, N'PASS', N'FAIL');

/* S10 - the removed parameters fail loudly instead of being half-honoured */
SET @Err = 0;
BEGIN TRY
    EXEC sp_executesql N'EXEC dbo.AssignCustomerSitesData @LoggedInUserEmail = @e, @CustomerSiteDescription = N''x'', @CustomerSiteCode = 1',
                       N'@e NVARCHAR(100)', @e = @Me;
END TRY
BEGIN CATCH SET @Err = ERROR_NUMBER(); END CATCH
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @Out SELECT N'sites', N'S10 @CustomerSiteCode no longer accepted', N'8145', @Err, IIF(@Err = 8145, N'PASS', N'FAIL');

SET @Err = 0;
BEGIN TRY
    EXEC sp_executesql N'EXEC dbo.AssignCustomerSitesData @LoggedInUserEmail = @e, @CustomerSiteId = 1, @RevertDeletion = 1',
                       N'@e NVARCHAR(100)', @e = @Me;
END TRY
BEGIN CATCH SET @Err = ERROR_NUMBER(); END CATCH
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @Out SELECT N'sites', N'S10 @RevertDeletion no longer accepted', N'8145', @Err, IIF(@Err = 8145, N'PASS', N'FAIL');

/* S11 - a new site needs a description or an address */
BEGIN TRAN; SET @Err = 0;
BEGIN TRY DELETE #S; INSERT #S EXEC dbo.AssignCustomerSitesData @LoggedInUserEmail = @Me, @CustomerSitePhone = N'1'; END TRY
BEGIN CATCH SET @Err = ERROR_NUMBER(); END CATCH
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @Out SELECT N'sites', N'S11 empty new site refused', N'54105', @Err, IIF(@Err = 54105, N'PASS', N'FAIL');

/* S12 - the same for sites */
BEGIN TRAN; SET @Err = 0;
UPDATE dbo.CustomerContacts SET IsActive = 0 WHERE CustomerContactId IN (SELECT CustomerContactId FROM @Own);
BEGIN TRY DELETE #S; INSERT #S EXEC dbo.AssignCustomerSitesData @LoggedInUserEmail = @Me, @CustomerSiteDescription = N'MBA-627 test site'; END TRY
BEGIN CATCH SET @Err = ERROR_NUMBER(); END CATCH
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @Out SELECT N'sites', N'S12 inactive contact refused', N'54101', @Err, IIF(@Err = 54101, N'PASS', N'FAIL');

/* S13 - app PR #165 sends every field, a blank one as '': on an edit '' clears to NULL (never ''),
   NULL keeps, and text is trimmed */
IF @OwnSite IS NULL
    INSERT @Out SELECT N'sites', N'S13 edit: '''' clears, NULL keeps, trimmed', NULL, NULL, N'SKIP: no site in the caller''s set';
ELSE
BEGIN
    DECLARE @Zip0 NVARCHAR(20), @ZipAfter NVARCHAR(20), @StateAfter NVARCHAR(80), @PhoneAfter NVARCHAR(60);
    BEGIN TRAN; SET @Err = 0;
    /* give the site a description so clearing the address below stays legal */
    UPDATE dbo.CustomerSites SET CustomerSiteDescription = N'MBA-627 test site', CustomerSiteState = N'x'
    WHERE CustomerSiteId = @OwnSite;
    SELECT @Zip0 = CustomerSiteZIP FROM dbo.CustomerSites WHERE CustomerSiteId = @OwnSite;
    BEGIN TRY DELETE #S; INSERT #S EXEC dbo.AssignCustomerSitesData @LoggedInUserEmail = @Me, @CustomerSiteId = @OwnSite,
                                        @CustomerSiteState = N'', @CustomerSitePhone = N'  03-6270627  '; END TRY
    BEGIN CATCH SET @Err = ERROR_NUMBER(); END CATCH
    SELECT @StateAfter = ISNULL(CustomerSiteState, N'<NULL>'), @PhoneAfter = CustomerSitePhone, @ZipAfter = CustomerSiteZIP
    FROM dbo.CustomerSites WHERE CustomerSiteId = @OwnSite;
    IF @@TRANCOUNT > 0 ROLLBACK;
    INSERT @Out SELECT N'sites', N'S13 edit: state '''' -> NULL / phone trimmed / zip kept', N'<NULL> / 03-6270627 / same',
                       CONCAT(@StateAfter, N' / ', @PhoneAfter, N' / ', IIF(ISNULL(@Zip0, N'~') = ISNULL(@ZipAfter, N'~'), N'same', N'CHANGED')),
                       IIF(@Err = 0 AND @StateAfter = N'<NULL>' AND @PhoneAfter = N'03-6270627'
                           AND ISNULL(@Zip0, N'~') = ISNULL(@ZipAfter, N'~'), N'PASS', N'FAIL');
END

/* S14 - an edit that clears both description and address is refused, and nothing changes */
IF @OwnSite IS NULL
    INSERT @Out SELECT N'sites', N'S14 edit clearing description and address refused', N'54105', NULL, N'SKIP: no site in the caller''s set';
ELSE
BEGIN
    BEGIN TRAN; SET @Err = 0;
    SET @K1 = (SELECT BINARY_CHECKSUM(CustomerSiteAddress, CustomerSiteDescription, UpdatedDate) FROM dbo.CustomerSites WHERE CustomerSiteId = @OwnSite);
    BEGIN TRY DELETE #S; INSERT #S EXEC dbo.AssignCustomerSitesData @LoggedInUserEmail = @Me, @CustomerSiteId = @OwnSite,
                                        @CustomerSiteDescription = N' ', @CustomerSiteAddress = N''; END TRY
    BEGIN CATCH SET @Err = ERROR_NUMBER(); END CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    SET @K2 = (SELECT BINARY_CHECKSUM(CustomerSiteAddress, CustomerSiteDescription, UpdatedDate) FROM dbo.CustomerSites WHERE CustomerSiteId = @OwnSite);
    INSERT @Out SELECT N'sites', N'S14 edit clearing description and address refused / unchanged', N'54105 / same',
                       CONCAT(@Err, N' / ', IIF(@K1 = @K2, N'same', N'CHANGED')), IIF(@Err = 54105 AND @K1 = @K2, N'PASS', N'FAIL');
END

/* S15 - a new site stores blanks as NULL, and trimmed text */
BEGIN TRAN; SET @Err = 0;
BEGIN TRY DELETE #S; INSERT #S EXEC dbo.AssignCustomerSitesData @LoggedInUserEmail = @Me,
                                    @CustomerSiteDescription = N'  MBA-627 test site  ', @CustomerSiteAddress = N'',
                                    @CustomerSiteState = N'', @CustomerSiteZIP = N' ', @CustomerSitePhone = N'',
                                    @CustomerSiteDescriptionENG = N'', @CustomerSiteAddressENG = N'', @CustomerSiteStateENG = N''; END TRY
BEGIN CATCH SET @Err = ERROR_NUMBER(); END CATCH
SELECT TOP (1) @A = description,
       @N1 = IIF(address IS NULL AND state IS NULL AND zip IS NULL AND phone IS NULL
                 AND descriptionENG IS NULL AND addressENG IS NULL AND stateENG IS NULL, 1, 0)
FROM #S;
IF @@TRANCOUNT > 0 ROLLBACK;
INSERT @Out SELECT N'sites', N'S15 new site: description trimmed / blanks are NULL', N'MBA-627 test site / 1',
                   CONCAT(@A, N' / ', @N1), IIF(@Err = 0 AND @A = N'MBA-627 test site' AND @N1 = 1, N'PASS', N'FAIL');
SELECT Seq, Section, Test, Expected, Actual, Result FROM @Out ORDER BY Seq;
