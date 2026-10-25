/*
    dbo.DuplicateCustomerDevice                                                         MBA-903
    ---------------------------------------------------------------------------------------------
    Copies a customer device, for the "שכפול מכשיר" action in the portal's device menu.

    A customer who owns forty identical thermometers should enter one and copy it thirty-nine
    times, changing only the serial number. Today there is no procedure for it, so the action has
    nowhere to write.

    Everything descriptive is copied - category, manufacturer, model, accuracy, units,
    specification, calibration interval, report language. The things that identify one physical
    instrument are NOT: SerialNumber, ManufacturerNumber and AdditionalDeviceNumber come from the
    caller, and the calibration history does not follow, because the copy has never been
    calibrated. LastAdjustmentDate and NextCalibrationDate are deliberately left for the caller
    rather than inherited: a copy inheriting the original's next-calibration date would silently
    tell the customer a brand new device is already due.

    Ownership is enforced: the source device must belong to the calling customer.

    A serial number that already exists for this customer is refused. Two devices with the same
    serial cannot be told apart on a report, which is the one thing a calibration certificate must
    get right.

    @Copies makes several at once for the bulk case. Serial numbers must then be supplied as a
    comma-separated list of the same length, since only the customer knows them.

    2026-09-30 - MBA-903: ownership against the caller's customer SET.
    ---------------------------------------------------------------------------------------------
    The caller was resolved with SELECT TOP (1) ... ORDER BY CustomerContactId, the rule MBA-943
    removed from every read screen. A contact of several customers could copy only devices of the
    lowest-id one, which is often a customer holding no devices at all - 236 addresses on STAGE.
    The source device now has to belong to a customer in dbo.GetPortalCustomerIds, and the copy,
    the serial-number clash check and the result all use THAT device's customer: a copy stays with
    the customer that owns the original.

    @CustomerSiteId, when given, must be a live site of that same customer (52025). It used to be
    written unchecked, which let a copy point at another customer's site.

    It also never ran: #Serials had tempdb's collation and every call died on a collation conflict
    against CustomerDevices.SerialNumber. Found by database/tests/Test-CustomerPortalRequest.sql.
*/
CREATE OR ALTER PROCEDURE dbo.DuplicateCustomerDevice
    @LoggedInUserEmail    NVARCHAR(100),
    @CustomerDeviceId     INT,
    @SerialNumbers        NVARCHAR(MAX),        /* one per copy, comma separated */
    @DeviceLocation       NVARCHAR(200) = NULL,
    @CustomerSiteId       INT           = NULL,
    @NextCalibrationDate  DATE          = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Email NVARCHAR(100) = LOWER(LTRIM(RTRIM(@LoggedInUserEmail)));
    DECLARE @CustomerId INT;

    IF NOT EXISTS (SELECT 1 FROM dbo.GetPortalCustomerIds(@Email))
        THROW 52021, 'The calling address does not belong to any customer contact.', 1;

    /* The customer that owns the source device - provided it is one of the caller's. */
    SELECT @CustomerId = d.CustomerId
    FROM dbo.CustomerDevices AS d
    INNER JOIN dbo.GetPortalCustomerIds(@Email) AS mine ON mine.CustomerId = d.CustomerId
    WHERE d.CustomerDeviceID = @CustomerDeviceId
      AND d.IsDeleted = 0;

    IF @CustomerId IS NULL
        THROW 52022, 'The device to copy does not belong to the caller.', 1;

    IF @CustomerSiteId IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM dbo.CustomerSites AS cs
                       WHERE cs.CustomerSiteId = @CustomerSiteId
                         AND cs.CustomerId = @CustomerId
                         AND ISNULL(cs.IsDeleted, 0) = 0)
        THROW 52025, 'The site does not belong to the customer that owns the device.', 1;

    /* Blanks dropped rather than becoming empty serials - same care as MBA-902.
       COLLATE DATABASE_DEFAULT: a temp table takes tempdb's collation (Latin1_General), and the
       clash check and the final SELECT compare it with CustomerDevices.SerialNumber (Hebrew_CI_AS).
       Without it every call failed with a collation conflict - unnoticed because CustomerDevices
       is empty on STAGE, so nothing had ever been copied. */
    CREATE TABLE #Serials (SerialNumber NVARCHAR(100) COLLATE DATABASE_DEFAULT PRIMARY KEY);

    INSERT INTO #Serials (SerialNumber)
    SELECT DISTINCT LTRIM(RTRIM(value))
    FROM STRING_SPLIT(ISNULL(@SerialNumbers, N''), ',')
    WHERE LTRIM(RTRIM(value)) <> N'';

    IF NOT EXISTS (SELECT 1 FROM #Serials)
        THROW 52023, 'At least one serial number is required.', 1;

    DECLARE @Clash NVARCHAR(100);
    SELECT TOP (1) @Clash = s.SerialNumber
    FROM #Serials AS s
    WHERE EXISTS (SELECT 1 FROM dbo.CustomerDevices AS d
                  WHERE d.CustomerId = @CustomerId
                    AND d.IsDeleted = 0
                    AND LTRIM(RTRIM(d.SerialNumber)) = s.SerialNumber);

    IF @Clash IS NOT NULL
        THROW 52024, 'A device with one of these serial numbers already exists for this customer.', 1;

    INSERT INTO dbo.CustomerDevices
        (CustomerId, MainCategoryId, SecondaryCategoryId, CustomerSiteId, CustomerContactId,
         OrdersProductTypeId, Accuracy, OrdersDeviceManufacturer, DeviceLocation, Model,
         SerialNumber, ManufacturerNumber, AdditionalDeviceNumber, DateFormatStructure,
         NextCalibrationDate, CalibrationIntervalMonths, ReportLanguage, IsThirdPartyCalibration,
         BatteriesReplacement, CalibrationMethod, SpecificationReferenceId,
         MeasurementsSpecificationId, PrimaryMeasurmentUnitId, SecondaryMeasurmentUnitId,
         GuardBand, CreatedDate, IsDeleted)
    SELECT
         src.CustomerId, src.MainCategoryId, src.SecondaryCategoryId,
         COALESCE(@CustomerSiteId, src.CustomerSiteId), src.CustomerContactId,
         src.OrdersProductTypeId, src.Accuracy, src.OrdersDeviceManufacturer,
         COALESCE(@DeviceLocation, src.DeviceLocation), src.Model,
         s.SerialNumber,
         NULL,                      /* ManufacturerNumber identifies one instrument */
         NULL,                      /* AdditionalDeviceNumber likewise */
         src.DateFormatStructure,
         @NextCalibrationDate,      /* never inherited - see the header */
         src.CalibrationIntervalMonths, src.ReportLanguage, src.IsThirdPartyCalibration,
         src.BatteriesReplacement, src.CalibrationMethod, src.SpecificationReferenceId,
         src.MeasurementsSpecificationId, src.PrimaryMeasurmentUnitId, src.SecondaryMeasurmentUnitId,
         src.GuardBand, GETDATE(), 0
    FROM dbo.CustomerDevices AS src
    CROSS JOIN #Serials AS s
    WHERE src.CustomerDeviceID = @CustomerDeviceId;

    SELECT d.CustomerDeviceID AS customerDeviceId, d.SerialNumber AS serialNumber
    FROM dbo.CustomerDevices AS d
    INNER JOIN #Serials AS s ON s.SerialNumber = d.SerialNumber
    WHERE d.CustomerId = @CustomerId AND d.IsDeleted = 0;
END
