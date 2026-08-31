SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/*
    dbo.GetCustomerRequests
    ---------------------------------------------------------------------------------------------
    The customer's orders as the portal shows them ("בקשות"): one row per OrderWorkPlan, with the
    device count, the earliest next-calibration date, whether any line is in-house, and the net
    price.

    2026-08-31 - MBA-943: scoped to the caller's customer SET rather than a single customer.

    An e-mail address is a contact of several customers in 3,684 cases, and orders are filed
    against whichever company owns the devices. Resolving to the lowest CustomerContactId showed
    davide@iscar.co.il the orders of ישקר בע"מ - none - while his real orders sat under three other
    ישקר divisions.

    The set comes from dbo.GetPortalCustomerIds, which is derived from the caller's own contact
    rows and takes nothing from the request, so no order of another customer can be reached.

    @SelectedCustomerId is gone; MBA-936 added it for a branch picker we decided not to build.

    NEW COLUMN: customerName - which company each order belongs to. Front end: MBA-942.
*/
CREATE OR ALTER PROCEDURE [dbo].[GetCustomerRequests]
    @LoggedInUserEmail NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH req AS
    (
        SELECT
             wp.OrderWorkPlanId
            ,wp.OrderNumber
            ,mine.CustomerName
            ,COALESCE(wp.OrderStatusId, wp.OrderOverallStatusId)      AS StatusId
            ,COALESCE(NULLIF(LTRIM(RTRIM(wp.Notes)), N''),
                      NULLIF(LTRIM(RTRIM(wp.CustomerComment)), N''))   AS Note
            ,(
                SELECT COUNT(*)
                FROM [dbo].[OrderDetails]      AS od2
                JOIN [dbo].[OrderDetailsItems] AS it2 ON it2.OrderDetailId = od2.OrderDetailId
                WHERE od2.OrderWorkPlanId       = wp.OrderWorkPlanId
                  AND ISNULL(od2.IsDeleted, 0)  = 0
                  AND ISNULL(od2.IsCancelled,0) = 0
                  AND ISNULL(it2.IsDeleted, 0)  = 0
                  AND ISNULL(it2.IsCancelled,0) = 0
             )                                                         AS DeviceCount
            ,(
                SELECT MIN(it3.NextCalibrationDate)
                FROM [dbo].[OrderDetails]      AS od3
                JOIN [dbo].[OrderDetailsItems] AS it3 ON it3.OrderDetailId = od3.OrderDetailId
                WHERE od3.OrderWorkPlanId       = wp.OrderWorkPlanId
                  AND ISNULL(od3.IsDeleted, 0)  = 0
                  AND ISNULL(it3.IsDeleted, 0)  = 0
             )                                                         AS ExpectedCalibrationDate
            ,(
                SELECT MAX(CAST(ISNULL(od4.IsInHouse, 0) AS INT))
                FROM [dbo].[OrderDetails] AS od4
                WHERE od4.OrderWorkPlanId       = wp.OrderWorkPlanId
                  AND ISNULL(od4.IsDeleted, 0)  = 0
                  AND ISNULL(od4.IsCancelled,0) = 0
             )                                                         AS AnyInHouse
            ,(
                SELECT SUM(od5.PRICE)
                FROM [dbo].[OrderDetails] AS od5
                WHERE od5.OrderWorkPlanId       = wp.OrderWorkPlanId
                  AND ISNULL(od5.IsDeleted, 0)  = 0
                  AND ISNULL(od5.IsCancelled,0) = 0
             )                                                         AS NetPrice
        FROM dbo.GetPortalCustomerIds(@LoggedInUserEmail) AS mine
        JOIN [dbo].[OrderWorkPlans] AS wp ON wp.CustomerId = mine.CustomerId
        WHERE wp.IsCancelled = 0
    )
    SELECT
         CASE r.StatusId
            WHEN 66 THEN 'sent'
            WHEN 72 THEN 'rejected'
            WHEN 73 THEN 'waitingForCustomer'
            WHEN 76 THEN 'waitingForCalibration'
            ELSE CASE
                    WHEN st.StatusDescriptionENG IS NULL
                      OR LEN(st.StatusDescriptionENG) = 0 THEN NULL
                    ELSE LOWER(LEFT(REPLACE(st.StatusDescriptionENG, '''', ''), 1))
                       + SUBSTRING(REPLACE(st.StatusDescriptionENG, '''', ''), 2, 200)
                 END
         END                                                          AS status
        ,r.OrderNumber                                                AS quoteNumber
        ,r.DeviceCount                                                AS deviceCount
        ,CONVERT(VARCHAR(10), r.ExpectedCalibrationDate, 104)         AS expectedCalibrationDate
        ,CASE
            WHEN r.AnyInHouse IS NULL THEN NULL
            WHEN r.AnyInHouse = 1     THEN 'lab'
            ELSE 'customer'
         END                                                          AS calibrationLocation
        ,CAST(r.NetPrice AS DECIMAL(18,2))                            AS price
        ,r.Note                                                       AS note
        ,r.CustomerName                                               AS customerName
    FROM req AS r
    LEFT JOIN [dbo].[Statuses] AS st
           ON st.StatusId = r.StatusId
          AND st.StatusCategoryId = 9      -- OrderStatus category
    ORDER BY r.OrderWorkPlanId DESC
    OPTION (RECOMPILE);
END
GO
