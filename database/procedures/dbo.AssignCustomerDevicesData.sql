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
        trimmed (case follows the column collation). Checked under UPDLOCK/HOLDLOCK so two
        simultaneous saves cannot both pass.
      - Portal callers only. The staff path is gone: the staff app has no server-side session
        (SEC-3), so an e-mail it sends proves nothing.
      - @RevertDeletion is gone, for the reason it left AssignCustomerSitesData: it let a customer
        bring back a device MABA staff removed. Adding it again creates a new device.

    Removal is this system's soft delete (IsDeleted), never a row delete.

    OPEN, not decided here (see MBA-996):
      - dbo.GetCustomerDeviceList and dbo.GetCustomerDeviceDetail read OrderDetailsItems only, and
        /customer/devices/[id] is an OrderDetailsItemId. A device written here does not appear in
        either until they also read dbo.CustomerDevices.
      - The clash check looks at dbo.CustomerDevices only, not at serials the customer already has
        through orders (OrderDetailsItems). Whether a device known from an order may be added again
        depends on how the list merges the two.

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

    UpdateUserID is NULL on a portal write: the caller has no dbo.Users row.

    Returns the devices written: customerDeviceId, customerId, serialNumber, isDeleted.
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

        /* The serial the device will have after this call. On an edit NULL keeps the current one,
           and '' would clear it - which is refused like a missing serial on an add. */
        DECLARE @SerialAfter NVARCHAR(50) =
            CASE WHEN @CustomerDeviceId IS NOT NULL AND @SerialNumber IS NULL
                 THEN (SELECT NULLIF(LTRIM(RTRIM(d.SerialNumber)), N'')
                       FROM dbo.CustomerDevices AS d WHERE d.CustomerDeviceID = @CustomerDeviceId)
                 ELSE @Serial END;

        IF @SerialAfter IS NULL
            THROW 54206, 'A serial number is required.', 1;

        BEGIN TRAN;
            /* Inside the transaction, with range locks, so two saves of the same serial cannot both
               pass the check. */
            IF EXISTS (SELECT 1 FROM dbo.CustomerDevices AS d WITH (UPDLOCK, HOLDLOCK)
                       WHERE d.CustomerId = @CustomerId
                         AND d.IsDeleted = 0
                         AND LTRIM(RTRIM(d.SerialNumber)) = @SerialAfter
                         AND d.CustomerDeviceID <> ISNULL(@CustomerDeviceId, -1))
                THROW 54207, 'A device with this serial number already exists for this customer.', 1;

            IF @CustomerDeviceId IS NOT NULL
                UPDATE d
                SET  d.MainCategoryId              = ISNULL(@MainCategoryId,              d.MainCategoryId)
                    ,d.SecondaryCategoryId         = ISNULL(@SecondaryCategoryId,         d.SecondaryCategoryId)
                    ,d.CustomerSiteId              = ISNULL(@CustomerSiteId,              d.CustomerSiteId)
                    ,d.CustomerContactId           = ISNULL(@CustomerContactId,           d.CustomerContactId)
                    ,d.OrdersProductTypeId         = ISNULL(@OrdersProductTypeId,         d.OrdersProductTypeId)
                    ,d.Accuracy                    = ISNULL(@Accuracy,                    d.Accuracy)
                    ,d.OrdersDeviceManufacturer    = IIF(@OrdersDeviceManufacturer IS NULL, d.OrdersDeviceManufacturer, @Manufacturer)
                    ,d.DeviceLocation              = IIF(@DeviceLocation           IS NULL, d.DeviceLocation,           @Location)
                    ,d.LastAdjustmentDate          = ISNULL(@LastAdjustmentDate,          d.LastAdjustmentDate)
                    ,d.Model                       = IIF(@Model                    IS NULL, d.Model,                    @ModelText)
                    ,d.SerialNumber                = @SerialAfter
                    ,d.ManufacturerNumber          = IIF(@ManufacturerNumber       IS NULL, d.ManufacturerNumber,       @ManufacturerNo)
                    ,d.AdditionalDeviceNumber      = IIF(@AdditionalDeviceNumber   IS NULL, d.AdditionalDeviceNumber,   @AdditionalNo)
                    ,d.DateFormatStructure         = IIF(@DateFormatStructure      IS NULL, d.DateFormatStructure,      @DateFormat)
                    ,d.NextCalibrationDate         = ISNULL(@NextCalibrationDate,         d.NextCalibrationDate)
                    ,d.CalibrationIntervalMonths   = ISNULL(@CalibrationIntervalMonths,   d.CalibrationIntervalMonths)
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
                     SecondaryMeasurmentUnitId, CreatedDate, UpdateUserID, IsDeleted)
                OUTPUT inserted.CustomerDeviceID INTO @Written (CustomerDeviceID)
                VALUES
                    (@CustomerId, @MainCategoryId, @SecondaryCategoryId, @CustomerSiteId, @CustomerContactId,
                     @OrdersProductTypeId, @Accuracy, @Manufacturer, @Location,
                     @LastAdjustmentDate, @ModelText, @SerialAfter, @ManufacturerNo, @AdditionalNo,
                     @DateFormat, @NextCalibrationDate, @CalibrationIntervalMonths, @Language,
                     ISNULL(@IsThirdPartyCalibration, 0), ISNULL(@BatteriesReplacement, 0), @Method,
                     @SpecificationReferenceId, @MeasurementsSpecificationId, @PrimaryMeasurmentUnitId,
                     @SecondaryMeasurmentUnitId, GETDATE(), NULL, 0);
        COMMIT;
    END

    SELECT d.CustomerDeviceID AS customerDeviceId,
           d.CustomerId       AS customerId,
           d.SerialNumber     AS serialNumber,
           d.IsDeleted        AS isDeleted
    FROM @Written AS w
    INNER JOIN dbo.CustomerDevices AS d ON d.CustomerDeviceID = w.CustomerDeviceID
    ORDER BY d.CustomerDeviceID;
END
GO
