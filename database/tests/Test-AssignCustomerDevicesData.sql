/*
    Tests for dbo.AssignCustomerDevicesData                                              MBA-996
    ---------------------------------------------------------------------------------------------
    The portal's add / edit / remove of a device, with the device entity loaded (phase 1): who may
    write which device, the serial clash in both of Priority's forms, the fields Priority owns on a
    registered device (54208), and categories that must fit together (54209).

    Run against a database where MBA-996 phases 1-3 are deployed and the register is loaded.
    Anything other than 'PASS' in Result is a failure; 'SKIP' says why a case could not run.

    EVERY CASE RUNS IN ITS OWN TRANSACTION AND IS ROLLED BACK. A refusal thrown inside the
    procedure (XACT_ABORT ON) dooms the transaction around it, so cases cannot share one. Results
    go to a table variable, which a rollback does not touch. The file leaves the database as it
    found it. Test values start with 'MBA996T-'.

    Fixtures, picked from the data:
      @Me, @Cust    a live contact address and a customer of its portal set that has a visible
                    registered device whose serial carries the customer's code, a live site and a
                    live contact
      @Reg          that registered device, one with a manufacturer and a model (clearing an empty
                    one is no change, so R3 would prove nothing); @RegSerial its serial, @RegBody the serial without
                    "<CustomerCode>-"
      @ForeignSite, @ForeignContact, @ForeignDevice   of a customer outside @Me's set
      @Main, @Sec, @Spec, @Ref    a pair of categories with a specification and a reference document
                    that fit it; @OtherRef, a reference document of another secondary category;
                    @OtherMain, another main category. Every secondary category and specification on STAGE
                    belongs to one main category (2026-11-15), so the cases that need a misfit create one
                    inside their transaction ('MBA996T-' names).
*/
SET NOCOUNT ON;
SET XACT_ABORT OFF;

DECLARE @Out TABLE (Seq INT IDENTITY, Test NVARCHAR(100), Expected NVARCHAR(40), Actual NVARCHAR(120), Result NVARCHAR(40));

DROP TABLE IF EXISTS #W;
CREATE TABLE #W (customerDeviceId INT, customerId INT, serialNumber NVARCHAR(50), isDeleted BIT, isRegistered BIT);

DECLARE @Me NVARCHAR(100), @Cust INT, @Code NVARCHAR(50), @Site INT, @Contact INT,
        @Reg INT, @RegSerial NVARCHAR(50), @RegBody NVARCHAR(50),
        @ForeignSite INT, @ForeignContact INT, @ForeignDevice INT,
        @Main INT, @Sec INT, @Spec INT, @Ref INT, @OtherRef INT, @OtherMain INT;

/* @Me and @Cust: the first live address whose portal set holds a fitting customer */
DROP TABLE IF EXISTS #Cand;
SELECT TOP (200) LOWER(LTRIM(RTRIM(cc.CustomerContactEmail))) AS Email
INTO #Cand
FROM dbo.CustomerContacts AS cc
JOIN dbo.Customers AS c ON c.CustomerId = cc.CustomerId
WHERE cc.IsDeleted = 0 AND cc.IsActive = 1 AND cc.CustomerContactEmail LIKE N'%_@_%'
  AND c.CustomerCode IS NOT NULL
  AND EXISTS (SELECT 1 FROM dbo.vwCustomerDevices AS v
              WHERE v.CustomerId = cc.CustomerId AND v.IsRegistered = 1
                AND v.SerialNumber LIKE c.CustomerCode + N'-_%'
                AND NULLIF(LTRIM(RTRIM(v.OrdersDeviceManufacturer)), N'') IS NOT NULL AND NULLIF(LTRIM(RTRIM(v.Model)), N'') IS NOT NULL)
  AND EXISTS (SELECT 1 FROM dbo.CustomerSites AS s WHERE s.CustomerId = cc.CustomerId AND ISNULL(s.IsDeleted, 0) = 0)
GROUP BY LOWER(LTRIM(RTRIM(cc.CustomerContactEmail)))
ORDER BY LOWER(LTRIM(RTRIM(cc.CustomerContactEmail)));

SELECT TOP (1) @Me = k.Email, @Cust = m.CustomerId, @Code = c.CustomerCode
FROM #Cand AS k
CROSS APPLY dbo.GetPortalCustomerIds(k.Email) AS m
JOIN dbo.Customers AS c ON c.CustomerId = m.CustomerId
WHERE c.CustomerCode IS NOT NULL
  AND EXISTS (SELECT 1 FROM dbo.vwCustomerDevices AS v
              WHERE v.CustomerId = m.CustomerId AND v.IsRegistered = 1 AND v.SerialNumber LIKE c.CustomerCode + N'-_%'
                AND NULLIF(LTRIM(RTRIM(v.OrdersDeviceManufacturer)), N'') IS NOT NULL AND NULLIF(LTRIM(RTRIM(v.Model)), N'') IS NOT NULL)
  AND EXISTS (SELECT 1 FROM dbo.CustomerSites AS s WHERE s.CustomerId = m.CustomerId AND ISNULL(s.IsDeleted, 0) = 0)
  AND EXISTS (SELECT 1 FROM dbo.CustomerContacts AS x WHERE x.CustomerId = m.CustomerId AND x.IsDeleted = 0 AND x.IsActive = 1)
ORDER BY k.Email, m.CustomerId;

SELECT TOP (1) @Reg = v.CustomerDeviceID, @RegSerial = v.SerialNumber,
               @RegBody = SUBSTRING(v.SerialNumber, LEN(@Code) + 2, 50)
FROM dbo.vwCustomerDevices AS v
WHERE v.CustomerId = @Cust AND v.IsRegistered = 1 AND v.SerialNumber LIKE @Code + N'-_%'
  AND NULLIF(LTRIM(RTRIM(v.OrdersDeviceManufacturer)), N'') IS NOT NULL AND NULLIF(LTRIM(RTRIM(v.Model)), N'') IS NOT NULL
ORDER BY v.CustomerDeviceID;

SELECT TOP (1) @Site = s.CustomerSiteId FROM dbo.CustomerSites AS s
WHERE s.CustomerId = @Cust AND ISNULL(s.IsDeleted, 0) = 0 ORDER BY s.CustomerSiteId;
SELECT TOP (1) @Contact = x.CustomerContactId FROM dbo.CustomerContacts AS x
WHERE x.CustomerId = @Cust AND x.IsDeleted = 0 AND x.IsActive = 1 ORDER BY x.CustomerContactId;

SELECT TOP (1) @ForeignSite = s.CustomerSiteId FROM dbo.CustomerSites AS s
WHERE s.CustomerId NOT IN (SELECT CustomerId FROM dbo.GetPortalCustomerIds(@Me)) AND ISNULL(s.IsDeleted, 0) = 0
ORDER BY s.CustomerSiteId;
SELECT TOP (1) @ForeignContact = x.CustomerContactId FROM dbo.CustomerContacts AS x
WHERE x.CustomerId NOT IN (SELECT CustomerId FROM dbo.GetPortalCustomerIds(@Me)) AND x.IsDeleted = 0 AND x.IsActive = 1
ORDER BY x.CustomerContactId;
SELECT TOP (1) @ForeignDevice = v.CustomerDeviceID FROM dbo.vwCustomerDevices AS v
WHERE v.CustomerId NOT IN (SELECT CustomerId FROM dbo.GetPortalCustomerIds(@Me))
ORDER BY v.CustomerDeviceID;

/* a specification linked to a secondary category of its own main category, with a reference document */
SELECT TOP (1) @Main = ms.MainCategoryId, @Sec = sc.ID, @Spec = ms.ID
FROM dbo.MeasurementsSpecifications AS ms
JOIN dbo.MeasurementsSpecificationsToSecondCategory AS l ON l.MeasurementsSpecificationId = ms.ID AND l.IsDeleted = 0
JOIN dbo.SecondaryCategories AS sc ON sc.ID = l.SecondaryCategoryId AND sc.IsDeleted = 0 AND sc.MainCategoryId = ms.MainCategoryId
WHERE ms.IsDeleted = 0
  AND EXISTS (SELECT 1 FROM dbo.SpecificationReference AS sr WHERE sr.SecondaryCategoryId = sc.ID AND sr.IsDeleted = 0)
ORDER BY ms.ID;
SELECT TOP (1) @Ref = sr.ID FROM dbo.SpecificationReference AS sr
WHERE sr.SecondaryCategoryId = @Sec AND sr.IsDeleted = 0 ORDER BY sr.ID;
SELECT TOP (1) @OtherMain = mc.ID FROM dbo.MainCategories AS mc WHERE mc.ID <> @Main ORDER BY mc.ID;
SELECT TOP (1) @OtherRef = sr.ID FROM dbo.SpecificationReference AS sr
WHERE sr.IsDeleted = 0 AND sr.SecondaryCategoryId <> @Sec ORDER BY sr.ID;

INSERT @Out SELECT N'0 fixtures: caller, customer, registered device, site, contact', N'found',
       IIF(@Me IS NULL OR @Reg IS NULL OR @Site IS NULL OR @Contact IS NULL, N'missing', N'found'),
       IIF(@Me IS NULL OR @Reg IS NULL OR @Site IS NULL OR @Contact IS NULL, N'FAIL - nothing below can run', N'PASS');
INSERT @Out SELECT N'0 fixtures: foreign site, contact, device; categories', N'found',
       CONCAT(IIF(@ForeignSite IS NULL, N'site ', N''), IIF(@ForeignContact IS NULL, N'contact ', N''),
              IIF(@ForeignDevice IS NULL, N'device ', N''), IIF(@Spec IS NULL OR @Ref IS NULL, N'spec ', N''),
              IIF(@OtherMain IS NULL OR @OtherRef IS NULL, N'other-spec', N''),
              IIF(@ForeignSite IS NULL OR @ForeignContact IS NULL OR @ForeignDevice IS NULL OR @Spec IS NULL
                  OR @Ref IS NULL OR @OtherMain IS NULL OR @OtherRef IS NULL, N' missing', N'found')),
       IIF(@ForeignSite IS NULL OR @ForeignContact IS NULL OR @ForeignDevice IS NULL OR @Spec IS NULL
           OR @Ref IS NULL OR @OtherMain IS NULL OR @OtherRef IS NULL, N'SKIP - some cases skip', N'PASS');

/* ---------------------------------------------------------------------------------------------
   The cases. Each: optional Setup (runs first, its result rows are discarded), the Call (its rows
   go to #W), then either an expected error number, or a Check that sets @Ok = 1 on success. Pre runs
   between Setup and the Call and may DECLARE what the Call passes (EXEC takes no subqueries).
   --------------------------------------------------------------------------------------------- */
DECLARE @Cases TABLE (Seq INT IDENTITY, Test NVARCHAR(100), Setup NVARCHAR(MAX), Pre NVARCHAR(MAX), CallSql NVARCHAR(MAX),
                      ExpectErr INT, CheckSql NVARCHAR(MAX));

DECLARE @P NVARCHAR(MAX) = N'EXEC dbo.AssignCustomerDevicesData @LoggedInUserEmail = @Me';

INSERT @Cases (Test, Setup, Pre, CallSql, ExpectErr, CheckSql) VALUES
(N'A1 an address that is no portal contact is refused', NULL, NULL,
 N'EXEC dbo.AssignCustomerDevicesData @LoggedInUserEmail = N''nobody.mba996@example.invalid'', @SerialNumber = N''MBA996T-1''',
 54201, NULL),
(N'A2 add: a typed device of the site''s customer, not registered', NULL, NULL,
 @P + N', @CustomerSiteId = @Site, @CustomerContactId = @Contact, @SerialNumber = N''MBA996T-new'', @Model = N''MBA996T-m''',
 NULL, N'SELECT @Ok = COUNT(*) FROM #W WHERE customerId = @Cust AND isRegistered = 0 AND isDeleted = 0
          AND serialNumber = N''MBA996T-new''
          AND EXISTS (SELECT 1 FROM dbo.CustomerDevices AS d WHERE d.CustomerDeviceID = #W.customerDeviceId
                      AND d.SERN IS NULL AND d.Model = N''MBA996T-m'' AND d.CustomerSiteId = @Site);'),
(N'A3 add: no serial number', NULL, NULL, @P + N', @CustomerSiteId = @Site, @SerialNumber = N''  ''', 54206, NULL),
(N'A4 add: another customer''s site', NULL, NULL, @P + N', @CustomerSiteId = @ForeignSite, @SerialNumber = N''MBA996T-4''', 54204, NULL),
(N'A5 add: another customer''s contact', NULL, NULL,
 @P + N', @CustomerSiteId = @Site, @CustomerContactId = @ForeignContact, @SerialNumber = N''MBA996T-5''', 54205, NULL),
(N'S1 add: the bare serial of a registered device clashes', NULL, NULL,
 @P + N', @CustomerSiteId = @Site, @SerialNumber = @RegBody', 54207, NULL),
(N'S2 add: the registered serial as Priority writes it clashes', NULL, NULL,
 @P + N', @CustomerSiteId = @Site, @SerialNumber = @RegSerial', 54207, NULL),
(N'S3 add: <code>-serial clashes with a typed bare serial',
 @P + N', @CustomerSiteId = @Site, @SerialNumber = N''MBA996T-s3''',
 N'DECLARE @S NVARCHAR(50) = @Code + N''-MBA996T-s3'';',
 @P + N', @CustomerSiteId = @Site, @SerialNumber = @S', 54207, NULL),
(N'S4 add: a hidden registered device does not clash',
 @P + N', @CustomerDevicesIdsToRemove = @RegText', NULL,
 @P + N', @CustomerSiteId = @Site, @SerialNumber = @RegBody',
 NULL, N'SELECT @Ok = COUNT(*) FROM #W WHERE isRegistered = 0 AND customerId = @Cust;'),
(N'R1 registered: changing the model is refused', NULL, NULL,
 @P + N', @CustomerDeviceId = @Reg, @Model = N''MBA996T-model''', 54208, NULL),
(N'R2 registered: changing the serial is refused', NULL, NULL,
 @P + N', @CustomerDeviceId = @Reg, @SerialNumber = N''MBA996T-serial''', 54208, NULL),
(N'R3 registered: clearing the manufacturer is refused', NULL, NULL,
 @P + N', @CustomerDeviceId = @Reg, @OrdersDeviceManufacturer = N''''', 54208, NULL),
(N'R4 registered: the next calibration date is refused', NULL, NULL,
 @P + N', @CustomerDeviceId = @Reg, @NextCalibrationDate = ''2099-01-01''', 54208, NULL),
(N'R5 registered: the calibration interval is refused', NULL, NULL,
 @P + N', @CustomerDeviceId = @Reg, @CalibrationIntervalMonths = 251', 54208, NULL),
(N'R6 registered: the device type is refused', NULL, NULL,
 @P + N', @CustomerDeviceId = @Reg, @OrdersProductTypeId = 2147483000', 54208, NULL),
(N'R7 registered: Priority values sent back unchanged + a new location are accepted', NULL,
 N'DECLARE @RegModel NVARCHAR(150) = (SELECT Model FROM dbo.CustomerDevices WHERE CustomerDeviceID = @Reg);',
 @P + N', @CustomerDeviceId = @Reg, @SerialNumber = @RegSerial, @Model = @RegModel,
          @DeviceLocation = N''MBA996T-loc''',
 NULL, N'SELECT @Ok = COUNT(*) FROM #W AS w JOIN dbo.CustomerDevices AS d ON d.CustomerDeviceID = w.customerDeviceId
          WHERE w.customerDeviceId = @Reg AND w.isRegistered = 1 AND d.DeviceLocation = N''MBA996T-loc''
            AND d.SerialNumber = @RegSerial;'),
(N'R8 registered: hiding it is the customer''s choice', NULL, NULL,
 @P + N', @CustomerDevicesIdsToRemove = @RegText',
 NULL, N'SELECT @Ok = COUNT(*) FROM #W WHERE customerDeviceId = @Reg AND isDeleted = 1;'),
(N'R9 another customer''s device cannot be removed', NULL, NULL,
 @P + N', @CustomerDevicesIdsToRemove = @ForeignText', 54202, NULL),
(N'T1 typed: its model may change',
 @P + N', @CustomerSiteId = @Site, @SerialNumber = N''MBA996T-t1'', @Model = N''MBA996T-old''',
 N'DECLARE @Id INT = (SELECT MAX(CustomerDeviceID) FROM dbo.CustomerDevices WHERE SerialNumber = N''MBA996T-t1'');',
 @P + N', @CustomerDeviceId = @Id,
          @Model = N''MBA996T-new''',
 NULL, N'SELECT @Ok = COUNT(*) FROM #W AS w JOIN dbo.CustomerDevices AS d ON d.CustomerDeviceID = w.customerDeviceId
          WHERE d.Model = N''MBA996T-new'';'),
(N'C1 categories: a secondary of another main is refused', NULL,
 N'INSERT dbo.SecondaryCategories (SecondaryCategoryName, MainCategoryId) VALUES (N''MBA996T-sec'', @OtherMain);
   DECLARE @OS INT = SCOPE_IDENTITY();',
 @P + N', @CustomerSiteId = @Site, @SerialNumber = N''MBA996T-c1'', @MainCategoryId = @Main, @SecondaryCategoryId = @OS', 54209, NULL),
(N'C2 categories: a specification of another main is refused', NULL,
 N'INSERT dbo.MeasurementsSpecifications (Name, MainCategoryId) VALUES (N''MBA996T-spec'', @OtherMain);
   DECLARE @OSp INT = SCOPE_IDENTITY();',
 @P + N', @CustomerSiteId = @Site, @SerialNumber = N''MBA996T-c2'', @MainCategoryId = @Main, @SecondaryCategoryId = @Sec,
          @MeasurementsSpecificationId = @OSp', 54209, NULL),
(N'C3 categories: a reference document of another secondary is refused', NULL, NULL,
 @P + N', @CustomerSiteId = @Site, @SerialNumber = N''MBA996T-c3'', @MainCategoryId = @Main, @SecondaryCategoryId = @Sec,
          @SpecificationReferenceId = @OtherRef', 54209, NULL),
(N'C4 categories: a pair with its specification and reference is accepted', NULL, NULL,
 @P + N', @CustomerSiteId = @Site, @SerialNumber = N''MBA996T-c4'', @MainCategoryId = @Main, @SecondaryCategoryId = @Sec,
          @MeasurementsSpecificationId = @Spec, @SpecificationReferenceId = @Ref',
 NULL, N'SELECT @Ok = COUNT(*) FROM #W AS w JOIN dbo.CustomerDevices AS d ON d.CustomerDeviceID = w.customerDeviceId
          WHERE d.MeasurementsSpecificationId = @Spec AND d.SpecificationReferenceId = @Ref;'),
(N'C5 categories: a secondary of the same main its specification is not linked to is refused',
 @P + N', @CustomerSiteId = @Site, @SerialNumber = N''MBA996T-c5'', @MainCategoryId = @Main, @SecondaryCategoryId = @Sec,
          @MeasurementsSpecificationId = @Spec',
 N'DECLARE @Id INT = (SELECT MAX(CustomerDeviceID) FROM dbo.CustomerDevices WHERE SerialNumber = N''MBA996T-c5'');
   INSERT dbo.SecondaryCategories (SecondaryCategoryName, MainCategoryId) VALUES (N''MBA996T-sec5'', @Main);
   DECLARE @OS INT = SCOPE_IDENTITY();',
 @P + N', @CustomerDeviceId = @Id,
          @SecondaryCategoryId = @OS', 54209, NULL);

DECLARE @Params NVARCHAR(MAX) = N'@Me NVARCHAR(100), @Cust INT, @Code NVARCHAR(50), @Site INT, @Contact INT,
        @Reg INT, @RegSerial NVARCHAR(50), @RegBody NVARCHAR(50), @RegText NVARCHAR(20),
        @ForeignSite INT, @ForeignContact INT, @ForeignText NVARCHAR(20),
        @Main INT, @Sec INT, @Spec INT, @Ref INT, @OtherRef INT, @OtherMain INT, @Ok INT OUTPUT';
DECLARE @RegText NVARCHAR(20) = CAST(@Reg AS NVARCHAR(20)), @ForeignText NVARCHAR(20) = CAST(@ForeignDevice AS NVARCHAR(20));

DECLARE @i INT = 1, @Test NVARCHAR(100), @Setup NVARCHAR(MAX), @Pre NVARCHAR(MAX), @Call NVARCHAR(MAX), @ExpectErr INT,
        @Check NVARCHAR(MAX), @Sql NVARCHAR(MAX), @Ok INT, @Err INT, @Msg NVARCHAR(4000), @Stage NVARCHAR(10);

WHILE @i <= (SELECT COUNT(*) FROM @Cases)
BEGIN
    SELECT @Test = Test, @Setup = Setup, @Pre = Pre, @Call = CallSql, @ExpectErr = ExpectErr, @Check = CheckSql
    FROM @Cases WHERE Seq = @i;
    SELECT @Ok = NULL, @Err = NULL, @Msg = NULL, @Stage = NULL;

    IF @Me IS NULL OR @Reg IS NULL OR @Site IS NULL
       OR (CONCAT(@Setup, @Pre, @Call) LIKE N'%@Foreign%' AND (@ForeignSite IS NULL OR @ForeignContact IS NULL OR @ForeignDevice IS NULL))
       OR (CONCAT(@Setup, @Pre, @Call) LIKE N'%@Main%' AND (@Spec IS NULL OR @Ref IS NULL OR @OtherRef IS NULL OR @OtherMain IS NULL))
    BEGIN
        INSERT @Out SELECT @Test, ISNULL(CAST(@ExpectErr AS NVARCHAR(10)), N'written'), N'-', N'SKIP - fixture missing';
        SET @i += 1;
        CONTINUE;
    END

    SET @Sql = CONCAT(N'TRUNCATE TABLE #W; ',
                      IIF(@Setup IS NULL, N'', CONCAT(N'INSERT #W ', @Setup, N'; TRUNCATE TABLE #W; ')),
                      ISNULL(@Pre, N''), N' INSERT #W ', @Call, N'; ',
                      ISNULL(@Check, N''));
    BEGIN TRY
        BEGIN TRAN;
        EXEC sp_executesql @Sql, @Params,
             @Me, @Cust, @Code, @Site, @Contact, @Reg, @RegSerial, @RegBody, @RegText,
             @ForeignSite, @ForeignContact, @ForeignText, @Main, @Sec, @Spec, @Ref, @OtherRef, @OtherMain,
             @Ok OUTPUT;
        IF @@TRANCOUNT > 0 ROLLBACK;
    END TRY
    BEGIN CATCH
        SELECT @Err = ERROR_NUMBER(), @Msg = ERROR_MESSAGE();
        IF @@TRANCOUNT > 0 ROLLBACK;
    END CATCH;

    IF @ExpectErr IS NOT NULL
        INSERT @Out SELECT @Test, CAST(@ExpectErr AS NVARCHAR(10)),
               IIF(@Err IS NULL, N'no error', LEFT(CONCAT(@Err, N' ', @Msg), 120)),
               IIF(@Err = @ExpectErr, N'PASS', N'FAIL');
    ELSE
        INSERT @Out SELECT @Test, N'written',
               IIF(@Err IS NULL, CONCAT(N'check ', ISNULL(@Ok, 0)), LEFT(CONCAT(@Err, N' ', @Msg), 120)),
               IIF(@Err IS NULL AND @Ok >= 1, N'PASS', N'FAIL');
    SET @i += 1;
END;

/* the file leaves no trace */
INSERT @Out SELECT N'Z  no test row left behind', N'0 rows',
       CONCAT((SELECT COUNT(*) FROM dbo.CustomerDevices WHERE SerialNumber LIKE N'MBA996T-%' OR Model LIKE N'MBA996T-%'
                                                         OR DeviceLocation LIKE N'MBA996T-%'), N' rows'),
       IIF(EXISTS (SELECT 1 FROM dbo.CustomerDevices WHERE SerialNumber LIKE N'MBA996T-%' OR Model LIKE N'MBA996T-%'
                                                       OR DeviceLocation LIKE N'MBA996T-%')
           OR EXISTS (SELECT 1 FROM dbo.SecondaryCategories WHERE SecondaryCategoryName LIKE N'MBA996T-%')
           OR EXISTS (SELECT 1 FROM dbo.MeasurementsSpecifications WHERE Name LIKE N'MBA996T-%'), N'FAIL', N'PASS');

SELECT Seq, Test, Expected, Actual, Result FROM @Out ORDER BY Seq;
