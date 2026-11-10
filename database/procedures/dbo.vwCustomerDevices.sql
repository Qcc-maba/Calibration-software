/*
    dbo.vwCustomerDevices                                                               MBA-996
    ---------------------------------------------------------------------------------------------
    The one read path for a customer's devices: one row per device the portal may show, with its
    latest visit and its number of visits. The device list and detail procedures, and later
    screens (recall, dashboards), read this view - so the display rules live here and nowhere else.
    Design: DBA/schema-updates.md section 2, point 5.

    It does NOT filter by caller. Every portal procedure that reads it filters through
    dbo.GetPortalCustomerIds(@LoggedInUserEmail), and the portal login is never granted SELECT on
    it (point 7).

    DISPLAY RULES
    -------------
      - hidden: IsDeleted = 1 (the customer hid it) or IsInactiveInSource = 1 (cancelled in Priority);
      - shown: a registered device with at least one visit, or a device typed in the portal. That
        keeps today's list - devices the customer has calibrated with us - while the whole register
        is loaded underneath; showing every registered device later is this one condition;
      - visits: order lines with the device's SERN, under the device's OWN customer. A device that
        moved between customers in Priority therefore shows only the visits of its current owner.
        STAGE 2026-11-10: 5,593 of 5,617 visits with a SERN have their device; the other 24 are
        devices cancelled in Priority, which the portal already hides; 3 sit under another customer.

    ONE VISIT PER CALIBRATION
    -------------------------
    134 Docs (calibration documents) sit on two order lines each (PROD copy of 2026-10-21) - open
    question 1 of section 2. Until it is settled VisitCount counts distinct Docs. The latest visit
    is the newest order line of the newest order, the way dbo.GetCustomerDeviceList picks it today.

    Columns for the portal: CustomerDeviceID is the device's id (stable across visits);
    LatestOrderDetailsItemId is the visit the report and calibration links use.
*/
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

CREATE OR ALTER VIEW dbo.vwCustomerDevices
AS
SELECT
    d.CustomerDeviceID,
    d.CustomerId,
    d.SERN,
    CAST(CASE WHEN d.SERN IS NOT NULL THEN 1 ELSE 0 END AS BIT)        AS IsRegistered,
    d.SerialNumber,
    d.SerialKey,
    d.Model,
    d.OrdersDeviceManufacturer,
    d.ManufacturerNumber,
    d.AdditionalDeviceNumber,
    d.DevicePart,
    d.DeviceTypeName,
    d.DeviceDescription,
    d.OrdersProductTypeId,
    d.MainCategoryId,
    d.SecondaryCategoryId,
    d.CustomerSiteId,
    d.CustomerContactId,
    d.DeviceLocation,
    d.Accuracy,
    d.CalibrationIntervalMonths,
    d.ReportLanguage,
    d.SpecificationReferenceId,
    d.MeasurementsSpecificationId,
    d.PrimaryMeasurmentUnitId,
    d.SecondaryMeasurmentUnitId,
    d.NeedsReview,
    d.CreatedDate,
    v.VisitCount,
    lv.OrderDetailsItemId                                              AS LatestOrderDetailsItemId,
    lv.Doc                                                             AS LatestDoc,
    lv.ActualCalibrationDate                                           AS LastCalibrationDate,
    /* a registered device's next date is its latest visit's; a typed one keeps what was entered */
    CASE WHEN d.SERN IS NOT NULL THEN lv.NextCalibrationDate
         ELSE COALESCE(lv.NextCalibrationDate, d.NextCalibrationDate) END AS NextCalibrationDate
FROM dbo.CustomerDevices AS d
OUTER APPLY (
    SELECT COUNT(DISTINCT COALESCE(i.Doc, -i.OrderDetailsItemId)) AS VisitCount
    FROM dbo.OrderDetailsItems AS i
    JOIN dbo.OrderDetails      AS od ON od.OrderDetailId    = i.OrderDetailId
    JOIN dbo.OrderWorkPlans    AS wp ON wp.OrderWorkPlanId  = od.OrderWorkPlanId
    WHERE i.SERN = d.SERN AND i.IsDeleted = 0 AND wp.CustomerId = d.CustomerId
) AS v
OUTER APPLY (
    SELECT TOP (1) i.OrderDetailsItemId, i.Doc, i.ActualCalibrationDate, i.NextCalibrationDate
    FROM dbo.OrderDetailsItems AS i
    JOIN dbo.OrderDetails      AS od ON od.OrderDetailId    = i.OrderDetailId
    JOIN dbo.OrderWorkPlans    AS wp ON wp.OrderWorkPlanId  = od.OrderWorkPlanId
    WHERE i.SERN = d.SERN AND i.IsDeleted = 0 AND wp.CustomerId = d.CustomerId
    ORDER BY wp.OrderWorkPlanId DESC, i.OrderDetailsItemId DESC   /* as GetCustomerDeviceList picks it today */
) AS lv
WHERE d.IsDeleted = 0
  AND d.IsInactiveInSource = 0
  AND (d.SERN IS NULL OR v.VisitCount > 0);
GO
