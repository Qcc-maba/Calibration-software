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

    DECLARE @CustomerId INT, @UserId INT;

    SELECT TOP (1) @CustomerId = cc.CustomerId
    FROM dbo.CustomerContacts AS cc
    WHERE cc.IsDeleted = 0
      AND LOWER(LTRIM(RTRIM(cc.CustomerContactEmail))) = LOWER(LTRIM(RTRIM(@LoggedInUserEmail)))
    ORDER BY cc.CustomerContactId ASC;

    IF @CustomerId IS NULL
        THROW 52021, 'The calling address does not belong to any customer contact.', 1;

    IF NOT EXISTS (SELECT 1 FROM dbo.CustomerDevices AS d
                   WHERE d.CustomerDeviceID = @CustomerDeviceId
                     AND d.CustomerId = @CustomerId
                     AND d.IsDeleted = 0)
        THROW 52022, 'The device to copy does not belong to the caller.', 1;

    /* Blanks dropped rather than becoming empty serials - same care as MBA-902. */
    CREATE TABLE #Serials (SerialNumber NVARCHAR(100) PRIMARY KEY);

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
