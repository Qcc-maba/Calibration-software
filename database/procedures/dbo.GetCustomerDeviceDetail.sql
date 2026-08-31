/*
    dbo.GetCustomerDeviceDetail                                        MBA-936
    ---------------------------------------------------------------------------------------------
    Takes an optional @SelectedCustomerId: the branch the caller chose, for a contact whose e-mail
    address serves more than one customer. 3,684 addresses do - davide@iscar.co.il covers 22 ישקר
    sites, sharbaf_o@mac.org.il covers 25 מכבי branches.

    Without it, the customer is resolved as before: the lowest CustomerContactId for that address.
    That is stable but arbitrary, and it can land on a branch holding nothing while another of the
    caller's own branches holds their devices.

    THE ID IS VERIFIED, NOT TRUSTED. It is used only when the caller really is a contact of that
    customer; anything else falls through to the original pick. Passing a customer the caller does
    not serve returns their own data, never the other customer's - checked against a customer with
    71 order lines, which returned nothing.
*/
-- =============================================
-- Proc:        dbo.GetCustomerDeviceDetail
-- Jira:        MBA-798  "Customer Selected-device detail view"
-- Description: Returns the FULL detail of ONE device for the logged-in customer
--              (customer portal "selected device" detail view). This is a distinct
--              contract from:
--                * dbo.GetCustomerDeviceList     -> one row PER device, 12 list columns,
--                                                   no single-device key.
--                * dbo.GetOrderDetailsDevices    -> STAFF detail, keyed by OrderWorkPlanId,
--                                                   requires a MABA Users/UserRoles row via
--                                                   GetSourceFilterByEmail and performs NO
--                                                   customer-ownership check -> unusable and
--                                                   unsafe for a customer contact.
--
--              Identity input matches the other GetCustomer* SPs:
--                @LoggedInUserEmail -> CustomerId via dbo.CustomerContacts.
--              The device is looked up by @OrderDetailsItemId and is ALWAYS re-scoped to the
--              calling customer (WHERE wp.CustomerId = @CustomerId), so a customer can never
--              read another customer's device by guessing an id. Returns 0 rows if the id
--              does not belong to the caller.
--
-- Params:
--   @LoggedInUserEmail  NVARCHAR(50)  -- customer contact email (resolves CustomerId)
--   @OrderDetailsItemId INT           -- the selected device (OrderDetailsItems.OrderDetailsItemId)
--
-- Output (single row): superset of the Device-List contract plus detail-only fields.
--   id, deviceStatus (FE camelCase code), deviceStatusHeb,
--   lastCalibration (DD.MM.YYYY), nextCalibration (DD.MM.YYYY),
--   serialNumber, sku, additionalDeviceNumber,
--   calibrationLocation (מעבדה/לקוח), deviceDescription, deviceManufacturer, deviceModel,
--   mainCategory, secondaryCategory, accuracy, measurementUnit,
--   productLocation, siteAddress, shippingMethod,
--   orderNumber, lastReport,
--   calibratorFullName, calibratorPhone
--
--   * deviceStatus is mapped by StatusId to the exact FE `deviceCalibrationStatuses`
--     camelCase codes, IDENTICAL to dbo.GetCustomerDeviceList (kept in sync on purpose);
--     any unmapped status falls back to lower-camel of StatusDescriptionENG.
--   * Dates -> DD.MM.YYYY (CONVERT style 104), per house convention.
--
-- NOTE for review (Ariel): source mappings mirror dbo.GetCustomerDeviceList (MBA-860) --
--   sku -> ManufacturerNumber, calibrationLocation -> IIF(od.IsInHouse=1,'מעבדה','לקוח'),
--   lastReport -> itm.MbaReportNumber. Please confirm which extra detail fields the final
--   Figma frame requires; those listed above are the customer-safe superset available in
--   Calibrator. No financial/analytics fields are included (not in this DB).
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[GetCustomerDeviceDetail]
    @LoggedInUserEmail  NVARCHAR(50),
    @OrderDetailsItemId INT,
    /* MBA-936: the branch the caller chose, when their address serves several customers.
       Verified below - an unverified id is ignored rather than trusted, so this cannot be
       used to read another customer's data. */
    @SelectedCustomerId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @CustomerId INT = NULL;

        /* MBA-936: honour the chosen branch, but only if this caller really is a contact of it.
       3,684 addresses serve more than one customer; sharbaf_o@mac.org.il covers 25 מכבי branches.
       Without a choice, or with one that does not belong to the caller, this falls through to the
       original deterministic pick - never to the id it was handed. */
    IF @SelectedCustomerId IS NOT NULL
       AND EXISTS (SELECT 1 FROM dbo.CustomerContacts AS v
                   WHERE v.CustomerId = @SelectedCustomerId
                     AND ISNULL(v.IsDeleted, 0) = 0
                     AND LOWER(LTRIM(RTRIM(v.CustomerContactEmail)))
                       = LOWER(LTRIM(RTRIM(@LoggedInUserEmail))))
        SET @CustomerId = @SelectedCustomerId;
    ELSE
    SELECT TOP (1) @CustomerId = cc.CustomerId
        FROM [dbo].[CustomerContacts] AS cc
        WHERE cc.CustomerContactEmail = @LoggedInUserEmail
        ORDER BY cc.CustomerContactId ASC;   /* deterministic pick when the e-mail is duplicated - same rule as GetCustomerPortalContactByEmail */

    IF @CustomerId IS NULL
        RETURN;  -- unknown contact -> no data

    SELECT TOP (1)
         itm.OrderDetailsItemId                                                   AS id
        ,CASE itm.CalibrationStatusId
            WHEN 31 THEN 'testedMetTheStandard'
            WHEN 32 THEN 'testedDidntMeetTheStandards'
            WHEN 23 THEN 'calibrationSuccess'
            WHEN 21 THEN 'calibrationFailed'
            WHEN 26 THEN 'adjusted'
            WHEN 24 THEN 'delivered'
            WHEN 22 THEN 'packaged'
            WHEN 29 THEN 'readyForPacking'
            WHEN 27 THEN 'readyForDelivery'
            WHEN 19 THEN 'waitingForCalibration'
            WHEN 33 THEN 'cannotBeDetermined'
            ELSE CASE
                    WHEN st.StatusDescriptionENG IS NULL OR LEN(st.StatusDescriptionENG) = 0 THEN NULL
                    ELSE LOWER(LEFT(REPLACE(st.StatusDescriptionENG, '''', ''), 1))
                       + SUBSTRING(REPLACE(st.StatusDescriptionENG, '''', ''), 2, 200)
                 END
         END                                                                      AS deviceStatus
        ,st.StatusDescriptionHEB                                                  AS deviceStatusHeb
        ,CONVERT(VARCHAR(10), itm.ActualCalibrationDate, 104)                     AS lastCalibration
        ,CONVERT(VARCHAR(10), itm.NextCalibrationDate,   104)                     AS nextCalibration
        ,itm.SerialNumber                                                         AS serialNumber
        ,itm.ManufacturerNumber                                                   AS sku
        ,itm.AdditionalDeviceNumber                                               AS additionalDeviceNumber
        ,IIF(od.IsInHouse = 1, N'מעבדה', N'לקוח')                                  AS calibrationLocation
        ,pt.OrdersProductTypeName                                                 AS deviceDescription
        ,itm.OrdersDeviceManufacturer                                             AS deviceManufacturer
        ,itm.DeviceModel                                                          AS deviceModel
        ,mc.MainCategoryName                                                      AS mainCategory
        ,sc.SecondaryCategoryName                                                 AS secondaryCategory
        ,itm.Accuracy                                                             AS accuracy
        ,mu.ShortNameHe                                                           AS measurementUnit
        ,itm.ProductLocation                                                      AS productLocation
        ,COALESCE(itm.SiteAddress, cs.CustomerSiteAddress)                        AS siteAddress
        ,wp.ShipTypeDesc                                                          AS shippingMethod
        ,wp.OrderNumber                                                           AS orderNumber
        ,itm.MbaReportNumber                                                      AS lastReport
        ,CONCAT(u.FirstName, ' ', u.LastName)                                     AS calibratorFullName
        ,u.Phone                                                                  AS calibratorPhone
    FROM [dbo].[OrderWorkPlans]        AS wp
    JOIN [dbo].[OrderDetails]          AS od  ON od.OrderWorkPlanId = wp.OrderWorkPlanId
    JOIN [dbo].[OrderDetailsItems]     AS itm ON itm.OrderDetailId  = od.OrderDetailId
    LEFT JOIN [dbo].[Statuses]             AS st ON st.StatusId              = itm.CalibrationStatusId
    LEFT JOIN [dbo].[OrdersProductTypes]   AS pt ON pt.OrdersProductTypeId   = od.OrdersProductTypeId
    LEFT JOIN [dbo].[MainCategories]       AS mc ON mc.ID                    = od.MainCategoryId
    LEFT JOIN [dbo].[SecondaryCategories]  AS sc ON sc.ID                    = od.SecondaryCategoryId
    LEFT JOIN [dbo].[MeasurementDeviceUnits] AS mu ON mu.MeasurementDeviceUnitId = itm.MeasurementUnitId
    LEFT JOIN [dbo].[CustomerSites]        AS cs ON cs.CustomerSiteId        = od.CustomerSiteId
    LEFT JOIN [dbo].[Users]                AS u  ON u.ID                     = od.CalibratorId
    WHERE itm.OrderDetailsItemId    = @OrderDetailsItemId
      AND wp.CustomerId             = @CustomerId          -- ownership guard
      AND wp.IsCancelled           = 0
      AND ISNULL(od.IsDeleted, 0)  = 0
      AND ISNULL(od.IsCancelled, 0) = 0
      AND ISNULL(itm.IsDeleted, 0) = 0
      AND ISNULL(itm.IsCancelled, 0) = 0
    OPTION (RECOMPILE);
END
