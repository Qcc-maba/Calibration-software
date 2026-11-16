/*
    dbo.AssignCustomerDevicesData                                                       MBA-996
    ---------------------------------------------------------------------------------------------
    Adds, edits and removes a customer's own devices (dbo.CustomerDevices) from the portal's
    "add device" form - only devices of the customers the caller is a contact of.

    2026-10-22 - MBA-996: rewritten before its first caller. The previous definition (identical on
    STAGE and PROD, kept in database/_rollback/BOTH.dbo.AssignCustomerDevicesData.before-MBA-996.sql)
    had no caller anywhere - not in the app, not in another database object - and
    dbo.CustomerDevices holds 0 rows on both servers. It had the same faults as the sites and
    contacts procedures had before MBA-627:

      1. The caller was resolved through dbo.GetSourceFilterByEmail (dbo.Users, the staff table).
         Of the active contact addresses, 8 of 22,494 have a Users row on STAGE and 2,034 of
         22,498 on PROD; for every other portal caller @CustomerId was NULL: add failed with 515,
         edit and remove silently matched nothing. And a Users row names at most one customer,
         where a portal address can be a contact of several.
      2. @CustomerSiteId and @CustomerContactId were written unchecked, so a device could point at
         another customer's site or contact.
      3. No serial-number clash check. Two devices with the same serial cannot be told apart on a
         report, which is the one thing a calibration certificate must get right (the rule
         dbo.DuplicateCustomerDevice already enforces).
      4. Nothing was returned, so the portal could not learn the new CustomerDeviceID.
      5. The add branch tested NOT EXISTS (... CustomerDeviceID = @CustomerDeviceId) with a NULL id,
         which is always true.
      6. @IsThirdPartyCalibration and @BatteriesReplacement defaulted to 0, so any edit that did not
         send them reset both flags.

    The rules now:

      - The caller is the SET dbo.GetPortalCustomerIds returns, as for every portal procedure.
      - Add: the device belongs to the customer that owns the chosen site; with no site, to the
        caller's PRIMARY customer (the AssignCustomerSitesData rule). A contact, when given, must be
        a live contact of that same customer.
      - Edit and remove: every id must be a live device of a customer in the set. A changed site or
        contact must belong to the device's own customer - an edit never moves a device between
        customers. Removal is all or nothing, as in AssignCustomerSitesData.
      - Serial number: required, and unique among the live devices of that customer, compared
        trimmed and case-blind (SerialKey), with or without Priority's "<CustomerCode>-" prefix
        (2026-11-15, below). Checked under UPDLOCK/HOLDLOCK so two simultaneous saves cannot both
        pass.
      - Portal callers only. The staff path is gone: the staff app has no server-side session
        (SEC-3), so an e-mail it sends proves nothing.
      - @RevertDeletion is gone, for the reason it left AssignCustomerSitesData: it let a customer
        bring back a device MABA staff removed. Adding it again creates a new device.

    Removal is this system's soft delete (IsDeleted), never a row delete.

    2026-11-15 - MBA-996 phase 3: the device entity (DBA/schema-updates.md section 2).
      - dbo.CustomerDevices now also holds every registered device, loaded from Priority's register
        (SERN IS NOT NULL), and the list and detail read it - so a device saved here appears at once.
      - A registered device's Priority-owned fields change only in Priority (decided 2026-11-10,
        section 2 point 2): an edit that would change its serial number, model, manufacturer, device
        type (OrdersProductTypeId), calibration interval or next calibration date is refused with
        54208. Sending the value it already has is accepted, and those columns are never written on
        a registered row - the trigger trCustomerDevices_PriorityOwned is the backstop. Site,
        contact, location, language, categories, specification and units stay the customer's.
      - The serial clash check covers both kinds of row, and Priority's form of the serial:
        Priority stores a device as <CustomerCode>-<serial>, so "ABC" typed by customer 50667 clashes
        with its registered "50667-ABC", and "50667-ABC" typed clashes with a typed "ABC". Devices
        the customer hid or Priority cancelled do not clash.
      - Categories, specification and reference document must fit together the way the form's
        pickers offer them (54209): the secondary category belongs to the main one, the specification
        to the main category and is linked to the secondary one, the reference document to the
        secondary one. Checked only when one of the four is sent, on the values the device will have.
      - Returns isRegistered as well.

    PARAMETERS
    ----------
    @CustomerDevicesIdsToRemove comma-separated CustomerDeviceID list. When given, the call only
                                removes; every other parameter is ignored.
    @CustomerDeviceId           edit that (live) device. NULL with no removal list = add.
    Every other field: NULL keeps the current value on an edit. Text is trimmed, and '' clears it
    - except SerialNumber, which cannot be cleared.

    Refusals, all before anything is written:
      54201  the address is not a portal contact
      54202  a removal id is not a device of the caller (or not a number)
      54203  @CustomerDeviceId is not a live device of the caller
      54204  @CustomerSiteId is not a live site of the caller (on edit: of the device's customer)
      54205  @CustomerContactId is not a live contact of that same customer
      54206  no serial number
      54207  the serial number is already used by another live device of that customer
      54208  the edit would change a field Priority owns on a registered device
      54209  the categories, specification and reference document do not fit together

    UpdateUserID is NULL on a portal write: the caller has no dbo.Users row.

    Returns the devices written: customerDeviceId, customerId, serialNumber, isDeleted, isRegistered.
*/
CREATE OR ALTER PROCEDURE [dbo].[AssignCustomerDevicesData]
    @LoggedInUserEmail           NVARCHAR(100),
    @CustomerDevicesIdsToRemove  NVARCHAR(400) = NULL,
    -- Identification & Location
    @MainCategoryId              INT           = NULL,
    @SecondaryCategoryId         INT           = NULL,
    @CustomerSiteId              INT           = NULL,
    @CustomerContactId           INT           = NULL,
    -- Type & Manufacturer
    @OrdersProductTypeId         INT           = NULL,
    @Accuracy                    TINYINT       = NULL,
    @OrdersDeviceManufacturer    NVARCHAR(100) = NULL,
    @DeviceLocation              NVARCHAR(50)  = NULL,
    @LastAdjustmentDate          DATETIME2(0)  = NULL,
    -- Technical Details
    @Model                       NVARCHAR(150) = NULL,
    @SerialNumber                NVARCHAR(50)  = NULL,
    @ManufacturerNumber          NVARCHAR(100) = NULL,
    @AdditionalDeviceNumber      NVARCHAR(100) = NULL,
    @DateFormatStructure         NVARCHAR(20)  = NULL,
    @NextCalibrationDate         DATETIME2(0)  = NULL,
    @CalibrationIntervalMonths   TINYINT       = NULL,
    @ReportLanguage              NVARCHAR(50)  = NULL,
    -- Methodology & Specs
    @IsThirdPartyCalibration     BIT           = NULL,
    @BatteriesReplacement        BIT           = NULL,
    @CalibrationMethod           NVARCHAR(100) = NULL,
    @SpecificationReferenceId    INT           = NULL,
    @MeasurementsSpecificationId INT           = NULL,
    @PrimaryMeasurmentUnitId     INT           = NULL,
    @SecondaryMeasurmentUnitId   INT           = NULL,

    @CustomerDeviceId            INT           = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Email NVARCHAR(100) = LOWER(LTRIM(RTRIM(@LoggedInUserEmail)));

    SELECT m.CustomerId, m.IsPrimary
    INTO #Mine
    FROM dbo.GetPortalCustomerIds(@Email) AS m;

    IF NOT EXISTS (SELECT 1 FROM #Mine)
        THROW 54201, 'The address does not belong to any customer contact.', 1;

    DECLARE @Written TABLE (CustomerDeviceID INT PRIMARY KEY);

    /* Trimmed, '' -> NULL. The raw parameter still tells "not sent" (NULL) from "cleared" ('')
       on an edit - see the header. */
    DECLARE @Manufacturer       NVARCHAR(100) = NULLIF(LTRIM(RTRIM(@OrdersDeviceManufacturer)), N''),
            @Location           NVARCHAR(50)  = NULLIF(LTRIM(RTRIM(@DeviceLocation)), N''),
            @ModelText          NVARCHAR(150) = NULLIF(LTRIM(RTRIM(@Model)), N''),
            @Serial             NVARCHAR(50)  = NULLIF(LTRIM(RTRIM(@SerialNumber)), N''),
            @ManufacturerNo     NVARCHAR(100) = NULLIF(LTRIM(RTRIM(@ManufacturerNumber)), N''),
            @AdditionalNo       NVARCHAR(100) = NULLIF(LTRIM(RTRIM(@AdditionalDeviceNumber)), N''),
            @DateFormat         NVARCHAR(20)  = NULLIF(LTRIM(RTRIM(@DateFormatStructure)), N''),
            @Language           NVARCHAR(50)  = NULLIF(LTRIM(RTRIM(@ReportLanguage)), N''),
            @Method             NVARCHAR(100) = NULLIF(LTRIM(RTRIM(@CalibrationMethod)), N'');

    /* ---- Remove ------------------------------------------------------------------------- */
    IF @CustomerDevicesIdsToRemove IS NOT NULL
    BEGIN
        /* Keep every non-blank entry, numeric or not, so a junk entry is refused below instead of
           silently dropped. STRING_SPLIT('', ',') yields one empty string (the MBA-902 trap). */
        DECLARE @Requested TABLE (Value NVARCHAR(400) NOT NULL);
        INSERT INTO @Requested (Value)
        SELECT DISTINCT LTRIM(RTRIM(value))
        FROM STRING_SPLIT(@CustomerDevicesIdsToRemove, ',')
        WHERE LTRIM(RTRIM(value)) <> N'';

        IF NOT EXISTS (SELECT 1 FROM @Requested)
           OR EXISTS (SELECT 1 FROM @Requested AS r
                      WHERE r.Value LIKE N'%[^0-9]%' OR LEN(r.Value) > 9
                         OR NOT EXISTS (SELECT 1 FROM dbo.CustomerDevices AS d
                                        INNER JOIN #Mine AS m ON m.CustomerId = d.CustomerId
                                        WHERE d.CustomerDeviceID = TRY_CAST(r.Value AS INT)))
            THROW 54202, 'A device to remove does not belong to the caller.', 1;

        BEGIN TRAN;
            UPDATE d
            SET  d.IsDeleted    = 1
                ,d.UpdatedDate  = GETDATE()
                ,d.UpdateUserID = NULL
            OUTPUT inserted.CustomerDeviceID INTO @Written (CustomerDeviceID)
            FROM dbo.CustomerDevices AS d
            INNER JOIN #Mine AS m ON m.CustomerId = d.CustomerId
            INNER JOIN @Requested AS r ON d.CustomerDeviceID = TRY_CAST(r.Value AS INT)
            WHERE d.IsDeleted = 0;   /* already removed: accepted above, nothing to change */
        COMMIT;
    END
    ELSE
    BEGIN
        /* Add and edit share the ownership and serial checks; they differ only in which customer
           the device belongs to and which device the clash check ignores. */
        DECLARE @CustomerId INT;

        IF @CustomerDeviceId IS NOT NULL
        BEGIN
            SELECT @CustomerId = d.CustomerId
            FROM dbo.CustomerDevices AS d
            INNER JOIN #Mine AS m ON m.CustomerId = d.CustomerId
            WHERE d.CustomerDeviceID = @CustomerDeviceId
              AND d.IsDeleted = 0;

            IF @CustomerId IS NULL
                THROW 54203, 'The device does not belong to the caller, or was removed.', 1;
        END
        ELSE IF @CustomerSiteId IS NOT NULL
            /* A new device goes to the customer that owns the chosen site. */
            SELECT @CustomerId = cs.CustomerId
            FROM dbo.CustomerSites AS cs
            INNER JOIN #Mine AS m ON m.CustomerId = cs.CustomerId
            WHERE cs.CustomerSiteId = @CustomerSiteId
              AND ISNULL(cs.IsDeleted, 0) = 0;
        ELSE
            SELECT TOP (1) @CustomerId = m.CustomerId
            FROM #Mine AS m
            ORDER BY m.IsPrimary DESC, m.CustomerId;

        IF @CustomerSiteId IS NOT NULL
           AND NOT EXISTS (SELECT 1 FROM dbo.CustomerSites AS cs
                           WHERE cs.CustomerSiteId = @CustomerSiteId
                             AND cs.CustomerId = @CustomerId
                             AND ISNULL(cs.IsDeleted, 0) = 0)
            THROW 54204, 'The site does not belong to the customer of this device.', 1;

        IF @CustomerContactId IS NOT NULL
           AND NOT EXISTS (SELECT 1 FROM dbo.CustomerContacts AS cc
                           WHERE cc.CustomerContactId = @CustomerContactId
                             AND cc.CustomerId = @CustomerId
                             AND cc.IsDeleted = 0
                             AND cc.IsActive = 1)
            THROW 54205, 'The contact does not belong to the customer of this device.', 1;

        /* The device as it is now (an edit), for the Priority-owned and the fit-together checks. */
        DECLARE @Sern INT, @CurSerial NVARCHAR(50), @CurModel NVARCHAR(150), @CurManufacturer NVARCHAR(100),
                @CurProductType INT, @CurInterval TINYINT, @CurNextDate DATETIME2(0),
                @CurMain INT, @CurSecondary INT, @CurSpec INT, @CurReference INT;

        IF @CustomerDeviceId IS NOT NULL
            SELECT @Sern = d.SERN,
                   @CurSerial = NULLIF(LTRIM(RTRIM(d.SerialNumber)), N''),
                   @CurModel = NULLIF(LTRIM(RTRIM(d.Model)), N''),
                   @CurManufacturer = NULLIF(LTRIM(RTRIM(d.OrdersDeviceManufacturer)), N''),
                   @CurProductType = d.OrdersProductTypeId, @CurInterval = d.CalibrationIntervalMonths,
                   @CurNextDate = d.NextCalibrationDate,
                   @CurMain = d.MainCategoryId, @CurSecondary = d.SecondaryCategoryId,
                   @CurSpec = d.MeasurementsSpecificationId, @CurReference = d.SpecificationReferenceId
            FROM dbo.CustomerDevices AS d
            WHERE d.CustomerDeviceID = @CustomerDeviceId;

        /* What the list and detail SHOW for a registered device, which is not always the row's own
           value: model and manufacturer fall back to the latest visit (Priority's placeholders '-/-'
           and '0' count as empty), and the device type and next calibration date come from the latest
           visit only. The form may send back what it displayed, and the contract says an unchanged
           value is fine (review of PR #60, r4588792083). */
        DECLARE @ShownModel NVARCHAR(150), @ShownManufacturer NVARCHAR(100), @ShownProductType INT,
                @ShownNextDate DATETIME2(0);

        IF @Sern IS NOT NULL
            SELECT @ShownModel        = COALESCE(NULLIF(NULLIF(NULLIF(LTRIM(RTRIM(v.Model)), N''), N'-/-'), N'0'),
                                                 NULLIF(LTRIM(RTRIM(li.DeviceModel)), N'')),
                   @ShownManufacturer = COALESCE(NULLIF(NULLIF(NULLIF(LTRIM(RTRIM(v.OrdersDeviceManufacturer)), N''), N'-/-'), N'0'),
                                                 NULLIF(LTRIM(RTRIM(li.OrdersDeviceManufacturer)), N'')),
                   @ShownProductType  = od.OrdersProductTypeId,
                   @ShownNextDate     = v.NextCalibrationDate
            FROM dbo.vwCustomerDevices AS v
            LEFT JOIN dbo.OrderDetailsItems AS li ON li.OrderDetailsItemId = v.LatestOrderDetailsItemId
            LEFT JOIN dbo.OrderDetails      AS od ON od.OrderDetailId      = li.OrderDetailId
            WHERE v.CustomerDeviceID = @CustomerDeviceId;

        /* A registered device: what Priority owns may be sent back unchanged - as stored or as shown -
           never changed. NULL means "not sent"; '' on a text field means "clear", which is a change. */
        IF @Sern IS NOT NULL
           AND (   (@SerialNumber IS NOT NULL             AND ISNULL(@Serial, N'')       <> ISNULL(@CurSerial, N''))
                OR (@Model IS NOT NULL                    AND ISNULL(@ModelText, N'')    <> ISNULL(@CurModel, N'')
                                                          AND ISNULL(@ModelText, N'')    <> ISNULL(@ShownModel, N''))
                OR (@OrdersDeviceManufacturer IS NOT NULL AND ISNULL(@Manufacturer, N'') <> ISNULL(@CurManufacturer, N'')
                                                          AND ISNULL(@Manufacturer, N'') <> ISNULL(@ShownManufacturer, N''))
                OR (@OrdersProductTypeId IS NOT NULL      AND @OrdersProductTypeId       <> ISNULL(@CurProductType, -1)
                                                          AND @OrdersProductTypeId       <> ISNULL(@ShownProductType, -1))
                OR (@CalibrationIntervalMonths IS NOT NULL AND @CalibrationIntervalMonths <> ISNULL(@CurInterval, 0))
                OR (@NextCalibrationDate IS NOT NULL      AND CAST(@NextCalibrationDate AS DATE) <> ISNULL(CAST(@CurNextDate AS DATE), '19000101')
                                                          AND CAST(@NextCalibrationDate AS DATE) <> ISNULL(CAST(@ShownNextDate AS DATE), '19000101')))
            THROW 54208, 'This field is managed by MABA: a registered device changes only in Priority.', 1;

        /* Categories, specification and reference document fit together the way the form's pickers
           offer them, on the values the device will have. Only when one of them is sent, so an edit
           of anything else is never refused for what an older row already holds. */
        IF COALESCE(@MainCategoryId, @SecondaryCategoryId, @MeasurementsSpecificationId, @SpecificationReferenceId) IS NOT NULL
        BEGIN
            DECLARE @MainAfter      INT = COALESCE(@MainCategoryId, @CurMain),
                    @SecondaryAfter INT = COALESCE(@SecondaryCategoryId, @CurSecondary),
                    @SpecAfter      INT = COALESCE(@MeasurementsSpecificationId, @CurSpec),
                    @ReferenceAfter INT = COALESCE(@SpecificationReferenceId, @CurReference);

            IF (@SecondaryAfter IS NOT NULL
                AND NOT EXISTS (SELECT 1 FROM dbo.SecondaryCategories AS sc
                                WHERE sc.ID = @SecondaryAfter AND sc.IsDeleted = 0
                                  AND (@MainAfter IS NULL OR sc.MainCategoryId = @MainAfter)))
               OR (@SpecAfter IS NOT NULL
                   AND NOT EXISTS (SELECT 1 FROM dbo.MeasurementsSpecifications AS ms
                                   WHERE ms.ID = @SpecAfter AND ms.IsDeleted = 0
                                     AND (@MainAfter IS NULL OR ms.MainCategoryId = @MainAfter)
                                     AND (@SecondaryAfter IS NULL
                                          OR EXISTS (SELECT 1 FROM dbo.MeasurementsSpecificationsToSecondCategory AS l
                                                     WHERE l.MeasurementsSpecificationId = ms.ID
                                                       AND l.SecondaryCategoryId = @SecondaryAfter
                                                       AND l.IsDeleted = 0))))
               OR (@ReferenceAfter IS NOT NULL
                   AND NOT EXISTS (SELECT 1 FROM dbo.SpecificationReference AS sr
                                   WHERE sr.ID = @ReferenceAfter AND sr.IsDeleted = 0
                                     AND (@SecondaryAfter IS NULL OR sr.SecondaryCategoryId = @SecondaryAfter)))
                THROW 54209, 'The categories, specification and reference document do not fit together.', 1;
        END

        /* The serial the device will have after this call. On an edit NULL keeps the current one,
           and '' would clear it - which is refused like a missing serial on an add. */
        DECLARE @SerialAfter NVARCHAR(50) =
            CASE WHEN @CustomerDeviceId IS NOT NULL AND @SerialNumber IS NULL THEN @CurSerial
                 ELSE @Serial END;

        /* The serial rules apply to a serial being set: an add, or an edit that changes it. An edit of
           anything else must not be refused for what the row already is - Priority holds a few
           devices registered twice under one serial, and a registered serial may be blank (review of
           PR #60, r4588791809). */
        DECLARE @SerialChanges BIT =
            CASE WHEN @CustomerDeviceId IS NULL THEN 1
                 WHEN @SerialNumber IS NULL THEN 0
                 WHEN ISNULL(@Serial, N'') = ISNULL(@CurSerial, N'') THEN 0
                 ELSE 1 END;

        IF @SerialChanges = 1 AND @SerialAfter IS NULL
            THROW 54206, 'A serial number is required.', 1;

        /* Priority stores a device as <CustomerCode>-<serial>. Compare without that prefix on both
           sides: the clash check looks for the bare serial and for the prefixed one. */
        DECLARE @Code NVARCHAR(50) = (SELECT NULLIF(LTRIM(RTRIM(c.CustomerCode)), N'')
                                      FROM dbo.Customers AS c WHERE c.CustomerId = @CustomerId);
        DECLARE @Body NVARCHAR(50) =
            CASE WHEN @Code IS NOT NULL AND UPPER(@SerialAfter) LIKE UPPER(@Code) + N'-_%'
                 THEN SUBSTRING(@SerialAfter, LEN(@Code) + 2, 50) ELSE @SerialAfter END;
        DECLARE @KeyBare     NVARCHAR(50) = UPPER(LTRIM(RTRIM(@Body))),
                @KeyPrefixed NVARCHAR(50) = CASE WHEN @Code IS NULL THEN NULL
                                                 ELSE LEFT(UPPER(@Code + N'-' + LTRIM(RTRIM(@Body))), 50) END;

        BEGIN TRAN;
            /* Inside the transaction, with range locks, so two saves of the same serial cannot both
               pass the check. */
            IF @SerialChanges = 1
               AND EXISTS (SELECT 1 FROM dbo.CustomerDevices AS d WITH (UPDLOCK, HOLDLOCK)
                       WHERE d.CustomerId = @CustomerId
                         AND d.IsDeleted = 0
                         AND d.IsInactiveInSource = 0
                         AND (d.SerialKey = @KeyBare OR d.SerialKey = @KeyPrefixed)
                         AND d.CustomerDeviceID <> ISNULL(@CustomerDeviceId, -1))
                THROW 54207, 'A device with this serial number already exists for this customer.', 1;

            IF @CustomerDeviceId IS NOT NULL
                UPDATE d
                SET  d.MainCategoryId              = ISNULL(@MainCategoryId,              d.MainCategoryId)
                    ,d.SecondaryCategoryId         = ISNULL(@SecondaryCategoryId,         d.SecondaryCategoryId)
                    ,d.CustomerSiteId              = ISNULL(@CustomerSiteId,              d.CustomerSiteId)
                    ,d.CustomerContactId           = ISNULL(@CustomerContactId,           d.CustomerContactId)
                    /* Priority-owned on a registered row (SERN IS NOT NULL): kept as they are. An
                       unchanged value passed 54208 above; writing it back could still differ in
                       case or spacing, which only the refresh may do. */
                    ,d.OrdersProductTypeId         = IIF(d.SERN IS NOT NULL, d.OrdersProductTypeId,
                                                         ISNULL(@OrdersProductTypeId, d.OrdersProductTypeId))
                    ,d.Accuracy                    = ISNULL(@Accuracy,                    d.Accuracy)
                    ,d.OrdersDeviceManufacturer    = IIF(d.SERN IS NOT NULL OR @OrdersDeviceManufacturer IS NULL,
                                                         d.OrdersDeviceManufacturer, @Manufacturer)
                    ,d.DeviceLocation              = IIF(@DeviceLocation           IS NULL, d.DeviceLocation,           @Location)
                    ,d.LastAdjustmentDate          = ISNULL(@LastAdjustmentDate,          d.LastAdjustmentDate)
                    ,d.Model                       = IIF(d.SERN IS NOT NULL OR @Model IS NULL, d.Model, @ModelText)
                    ,d.SerialNumber                = IIF(d.SERN IS NOT NULL, d.SerialNumber, @SerialAfter)
                    ,d.ManufacturerNumber          = IIF(@ManufacturerNumber       IS NULL, d.ManufacturerNumber,       @ManufacturerNo)
                    ,d.AdditionalDeviceNumber      = IIF(@AdditionalDeviceNumber   IS NULL, d.AdditionalDeviceNumber,   @AdditionalNo)
                    ,d.DateFormatStructure         = IIF(@DateFormatStructure      IS NULL, d.DateFormatStructure,      @DateFormat)
                    ,d.NextCalibrationDate         = IIF(d.SERN IS NOT NULL, d.NextCalibrationDate,
                                                         ISNULL(@NextCalibrationDate, d.NextCalibrationDate))
                    ,d.CalibrationIntervalMonths   = IIF(d.SERN IS NOT NULL, d.CalibrationIntervalMonths,
                                                         ISNULL(@CalibrationIntervalMonths, d.CalibrationIntervalMonths))
                    ,d.ReportLanguage              = IIF(@ReportLanguage           IS NULL, d.ReportLanguage,           @Language)
                    ,d.IsThirdPartyCalibration     = ISNULL(@IsThirdPartyCalibration,     d.IsThirdPartyCalibration)
                    ,d.BatteriesReplacement        = ISNULL(@BatteriesReplacement,        d.BatteriesReplacement)
                    ,d.CalibrationMethod           = IIF(@CalibrationMethod        IS NULL, d.CalibrationMethod,        @Method)
                    ,d.SpecificationReferenceId    = ISNULL(@SpecificationReferenceId,    d.SpecificationReferenceId)
                    ,d.MeasurementsSpecificationId = ISNULL(@MeasurementsSpecificationId, d.MeasurementsSpecificationId)
                    ,d.PrimaryMeasurmentUnitId     = ISNULL(@PrimaryMeasurmentUnitId,     d.PrimaryMeasurmentUnitId)
                    ,d.SecondaryMeasurmentUnitId   = ISNULL(@SecondaryMeasurmentUnitId,   d.SecondaryMeasurmentUnitId)
                    ,d.UpdatedDate                 = GETDATE()
                    ,d.UpdateUserID                = NULL
                OUTPUT inserted.CustomerDeviceID INTO @Written (CustomerDeviceID)
                FROM dbo.CustomerDevices AS d
                WHERE d.CustomerDeviceID = @CustomerDeviceId
                  AND d.CustomerId = @CustomerId
                  AND d.IsDeleted = 0;
            ELSE
                INSERT INTO dbo.CustomerDevices
                    (CustomerId, MainCategoryId, SecondaryCategoryId, CustomerSiteId, CustomerContactId,
                     OrdersProductTypeId, Accuracy, OrdersDeviceManufacturer, DeviceLocation,
                     LastAdjustmentDate, Model, SerialNumber, ManufacturerNumber, AdditionalDeviceNumber,
                     DateFormatStructure, NextCalibrationDate, CalibrationIntervalMonths, ReportLanguage,
                     IsThirdPartyCalibration, BatteriesReplacement, CalibrationMethod,
                     SpecificationReferenceId, MeasurementsSpecificationId, PrimaryMeasurmentUnitId,
                     SecondaryMeasurmentUnitId, CreatedDate, UpdateUserID, IsDeleted, AddedInPortal)
                OUTPUT inserted.CustomerDeviceID INTO @Written (CustomerDeviceID)
                VALUES
                    (@CustomerId, @MainCategoryId, @SecondaryCategoryId, @CustomerSiteId, @CustomerContactId,
                     @OrdersProductTypeId, @Accuracy, @Manufacturer, @Location,
                     @LastAdjustmentDate, @ModelText, @SerialAfter, @ManufacturerNo, @AdditionalNo,
                     @DateFormat, @NextCalibrationDate, @CalibrationIntervalMonths, @Language,
                     ISNULL(@IsThirdPartyCalibration, 0), ISNULL(@BatteriesReplacement, 0), @Method,
                     @SpecificationReferenceId, @MeasurementsSpecificationId, @PrimaryMeasurmentUnitId,
                     @SecondaryMeasurmentUnitId, GETDATE(), NULL, 0,
                     1);   /* the view keeps showing it once Priority registers it */
        COMMIT;
    END

    SELECT d.CustomerDeviceID AS customerDeviceId,
           d.CustomerId       AS customerId,
           d.SerialNumber     AS serialNumber,
           d.IsDeleted        AS isDeleted,
           CAST(CASE WHEN d.SERN IS NOT NULL THEN 1 ELSE 0 END AS BIT) AS isRegistered
    FROM @Written AS w
    INNER JOIN dbo.CustomerDevices AS d ON d.CustomerDeviceID = w.CustomerDeviceID
    ORDER BY d.CustomerDeviceID;
END
GO
