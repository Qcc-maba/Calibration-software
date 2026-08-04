-- =============================================
-- Proc:        dbo.GetCustomerShipments
-- Jira:        MBA-795 ("Customer Shipping page (customer/shipping)")
-- Description: Returns the shipments / deliveries belonging to the logged-in customer
--              for the customer portal Shipping screen (route: /customer/shipping).
--              One row per shipped/shippable order item. Identity input matches the
--              other GetCustomer* SPs (@LoggedInUserEmail -> CustomerId via
--              dbo.CustomerContacts) and the result is scoped to that customer only.
--
--              Filtering / sorting / search are expected client-side (consistent with
--              MBA-860 GetCustomerDeviceList), so this SP returns the full clean set
--              with no pagination.
--
-- Output columns (order):
--   id, orderNumber, mbaReportNumber, serialNumber, deviceDescription,
--   deviceManufacturer, deviceModel, shippingMethod, shippingDoc, shippingAddress,
--   receivingDate, calibrationDate, expectedReturnDate, deliveryDate, status
--
--   * status       -> ORDER-level status (wp.OrderOverallStatusId -> dbo.Statuses),
--                     returned as a lower-camel code of StatusDescriptionENG
--                     (e.g. awaitingCollection, delivered, waitingForCalibration).
--                     Rationale: on STAGE the item-level CalibrationStatusId is entirely
--                     NULL, and shipping/delivery state is genuinely an order-level concept,
--                     so this SP keys on the order overall status (unlike GetCustomerDeviceList,
--                     which keys on the item calibration status). See NOTE below.
--   * statusLabel  -> Hebrew label of the same status (StatusDescriptionHEB) for the
--                     Hebrew-first portal, since no FE code->label map exists for this screen yet.
--   * shippingMethod   -> wp.ShipTypeDesc (order-level shipping method).
--   * shippingDoc      -> itm.ShippingDoc (delivery note / shipping document number).
--   * shippingAddress  -> COALESCE(itm.ShippingAddress, c.CustomerAddress).
--   * All *Date columns -> DD.MM.YYYY string (CONVERT style 104), NULL-safe.
--       receivingDate     = itm.CustomerReceivingDate (date device received at lab)
--       calibrationDate   = itm.ActualCalibrationDate
--       expectedReturnDate= itm.ExpectedReturnDate
--       deliveryDate      = itm.ActualReturnDate (date shipped back to customer)
--
-- NOTE for review (Ariel): source mappings below are best-guess from the Calibrator
--   schema (no Figma). Please confirm:
--     * status source   -> wp.OrderOverallStatusId (order-level). Item-level
--       CalibrationStatusId is 100% NULL on STAGE; confirm the shipping screen wants the
--       order status (and, if so, whether it should be filtered to the delivery-side
--       statuses only, e.g. AwaitingCollection / delivered).
--     * deliveryDate    -> itm.ActualReturnDate (alt: a dedicated shipping-out date if added)
--     * shippingAddress -> itm.ShippingAddress fallback c.CustomerAddress (alt: itm.SiteAddress)
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[GetCustomerShipments]
    @LoggedInUserEmail NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @CustomerId INT = NULL;

    SELECT TOP (1) @CustomerId = cc.CustomerId
    FROM [dbo].[CustomerContacts] AS cc
    WHERE cc.CustomerContactEmail = @LoggedInUserEmail;

    ;WITH shipments AS
    (
        SELECT
             itm.OrderDetailsItemId                                                  AS id
            ,wp.OrderNumber                                                          AS OrderNumber
            ,itm.MbaReportNumber                                                     AS MbaReportNumber
            ,itm.SerialNumber                                                        AS SerialNumber
            ,pt.OrdersProductTypeName                                                AS DeviceDescription
            ,itm.OrdersDeviceManufacturer                                            AS DeviceManufacturer
            ,itm.DeviceModel                                                         AS DeviceModel
            ,wp.ShipTypeDesc                                                         AS ShippingMethod
            ,itm.ShippingDoc                                                         AS ShippingDoc
            ,COALESCE(itm.ShippingAddress, c.CustomerAddress)                        AS ShippingAddress
            ,itm.CustomerReceivingDate                                               AS ReceivingDate
            ,itm.ActualCalibrationDate                                               AS CalibrationDate
            ,itm.ExpectedReturnDate                                                  AS ExpectedReturnDate
            ,itm.ActualReturnDate                                                    AS DeliveryDate
            ,st.StatusDescriptionENG                                                 AS StatusEng
            ,st.StatusDescriptionHEB                                                 AS StatusHeb
            ,ROW_NUMBER() OVER (PARTITION BY itm.OrderDetailsItemId
                                ORDER BY wp.OrderWorkPlanId DESC)                    AS Rn
        FROM [dbo].[OrderWorkPlans]      AS wp
        JOIN [dbo].[OrderDetails]        AS od  ON od.OrderWorkPlanId = wp.OrderWorkPlanId
        JOIN [dbo].[OrderDetailsItems]   AS itm ON itm.OrderDetailId  = od.OrderDetailId
        LEFT JOIN [dbo].[Customers]          AS c  ON c.CustomerId          = wp.CustomerId
        LEFT JOIN [dbo].[Statuses]           AS st ON st.StatusId           = wp.OrderOverallStatusId
        LEFT JOIN [dbo].[OrdersProductTypes] AS pt ON pt.OrdersProductTypeId = od.OrdersProductTypeId
        WHERE wp.CustomerId       = @CustomerId
          AND wp.IsCancelled      = 0
          AND ISNULL(od.IsDeleted, 0)  = 0
          AND ISNULL(od.IsCancelled,0) = 0
          AND ISNULL(itm.IsDeleted, 0) = 0
          AND ISNULL(itm.IsCancelled,0)= 0
    )
    SELECT
         s.id
        ,s.OrderNumber                                                   AS orderNumber
        ,s.MbaReportNumber                                              AS mbaReportNumber
        ,s.SerialNumber                                                  AS serialNumber
        ,s.DeviceDescription                                            AS deviceDescription
        ,s.DeviceManufacturer                                           AS deviceManufacturer
        ,s.DeviceModel                                                   AS deviceModel
        ,s.ShippingMethod                                               AS shippingMethod
        ,s.ShippingDoc                                                   AS shippingDoc
        ,s.ShippingAddress                                              AS shippingAddress
        ,CONVERT(VARCHAR(10), s.ReceivingDate,      104)               AS receivingDate
        ,CONVERT(VARCHAR(10), s.CalibrationDate,    104)               AS calibrationDate
        ,CONVERT(VARCHAR(10), s.ExpectedReturnDate, 104)               AS expectedReturnDate
        ,CONVERT(VARCHAR(10), s.DeliveryDate,       104)               AS deliveryDate
        ,CASE
            WHEN s.StatusEng IS NULL OR LEN(s.StatusEng) = 0 THEN NULL
            ELSE LOWER(LEFT(REPLACE(s.StatusEng, '''', ''), 1))
               + SUBSTRING(REPLACE(s.StatusEng, '''', ''), 2, 200)
         END                                                            AS status
        ,s.StatusHeb                                                    AS statusLabel
    FROM shipments AS s
    WHERE s.Rn = 1
    ORDER BY s.DeliveryDate DESC, s.CalibrationDate DESC
    OPTION (RECOMPILE);
END
