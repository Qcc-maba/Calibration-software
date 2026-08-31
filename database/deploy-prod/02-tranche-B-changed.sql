/*
    Tranche B - objects that already exist on PROD with a different body. Run this LAST.
    ---------------------------------------------------------------------------------------------
    This is the only tranche that can break something that works today. Every statement is
    CREATE OR ALTER, so it is one statement per object and nothing is dropped.

    Take a copy of the current definitions BEFORE running it - that is the rollback:

        SELECT o.name, OBJECT_DEFINITION(o.object_id) FROM sys.objects o
        WHERE o.type IN ('P','FN','IF','TF','V');

    To roll one object back, run its saved definition with CREATE changed to CREATE OR ALTER.
*/
SET NOCOUNT ON;
GO

/* ===== dbo.AssignCalibrationEnvironmentalConditions ===== */
GO
-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 07/01/2026
-- Description:	Assign environmental conditions for calibrated device
-- JiraLink: https://calibration-maba.atlassian.net/browse/MABA-478
--Json example
--'
--[
--  {"OrderDetailsItemId": 1254,"MeasurementDeviceUnitId": 12, "NominalValue": 30,"Tolerance": 12.54,"MinToleranceBorder": 1.54,"MaxToleranceBorder": 1.54},
--  {"OrderDetailsItemId": 1255,"MeasurementDeviceUnitId": 10,"NominalValue": 33,"Tolerance": 1.54,"MinToleranceBorder": 1.54,"MaxToleranceBorder": 1.54 }
--]'
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[AssignCalibrationEnvironmentalConditions]
@ConditionsJson NVARCHAR(MAX),
@LoggedInUserEmail NVARCHAR(50),
@IsDelete BIT = NULL

AS

BEGIN

SET NOCOUNT ON;

DECLARE @LoggedInUserId INT 
DECLARE @SourceId TINYINT

SELECT 
 @LoggedInUserId  = d.UserId 
,@SourceId = d.SourceId
FROM dbo.GetSourceFilterByEmail(@LoggedInUserEmail) as d


	MERGE INTO [dbo].[CalibrationEnvironmentalConditions] AS dest
	USING (
		SELECT 
			OrderDetailsItemId,
			MeasurementDeviceUnitId,
			NominalValue,
			Tolerance,
			MinToleranceBorder,
			MaxToleranceBorder
		FROM OPENJSON (@ConditionsJson) WITH (
			OrderDetailsItemId INT '$.OrderDetailsItemId',
			MeasurementDeviceUnitId INT'$.MeasurementDeviceUnitId',
			NominalValue DECIMAL(18,6) '$.NominalValue',
			Tolerance DECIMAL(18,6) '$.Tolerance',
			MinToleranceBorder DECIMAL(18,6) '$.MinToleranceBorder',
			MaxToleranceBorder DECIMAL(18,6) '$.MaxToleranceBorder'
		)
		) AS source
		ON dest.[OrderDetailsItemId] = source.[OrderDetailsItemId]
			AND dest.[MeasurementDeviceUnitId] = source.[MeasurementDeviceUnitId]
	WHEN MATCHED
		THEN
			UPDATE
			SET  dest.[NominalValue] = source.[NominalValue]
				,dest.[Tolerance] = source.[Tolerance]
				,dest.[MinToleranceBorder] = source.[MinToleranceBorder]
				,dest.[MaxToleranceBorder] = source.[MaxToleranceBorder]
				,dest.[UpdatedDate] = GETDATE()
				,dest.[UpdateUserID] = @LoggedInUserId
				,dest.[IsDeleted] = IIF(@IsDelete IS NULL, 0, 1)
	WHEN NOT MATCHED BY TARGET
		THEN
			INSERT (
				[OrderDetailsItemId]
				,[MeasurementDeviceUnitId]
				,[NominalValue]
				,[Tolerance]
				,[MinToleranceBorder]
				,[MaxToleranceBorder]
				,[CreateDate]
				,[UpdateUserID]
				)
			VALUES (
				source.[OrderDetailsItemId]
				,source.[MeasurementDeviceUnitId]
				,source.[NominalValue]
				,source.[Tolerance]
				,source.[MinToleranceBorder]
				,source.[MaxToleranceBorder]
				,GETDATE()
				,@LoggedInUserId
				);

END

GO
/* ===== dbo.GetCalibrationValuesForManyOrderDetailItems ===== */
GO
-- =============================================
-- Proc:        dbo.GetCalibrationValuesForManyOrderDetailItems
-- Jira:        the calibration wizard's `sensors.getCalibrationValuesForManyOrderDetailItems`
--
-- WHY: the front-end deployed on 2026-08-13 calls a batch version of
-- dbo.GetCalibrationValuesForOrderDetailItem, but only the SINGULAR proc existed — on STAGE and on
-- PROD. Every call failed, which is the 400 that survived every other fix on stg.qcc.co.il.
--
-- This is the singular proc's query, unchanged, with three differences:
--   1. it takes a LIST of OrderDetailsItemIds instead of one (comma separated, the convention used
--      by @OrderWorkPlanIds / @EquipmentIds / @AssignedCalibratorsIds elsewhere in this database);
--   2. OrderDetailsItemId is RETURNED as the first column, so the caller can group the flat result
--      back per item — a batch endpoint is useless without it;
--   3. @OrderDetailIds is optional. The singular proc also filters on OrderDetailId, but that
--      column is not unique (OrderDetailId 58 exists on two different work plans), so the item id
--      is the only safe key. Pass the list only if you specifically want that extra restriction.
--
-- The per-item pairing of measurement points to environmental conditions is unchanged: both sides
-- are numbered with ROW_NUMBER() PARTITION BY OrderDetailsItemId and FULL OUTER JOINed on
-- (OrderDetailsItemId, rn), so batching cannot mix rows between items.
--
-- CONTRACT NOT CONFIRMED WITH THE FE. The parameter name and shape are inferred from this
-- database's conventions. If the router sends something else (a JSON array, a different name),
-- this still will not bind — tell me the exact signature and it is a one-line change.
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[GetCalibrationValuesForManyOrderDetailItems]
    @OrderDetailsItemIds NVARCHAR(MAX),
    @OrderDetailIds      NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @items TABLE(OrderDetailsItemId INT PRIMARY KEY);
    INSERT INTO @items(OrderDetailsItemId)
    SELECT DISTINCT TRY_CONVERT(INT, LTRIM(RTRIM(value)))
    FROM STRING_SPLIT(ISNULL(@OrderDetailsItemIds, N''), ',')
    WHERE LTRIM(RTRIM(value)) <> N''            -- TRY_CONVERT(INT, N'') returns 0, not NULL:
      AND TRY_CONVERT(INT, LTRIM(RTRIM(value))) IS NOT NULL;   -- without this an empty list becomes {0}

    DECLARE @details TABLE(OrderDetailId INT PRIMARY KEY);
    INSERT INTO @details(OrderDetailId)
    SELECT DISTINCT TRY_CONVERT(INT, LTRIM(RTRIM(value)))
    FROM STRING_SPLIT(ISNULL(@OrderDetailIds, N''), ',')
    WHERE LTRIM(RTRIM(value)) <> N''            -- TRY_CONVERT(INT, N'') returns 0, not NULL:
      AND TRY_CONVERT(INT, LTRIM(RTRIM(value))) IS NOT NULL;   -- without this an empty list becomes {0}

    SELECT
         itm.[OrderDetailsItemId]
        ,COALESCE(combined.[MbaReportNumber], itm.[MbaReportNumber]) as [MbaReportNumber]
        ,COALESCE(combined.[SerialNumber], itm.[SerialNumber]) as [SerialNumber]
        ,itm.[UnitUnderTestValue]
        ,itm.[MeasurementUnitId] as UUTId
        ,mdu4.[ShortNameHe] as UUTDescription
        ,N'P' + CAST(combined.[ChannelNumber] as NVARCHAR(30)) as [ChannelNumber]
        ,combined.[SensorMeasurementDeviceId]
        ,md.[MabaID] AS MasterSensorMabaID
        ,md.ID as [MeasurementDeviceId]
        ,combined.[Tolerance]
        ,combined.[NominalValue]
        ,wp.[OrderNumber]
        ,combined.[MasterValue]
        ,combined.[MasterValueUnitId]
        ,mdu.[ShortNameHe] as MasterValueUnitDescription
        /* The display value: the reading's own precision, but never fewer than 3 decimals.
           Rounding purely to the input erased the correction - 23 came back as 23. Full
           precision is still available as MasterValueAfterCorrectionExact. */
        ,mvc.Corrected      as [MasterValueAfterCorrection]
        ,mvc.CorrectedExact as [MasterValueAfterCorrectionExact]
        /* MBA-475: is the calibrator driving the master outside its own working range?
           This is a DIFFERENT question from mvc.OutOfRange, which asks whether the reading fell
           outside the CERTIFICATE and the deviation had to be clamped. A master can be well
           inside its working range and still beyond its last calibrated point, and the reverse.
           The threshold is the fixed 10 units the ticket specifies - range -80..200, reading 220,
           20 beyond, so highlighted. It is written once, here and in the Many variant. */
        ,md.WorkRangeMin as [SensorRangeMin]
        ,md.WorkRangeMax as [SensorRangeMax]
        ,CAST(CASE WHEN md.WorkRangeMin IS NULL OR md.WorkRangeMax IS NULL THEN NULL
                   WHEN combined.[MasterValue] IS NULL THEN NULL
                   WHEN combined.[MasterValue] > md.WorkRangeMax + 10 THEN 1
                   WHEN combined.[MasterValue] < md.WorkRangeMin - 10 THEN 1
                   ELSE 0 END AS BIT) as [OutOfSensorRange]
        ,CAST(CASE WHEN md.WorkRangeMin IS NULL OR md.WorkRangeMax IS NULL THEN NULL
                   WHEN combined.[MasterValue] > md.WorkRangeMax THEN combined.[MasterValue] - md.WorkRangeMax
                   WHEN combined.[MasterValue] < md.WorkRangeMin THEN md.WorkRangeMin - combined.[MasterValue]
                   ELSE 0 END AS DECIMAL(18,6)) as [BeyondSensorRangeBy]
        /* and whether the compensation itself had to extrapolate */
        ,mvc.OutOfRange   as [BeyondCertificateRange]
        ,mvc.Extrapolated as [DeviationExtrapolated]
        ,mvc.CertificateTop      as [CertificateTop]
        ,mvc.LastCalibratedPoint as [LastCalibratedPoint]
        /* MBA-475: whether this instrument is permitted to go out of range at all, from the
           kyulan registry. 328 instruments permit neither end; for those, any overshoot may
           deserve the highlight rather than only one past 10. */
        ,md.AllowMinOutOfRange as [AllowMinOutOfRange]
        ,md.AllowMaxOutOfRange as [AllowMaxOutOfRange]
        ,combined.MeasuredValue
        ,combined.MeasuredValueUnitId
        ,mdu3.[ShortNameHe] as MeasuredUUTDescription
        ,combined.[AdditionalValue]
        ,combined.[AdditionalValueUnitId]
        ,mdu2.[ShortNameHe] as AdditionalUUTDescription
        ,combined.[MasterValue] - combined.[NominalValue] as [Deviation]
        ,((combined.[MasterValue] - combined.[NominalValue])/COALESCE(NULLIF(combined.[Tolerance],0),1))*100 as AllowedDeviation
        ,combined.[UncertancyValue]
        /* MBA-811: still unimplemented, but a typed NULL rather than a string that reaches the
           screen as text. Computing it needs a decision on what "last calibration" means for
           this device and point - raised separately. */
        ,CAST(NULL AS DECIMAL(18,6)) as DriftFromLastCalibration
        ,combined.StabilityValue
        ,combined.[MeasurmentPointsToOrderDetailsItemId]
    FROM [dbo].[OrderDetailsItems] as itm
    JOIN @items AS want ON want.OrderDetailsItemId = itm.OrderDetailsItemId
    JOIN [dbo].[OrderDetails] as od ON itm.OrderDetailId = od.OrderDetailId
    JOIN [dbo].[OrderWorkPlans] as wp ON wp.OrderWorkPlanId = od.OrderWorkPlanId
    LEFT JOIN (
        SELECT
            COALESCE(mpo.OrderDetailsItemId, evnc.OrderDetailsItemId) as OrderDetailsItemId,
            mpo.ChannelNumber,
            mpo.SensorMeasurementDeviceId,
            mpo.MasterValue,
            mpo.MasterValueUnitId,
            mpo.MeasuredValue,
            mpo.MeasuredValueUnitId,
            mpo.AdditionalValue,
            mpo.AdditionalValueUnitId,
            mpo.UncertancyValue,
            mpo.StabilityValue,
            mpo.MeasurmentPointsToOrderDetailsItemId,
            mpo.SerialNumber,
            mpo.MbaReportNumber,
            COALESCE(mpo.Tolerance, evnc.Tolerance) as Tolerance,
            COALESCE(mpo.NominalValue, evnc.NominalValue) as NominalValue
        FROM (
            SELECT *,
                   ROW_NUMBER() OVER(PARTITION BY OrderDetailsItemId ORDER BY MeasurmentPointsToOrderDetailsItemId) as rn
            FROM [dbo].[MeasurmentPointsToOrderDetailsItems]
            WHERE IsDeleted = 0
              AND OrderDetailsItemId IN (SELECT OrderDetailsItemId FROM @items)
        ) mpo
        FULL OUTER JOIN (
            SELECT *,
                   ROW_NUMBER() OVER(PARTITION BY OrderDetailsItemId ORDER BY NominalValue, CreateDate) as rn
            FROM [dbo].[CalibrationEnvironmentalConditions]
            WHERE IsDeleted = 0
              AND OrderDetailsItemId IN (SELECT OrderDetailsItemId FROM @items)
        ) evnc ON mpo.OrderDetailsItemId = evnc.OrderDetailsItemId AND mpo.rn = evnc.rn
    ) as combined ON itm.OrderDetailsItemId = combined.OrderDetailsItemId
    LEFT JOIN [dbo].[MeasurementDeviceUnits] as mdu  ON combined.[MasterValueUnitId] = mdu.[MeasurementDeviceUnitId]
    LEFT JOIN [dbo].[MeasurementDeviceUnits] as mdu2 ON combined.[AdditionalValueUnitId] = mdu2.[MeasurementDeviceUnitId]
    LEFT JOIN [dbo].[MeasurementDeviceUnits] as mdu3 ON combined.MeasuredValueUnitId = mdu3.[MeasurementDeviceUnitId]
    LEFT JOIN [dbo].[MeasurementDeviceUnits] as mdu4 ON itm.MeasurementUnitId = mdu4.[MeasurementDeviceUnitId]
    LEFT JOIN [dbo].[MeasurementDevices] as md ON md.ID = combined.[SensorMeasurementDeviceId]
    /* MBA-811: the master reading with its certificate deviation applied. Returns NULL for a
       master with no certificate, and for a temperature+humidity master - that one needs the
       2D interpolation in dbo.fnHumidityAfterCorrection, which our range-shaped correction
       data cannot feed yet. NULL is honest; the screen shows a dash. */
    OUTER APPLY dbo.fnMasterValueAfterCorrection(md.ID, combined.[MasterValue], NULL) AS mvc
    /* the third argument is passed explicitly: an inline table-valued function does not
       apply parameter defaults the way a stored procedure does, and omitting it fails the
       whole call with "an insufficient number of arguments". */
    WHERE (NOT EXISTS (SELECT 1 FROM @details) OR itm.OrderDetailId IN (SELECT OrderDetailId FROM @details))
    ORDER BY itm.[OrderDetailsItemId], combined.[MeasurmentPointsToOrderDetailsItemId], combined.NominalValue;
END

GO
/* ===== dbo.GetCalibrationValuesForOrderDetailItem ===== */
GO
CREATE OR ALTER PROCEDURE [dbo].[GetCalibrationValuesForOrderDetailItem]
@OrderDetailId INT, 
@OrderDetailsItemId INT
AS
BEGIN
    SELECT 
         COALESCE(combined.[MbaReportNumber], itm.[MbaReportNumber]) as [MbaReportNumber]
        ,COALESCE(combined.[SerialNumber], itm.[SerialNumber]) as [SerialNumber]
        ,itm.[UnitUnderTestValue]
        ,itm.[MeasurementUnitId] as UUTId
        ,mdu4.[ShortNameHe] as UUTDescription
        ,N'P' + CAST(combined.[ChannelNumber] as NVARCHAR(30)) as [ChannelNumber]
        ,combined.[SensorMeasurementDeviceId]
        ,md.[MabaID] AS MasterSensorMabaID
        ,md.ID as [MeasurementDeviceId] 
        ,combined.[Tolerance]
        ,combined.[NominalValue]
        ,wp.[OrderNumber]
        ,combined.[MasterValue]
        ,combined.[MasterValueUnitId] 
        ,mdu.[ShortNameHe] as MasterValueUnitDescription
        /* The display value: the reading's own precision, but never fewer than 3 decimals.
           Rounding purely to the input erased the correction - 23 came back as 23. Full
           precision is still available as MasterValueAfterCorrectionExact. */
        ,mvc.Corrected      as [MasterValueAfterCorrection]
        ,mvc.CorrectedExact as [MasterValueAfterCorrectionExact]
        /* MBA-475: is the calibrator driving the master outside its own working range?
           This is a DIFFERENT question from mvc.OutOfRange, which asks whether the reading fell
           outside the CERTIFICATE and the deviation had to be clamped. A master can be well
           inside its working range and still beyond its last calibrated point, and the reverse.
           The threshold is the fixed 10 units the ticket specifies - range -80..200, reading 220,
           20 beyond, so highlighted. It is written once, here and in the Many variant. */
        ,md.WorkRangeMin as [SensorRangeMin]
        ,md.WorkRangeMax as [SensorRangeMax]
        ,CAST(CASE WHEN md.WorkRangeMin IS NULL OR md.WorkRangeMax IS NULL THEN NULL
                   WHEN combined.[MasterValue] IS NULL THEN NULL
                   WHEN combined.[MasterValue] > md.WorkRangeMax + 10 THEN 1
                   WHEN combined.[MasterValue] < md.WorkRangeMin - 10 THEN 1
                   ELSE 0 END AS BIT) as [OutOfSensorRange]
        ,CAST(CASE WHEN md.WorkRangeMin IS NULL OR md.WorkRangeMax IS NULL THEN NULL
                   WHEN combined.[MasterValue] > md.WorkRangeMax THEN combined.[MasterValue] - md.WorkRangeMax
                   WHEN combined.[MasterValue] < md.WorkRangeMin THEN md.WorkRangeMin - combined.[MasterValue]
                   ELSE 0 END AS DECIMAL(18,6)) as [BeyondSensorRangeBy]
        /* and whether the compensation itself had to extrapolate */
        ,mvc.OutOfRange   as [BeyondCertificateRange]
        ,mvc.Extrapolated as [DeviationExtrapolated]
        ,mvc.CertificateTop      as [CertificateTop]
        ,mvc.LastCalibratedPoint as [LastCalibratedPoint]
        /* MBA-475: whether this instrument is permitted to go out of range at all, from the
           kyulan registry. 328 instruments permit neither end; for those, any overshoot may
           deserve the highlight rather than only one past 10. */
        ,md.AllowMinOutOfRange as [AllowMinOutOfRange]
        ,md.AllowMaxOutOfRange as [AllowMaxOutOfRange]
        ,combined.MeasuredValue
        ,combined.MeasuredValueUnitId
        ,mdu3.[ShortNameHe] as MeasuredUUTDescription
        ,combined.[AdditionalValue]
        ,combined.[AdditionalValueUnitId]
        ,mdu2.[ShortNameHe] as AdditionalUUTDescription
        ,combined.[MasterValue] - combined.[NominalValue] as [Deviation]
        ,((combined.[MasterValue] - combined.[NominalValue])/COALESCE(NULLIF(combined.[Tolerance],0),1))*100 as AllowedDeviation
        ,combined.[UncertancyValue]
        /* MBA-811: still unimplemented, but a typed NULL rather than a string that reaches the
           screen as text. Computing it needs a decision on what "last calibration" means for
           this device and point - raised separately. */
        ,CAST(NULL AS DECIMAL(18,6)) as DriftFromLastCalibration
        ,combined.StabilityValue
        ,combined.[MeasurmentPointsToOrderDetailsItemId]  
    FROM [dbo].[OrderDetailsItems] as itm
    JOIN [dbo].[OrderDetails] as od ON itm.OrderDetailId = od.OrderDetailId
    JOIN [dbo].[OrderWorkPlans] as wp ON wp.OrderWorkPlanId = od.OrderWorkPlanId
    LEFT JOIN (
        SELECT 
            COALESCE(mpo.OrderDetailsItemId, evnc.OrderDetailsItemId) as OrderDetailsItemId,
            mpo.ChannelNumber,
            mpo.SensorMeasurementDeviceId,
            mpo.MasterValue,
            mpo.MasterValueUnitId,
            mpo.MeasuredValue,
            mpo.MeasuredValueUnitId,
            mpo.AdditionalValue,
            mpo.AdditionalValueUnitId,
            mpo.UncertancyValue,
            mpo.StabilityValue,
            mpo.MeasurmentPointsToOrderDetailsItemId,
            mpo.SerialNumber,
            mpo.MbaReportNumber,
            COALESCE(mpo.Tolerance, evnc.Tolerance) as Tolerance,
            COALESCE(mpo.NominalValue, evnc.NominalValue) as NominalValue
        FROM (
            SELECT *, 
                   ROW_NUMBER() OVER(PARTITION BY OrderDetailsItemId ORDER BY MeasurmentPointsToOrderDetailsItemId) as rn
            FROM [dbo].[MeasurmentPointsToOrderDetailsItems]
            WHERE IsDeleted = 0 AND OrderDetailsItemId = @OrderDetailsItemId
        ) mpo
        FULL OUTER JOIN (
            SELECT *, 
                   ROW_NUMBER() OVER(PARTITION BY OrderDetailsItemId ORDER BY NominalValue, CreateDate) as rn
            FROM [dbo].[CalibrationEnvironmentalConditions]
            WHERE IsDeleted = 0 AND OrderDetailsItemId = @OrderDetailsItemId
        ) evnc ON mpo.OrderDetailsItemId = evnc.OrderDetailsItemId AND mpo.rn = evnc.rn
    ) as combined ON itm.OrderDetailsItemId = combined.OrderDetailsItemId
    LEFT JOIN [dbo].[MeasurementDeviceUnits] as mdu ON combined.[MasterValueUnitId] = mdu.[MeasurementDeviceUnitId]
    LEFT JOIN [dbo].[MeasurementDeviceUnits] as mdu2 ON combined.[AdditionalValueUnitId] = mdu2.[MeasurementDeviceUnitId]
    LEFT JOIN [dbo].[MeasurementDeviceUnits] as mdu3 ON combined.MeasuredValueUnitId = mdu3.[MeasurementDeviceUnitId]
    LEFT JOIN [dbo].[MeasurementDeviceUnits] as mdu4 ON itm.MeasurementUnitId = mdu4.[MeasurementDeviceUnitId]
    LEFT JOIN [dbo].[MeasurementDevices] as md ON md.ID = combined.[SensorMeasurementDeviceId]
    /* MBA-811: the master reading with its certificate deviation applied. Returns NULL for a
       master with no certificate, and for a temperature+humidity master - that one needs the
       2D interpolation in dbo.fnHumidityAfterCorrection, which our range-shaped correction
       data cannot feed yet. NULL is honest; the screen shows a dash. */
    OUTER APPLY dbo.fnMasterValueAfterCorrection(md.ID, combined.[MasterValue], NULL) AS mvc
    /* the third argument is passed explicitly: an inline table-valued function does not
       apply parameter defaults the way a stored procedure does, and omitting it fails the
       whole call with "an insufficient number of arguments". */
    WHERE itm.OrderDetailId = @OrderDetailId 
      AND itm.OrderDetailsItemId = @OrderDetailsItemId
    ORDER BY combined.[MeasurmentPointsToOrderDetailsItemId], combined.NominalValue
END
GO
/* ===== dbo.GetCustomerCalibrationReports ===== */
GO
-- =============================================
-- Proc:        dbo.GetCustomerCalibrationReports
-- Jira:        MBA-796  "Customer Calibration-reports page (customer/calibration-reports)"
-- Description: Returns the calibration reports belonging to the logged-in customer
--              (customer portal "Calibration Reports" grid, route customer/calibration-reports).
--              Identity input matches dbo.GetCustomerDashboardData / dbo.GetCustomerDeviceList
--              (@LoggedInUserEmail -> CustomerId via dbo.CustomerContacts) and is scoped to the
--              calling customer only, consistent with the other GetCustomer* SPs.
--
--              A "calibration report" is an OrderDetailsItem that has an MbaReportNumber assigned.
--              Unlike GetCustomerDeviceList (one row per device, latest order only) this SP returns
--              ONE ROW PER REPORT (every report the customer has, including historical / update
--              cycles), newest calibration first. Filtering / sorting / search are CLIENT-SIDE.
--
-- Output columns (camelCase, matching the app's Raw* -> mapper convention):
--   id                 -> OrderDetailsItemId (row key AND part of the AWS report path)
--   orderNumber        -> OrderWorkPlans.OrderNumber (part of the AWS report path)
--   reportPath         -> convenience S3 key the FE otherwise builds via getOrderReportPath():
--                         'orders/{orderNumber}/reports/{id}/report.pdf'  (see
--                         src/lib/helpers/get-aws-file-paths.ts + pdf-preview-dialog)
--   mbaReportNumber    -> itm.MbaReportNumber (מספר דוח מבא)
--   serialNumber       -> itm.SerialNumber
--   deviceDescription  -> OrdersProductTypes.OrdersProductTypeName
--   deviceManufacturer -> itm.OrdersDeviceManufacturer
--   deviceModel        -> itm.DeviceModel
--   calibrationDate    -> DD.MM.YYYY (CONVERT style 104) from itm.ActualCalibrationDate
--   reportStatus       -> lower-camel of the ReportStatus StatusDescriptionENG (e.g.
--                         'createCalibrationReport'); NULL when no report status is set
--   reportStatusHeb    -> Statuses.StatusDescriptionHEB (Hebrew display text for the status)
--
-- OPEN QUESTIONS for review (screen is still a stub in the app, no wired tRPC/Figma yet):
--   * reportStatus source = itm.CalibrationReportStatusId (ReportStatus category). Confirm this
--     is the status the grid should show (vs. the calibration status used by GetCustomerDeviceList).
--   * FE enum for reportStatus is not defined yet, so the code is derived generically from the
--     English description (same fallback pattern GetCustomerDeviceList uses). Confirm the exact
--     camelCase codes once the FE filter chips exist, then map explicitly by StatusId.
--   * Download: FE builds the URL from {orderNumber, id}; reportPath is returned as a convenience.
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[GetCustomerCalibrationReports]
    @LoggedInUserEmail NVARCHAR(50),
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

    SELECT
         itm.OrderDetailsItemId                                              AS id
        ,wp.OrderNumber                                                      AS orderNumber
        ,CONCAT(N'orders/', wp.OrderNumber, N'/reports/',
                itm.OrderDetailsItemId, N'/report.pdf')                      AS reportPath
        ,itm.MbaReportNumber                                                 AS mbaReportNumber
        ,itm.SerialNumber                                                    AS serialNumber
        ,pt.OrdersProductTypeName                                            AS deviceDescription
        ,itm.OrdersDeviceManufacturer                                        AS deviceManufacturer
        ,itm.DeviceModel                                                     AS deviceModel
        ,CONVERT(VARCHAR(10), itm.ActualCalibrationDate, 104)               AS calibrationDate
        ,CASE
            WHEN st.StatusDescriptionENG IS NULL OR LEN(st.StatusDescriptionENG) = 0 THEN NULL
            ELSE LOWER(LEFT(REPLACE(st.StatusDescriptionENG, '''', ''), 1))
               + SUBSTRING(REPLACE(st.StatusDescriptionENG, '''', ''), 2, 200)
         END                                                                AS reportStatus
        ,st.StatusDescriptionHEB                                            AS reportStatusHeb
    FROM [dbo].[OrderWorkPlans]      AS wp
    JOIN [dbo].[OrderDetails]        AS od  ON od.OrderWorkPlanId = wp.OrderWorkPlanId
    JOIN [dbo].[OrderDetailsItems]   AS itm ON itm.OrderDetailId  = od.OrderDetailId
    LEFT JOIN [dbo].[Statuses]           AS st ON st.StatusId            = itm.CalibrationReportStatusId
    LEFT JOIN [dbo].[OrdersProductTypes] AS pt ON pt.OrdersProductTypeId = od.OrdersProductTypeId
    WHERE wp.CustomerId        = @CustomerId
      AND wp.IsCancelled       = 0
      AND ISNULL(od.IsDeleted, 0)   = 0
      AND ISNULL(od.IsCancelled, 0) = 0
      AND ISNULL(itm.IsDeleted, 0)  = 0
      AND ISNULL(itm.IsCancelled, 0)= 0
      AND itm.MbaReportNumber IS NOT NULL
      AND LEN(itm.MbaReportNumber) > 0
    ORDER BY itm.ActualCalibrationDate DESC
    OPTION (RECOMPILE);
END

GO
/* ===== dbo.GetCustomerContacts ===== */
GO
-- =============================================
-- Author:      Eduard Kudlaiev
-- Create date: 04/05/2026
-- Description: Contacts of the customer the caller belongs to.
--              Used by the internal customer-management screen AND by the customer
--              portal profile screen.
--
-- 2026-08-30 ג€” FIX: portal users could not resolve.
--
--              The customer was resolved only through dbo.GetSourceFilterByEmail, which
--              is a table-valued function over dbo.Users ג€” internal staff accounts. A
--              portal user is a row in dbo.CustomerContacts and has no Users row, so the
--              function returned NO ROWS, @CustomerId stayed NULL, and the final
--              predicate `WHERE c.CustomerId = @CustomerId` was always false. The screen
--              showed nothing, which is why the front end was left on mock data.
--
--              Now: resolve from dbo.CustomerContacts first, fall back to the function.
--              Order matters ג€” the portal case is checked first, and the staff path is
--              untouched, so the internal screen behaves exactly as before.
--
--              Same defect and same fix as GetCustomerSupportData (2026-08-30).
--              The SELECT list is unchanged; no caller needs to change.
-- JiraLink:
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[GetCustomerContacts]
@LoggedInUserEmail NVARCHAR(100),
    /* MBA-936: the branch the caller chose, when their address serves several customers.
       Verified below - an unverified id is ignored rather than trusted, so this cannot be
       used to read another customer's data. */
    @SelectedCustomerId INT = NULL
AS

SET NOCOUNT ON;

DECLARE @CustomerId INT = NULL;

-- Primary resolution: portal contact login
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
    SELECT TOP 1 @CustomerId = cc.CustomerId
    FROM dbo.CustomerContacts AS cc
    WHERE cc.CustomerContactEmail = @LoggedInUserEmail
        ORDER BY cc.CustomerContactId ASC;   /* deterministic pick when the e-mail is duplicated - same rule as GetCustomerPortalContactByEmail */

-- Fallback: internal staff account mapped to a customer
IF @CustomerId IS NULL
BEGIN
    SELECT TOP 1 @CustomerId = d.CustomerId
    FROM dbo.GetSourceFilterByEmail(@LoggedInUserEmail) AS d;
END

SELECT c.[CustomerContactId]
      ,c.[CustomerId]
      ,c.[CustomerContactName]
      ,c.[CustomerContactPersonRole]
      ,c.[CustomerContactPhone]
      ,c.[CustomerContactAdditionalPhoneNumber]
      ,c.[CustomerContactEmail]
      ,c.[SourceId]
      ,s.[SourceDisplayName] AS [SourceName]
      ,c.[CustomerSiteId]
      ,c.[IsDeleted]
  FROM [dbo].[CustomerContacts] as c
  LEFT JOIN [dbo].[Source] as s ON c.[SourceId] = s.[SourceId]
  WHERE /*c.[IsDeleted] = 0 AND*/ c.CustomerId = @CustomerId

GO
/* ===== dbo.GetCustomerDashboardData ===== */
GO
/*
    dbo.GetCustomerDashboardData                                                   MBA-865
    ---------------------------------------------------------------------------------
    The חזרה צפויה column is labelled *expected* return, but the procedure was
    returning ActualReturnDate. It now returns ExpectedReturnDate, and only for in-house
    (lab) calibration - for on-site work there is nothing to return, so it is NULL.

    The output alias stays ActualReturnDate on purpose: the front end already binds to it,
    and renaming would break the screen for no gain.

    2026-08-31 - MBA-939: the caller is a SET of customers, not one.
    ---------------------------------------------------------------------------------
    An e-mail address is a contact of several customers in 3,684 cases. The old rule took the
    lowest CustomerContactId, which for davide@iscar.co.il landed on ישקר בע"מ - a row with zero
    devices - while his 31 devices sat under three other ישקר entities. The dashboard was empty
    for 181 such addresses.

    #CustomerOrdersIds is now filled from dbo.GetPortalCustomerIds, so every screen that reads it
    covers all the caller's companies at once. Everything downstream already filters through that
    temp table, so this is the only place the scope is decided.

    Two further changes inside the dynamic SQL:

      * IsLatestOrder partitions by CustomerId + SerialNumber, not SerialNumber alone. 10 of 3,819
        serials exist under more than one customer; over a union, partitioning on the serial alone
        keeps the newest order and silently drops the other company's device.
      * CustomerName is carried through to the output, so a manager can tell which company each
        row belongs to. The front end has to render it (MBA-940).

    @SourceId is removed. It was assigned from the contact row and never read.
*/
-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 26/02/2026
-- Description:	Get customer dashboad data
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[GetCustomerDashboardData]
@PageNumber AS INT = 1,                  -- Resulting page for pagination, starting in 1
@RowsOfPage AS INT = 50,                 -- Result page size
@OrderBy AS NVARCHAR(MAX) = 'CalibratioinDate',      -- OrderBy column
@OrderByAsc AS BIT = 0,                  -- OrderBy direction (ASC/DESC)
@LoggedInUserEmail NVARCHAR(100),
@GlobalSearch NVARCHAR(200) = NULL
AS

DROP TABLE IF EXISTS #CustomerOrdersIds
CREATE TABLE #CustomerOrdersIds
(
OrderWorkPlanId INT NOT NULL
)

/* MBA-939: every company this caller belongs to that holds devices - see dbo.GetPortalCustomerIds. */
INSERT #CustomerOrdersIds(OrderWorkPlanId)
SELECT wp.OrderWorkPlanId
FROM [dbo].[OrderWorkPlans] as wp
JOIN dbo.GetPortalCustomerIds(@LoggedInUserEmail) as mine ON mine.CustomerId = wp.[CustomerId]

DECLARE @sql NVARCHAR(MAX) =
CONCAT(
'
;WITH ds
AS
(
SELECT
COALESCE(clst.StatusDescriptionHEB,N'''+N'מחכה לכיול'+''') as DeviceStatus
,itm.ActualCalibrationDate as CalibratioinDate
,itm.NextCalibrationDate
,od.OrderWorkPlanId
,IIF(od.IsInHouse = 1,N'''+N'מעבדה'+''',N'''+N'לקוח'+''') as CalibratioinLocation
,pt.OrdersProductTypeName as DeviceDescription
,itm.SerialNumber
,IIF(od.IsInHouse = 1, itm.ExpectedReturnDate, NULL) as ActualReturnDate
,od.CalibratorId
,u.FirstName as CalibratorFirstName
,u.LastName as CalibratorLastName
,u.Phone as CalibratorPhoneNumber
,ctwp.AssigmentDate as CalibratorAssigmentDate
,c.CustomerName as CustomerName
,ROW_NUMBER() OVER( PARTITION BY wp.[CustomerId], itm.SerialNumber ORDER BY wp.OrderWorkPlanId DESC) as IsLatestOrder
FROM
[dbo].[OrderWorkPlans] as wp
JOIN #CustomerOrdersIds as f ON wp.OrderWorkPlanId = f.OrderWorkPlanId
JOIN [dbo].[OrderDetails] as od ON wp.OrderWorkPlanId = od.OrderWorkPlanId
LEFT JOIN [dbo].[OrderDetailsItems] as itm ON itm.OrderDetailId = od.OrderDetailId
LEFT JOIN [dbo].[Customers] as c ON wp.[CustomerId] = c.[CustomerId]
LEFT JOIN [dbo].[Statuses] as clst ON itm.[CalibrationStatusId] = clst.[StatusId]
LEFT JOIN [dbo].[MainCategories] as mcf ON od.MainCategoryId	= mcf.ID
LEFT JOIN [dbo].[Users] as u ON od.CalibratorId = u.[ID]
LEFT JOIN [dbo].[CalibratorsToWorkPlan] as ctwp ON ctwp.[OrderWorkPlanId] = wp.[OrderWorkPlanId] AND ctwp.[CalibratorId] = od.CalibratorId AND ctwp.IsDeleted = 0
LEFT JOIN [dbo].[SecondaryCategories] as scf ON od.SecondaryCategoryId = scf.ID
LEFT JOIN [dbo].[CustomerSites] as css ON css.CustomerSiteId = od.CustomerSiteId
LEFT JOIN [dbo].[OrdersProductTypes] as pt ON od.OrdersProductTypeId = pt.OrdersProductTypeId
),
devices_cnt
AS
(
SELECT
COALESCE(NULLIF(d.DeviceStatus,N''''),N''לא ניתן לקבוע'') as DeviceStatus
,d.CalibratioinDate
,d.NextCalibrationDate
,d.CalibratioinLocation
,d.DeviceDescription
,d.SerialNumber
,d.ActualReturnDate
,d.CalibratorId
,d.CalibratorFirstName
,d.CalibratorLastName
,d.CalibratorPhoneNumber
,d.CalibratorAssigmentDate
,d.CustomerName
,d.IsLatestOrder
,SUM(IIF(d.IsLatestOrder = 1,1,NULL)) OVER( ORDER BY d.DeviceStatus) as OverallDevicesCount
,SUM(IIF(d.IsLatestOrder = 1 AND COALESCE(d.CalibratioinDate,''1900-01-01'') < GETDATE(),1,NULL)) OVER( ORDER BY d.DeviceStatus) as ExpiredevicesCount
,COALESCE(SUM(IIF(d.IsLatestOrder = 1 AND d.CalibratioinDate > GETDATE(),1,NULL)) OVER( ORDER BY d.DeviceStatus),0) as CalibratedDevicesCount
,COALESCE(SUM(IIF(d.IsLatestOrder = 1 AND d.DeviceStatus=N'''+N'מחכה לכיול'+''',1,NULL)) OVER( ORDER BY d.DeviceStatus),0) as DevicesWaitingForCalibrationCount
FROM ds as d
)
SELECT
 ds.DeviceStatus
,ds.CalibratioinDate
,ds.NextCalibrationDate
,ds.CalibratioinLocation
,ds.DeviceDescription
,ds.SerialNumber
,ds.ActualReturnDate
,ds.CalibratorId
,ds.CalibratorFirstName
,ds.CalibratorLastName
,ds.CalibratorPhoneNumber
,ds.CalibratorAssigmentDate
,ds.CustomerName
,ds.OverallDevicesCount
,ds.ExpiredevicesCount
,ds.CalibratedDevicesCount
,ds.DevicesWaitingForCalibrationCount
,SUM(IsLatestOrder) OVER( ORDER BY ds.DeviceStatus) as ItemsCount
FROM devices_cnt as ds
WHERE ds.IsLatestOrder = 1'
,CASE WHEN @GlobalSearch IS NOT NULL THEN ' AND CONCAT(ds.DeviceDescription,ds.SerialNumber,ds.CalibratorFirstName,ds.CalibratorLastName,ds.CalibratorPhoneNumber) LIKE N''%'+ @GlobalSearch +'%'''ELSE ' ' END
,'ORDER BY ' , @OrderBy , CASE WHEN @OrderByAsc = 1 THEN ' ASC' WHEN @OrderByAsc = 0 THEN ' DESC'  ELSE '' END , ' OFFSET ',(@PageNumber -1) * @RowsOfPage,' ROWS FETCH NEXT ', @RowsOfPage ,'ROWS ONLY OPTION(RECOMPILE); ')

EXEC (@sql)

GO
/* ===== dbo.GetCustomerDeviceDetail ===== */
GO
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

GO
/* ===== dbo.GetCustomerDeviceList ===== */
GO
-- =============================================
-- Proc:        dbo.GetCustomerDeviceList
-- Jira:        MBA-860 (parent MBA-859 "Wire Customer Device List to live data")
--              MBA-939 - union across every customer the caller belongs to.
-- Description: Returns ONE row per device for the logged-in caller (customer portal
--              Device List grid).
--
--              Filtering / sorting / search are done CLIENT-SIDE (per MBA-860), so this SP
--              returns the full, clean device set with no pagination.
--
-- 2026-08-31 - MBA-939: the caller is a SET of customers, not one.
--
--              An e-mail address is a contact of one customer far less often than we assumed:
--              3,684 addresses serve several. davide@iscar.co.il is a contact of 22 ישקר
--              entities. The old rule took the lowest CustomerContactId, which for him is
--              ישקר בע"מ - a row holding ZERO devices - while his 24 devices sit under
--              ישקר-מתק"ש-תפן. He saw an empty portal. 181 addresses were in that state.
--
--              Scoping now comes from dbo.GetPortalCustomerIds, which returns every customer
--              the address belongs to that actually holds devices. See that function for why
--              the device filter is there and not cosmetic.
--
--              @SelectedCustomerId is GONE. It was added in MBA-936 for a branch picker that
--              we decided not to build; a union needs no choice and therefore no parameter to
--              verify. Callers passing it will now fail loudly rather than be silently ignored.
--
-- NEW COLUMN:  customerName - which company each device belongs to. Without it a manager sees
--              devices from three Iscar divisions in one list with nothing to tell them apart.
--              The front end has to render it (MBA-940).
--
-- Output (13 columns):
--   id, deviceStatus, lastCalibration, nextCalibration, serialNumber, calibrationLocation,
--   deviceDescription, deviceManufacturer, deviceModel, sku, shippingMethod, lastReport,
--   customerName
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[GetCustomerDeviceList]
    @LoggedInUserEmail NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH devices AS
    (
        SELECT
             itm.OrderDetailsItemId                                                   AS id
            ,itm.CalibrationStatusId                                                  AS CalibrationStatusId
            ,st.StatusDescriptionENG                                                  AS StatusEng
            ,itm.ActualCalibrationDate                                                AS ActualCalibrationDate
            ,itm.NextCalibrationDate                                                  AS NextCalibrationDate
            ,itm.SerialNumber                                                         AS SerialNumber
            ,IIF(od.IsInHouse = 1, N'מעבדה', N'לקוח')                                  AS CalibrationLocation
            ,pt.OrdersProductTypeName                                                 AS DeviceDescription
            ,itm.OrdersDeviceManufacturer                                             AS DeviceManufacturer
            ,itm.DeviceModel                                                          AS DeviceModel
            ,itm.ManufacturerNumber                                                   AS Sku
            ,wp.ShipTypeDesc                                                          AS ShippingMethod
            ,itm.MbaReportNumber                                                      AS LastReport
            ,mine.CustomerName                                                        AS CustomerName
            /* MBA-939: partition by CUSTOMER + serial, not serial alone.
               10 of 3,819 serial numbers appear under more than one customer. Partitioning on
               the serial alone would keep the newest order and silently drop the other
               company's device from a list that now spans several companies. */
            ,ROW_NUMBER() OVER (PARTITION BY wp.CustomerId, itm.SerialNumber
                                ORDER BY wp.OrderWorkPlanId DESC)                     AS IsLatestOrder
        FROM dbo.GetPortalCustomerIds(@LoggedInUserEmail) AS mine
        JOIN [dbo].[OrderWorkPlans]      AS wp  ON wp.CustomerId        = mine.CustomerId
        JOIN [dbo].[OrderDetails]        AS od  ON od.OrderWorkPlanId   = wp.OrderWorkPlanId
        JOIN [dbo].[OrderDetailsItems]   AS itm ON itm.OrderDetailId    = od.OrderDetailId
        LEFT JOIN [dbo].[Statuses]           AS st ON st.StatusId            = itm.CalibrationStatusId
        LEFT JOIN [dbo].[OrdersProductTypes] AS pt ON pt.OrdersProductTypeId = od.OrdersProductTypeId
        WHERE wp.IsCancelled      = 0
          AND ISNULL(od.IsDeleted, 0)  = 0
          AND ISNULL(od.IsCancelled,0) = 0
          AND ISNULL(itm.IsDeleted, 0) = 0
          AND ISNULL(itm.IsCancelled,0)= 0
    )
    SELECT
         d.id
        ,CASE d.CalibrationStatusId
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
                    WHEN d.StatusEng IS NULL OR LEN(d.StatusEng) = 0 THEN NULL
                    ELSE LOWER(LEFT(REPLACE(d.StatusEng, '''', ''), 1))
                       + SUBSTRING(REPLACE(d.StatusEng, '''', ''), 2, 200)
                 END
         END                                                             AS deviceStatus
        ,CONVERT(VARCHAR(10), d.ActualCalibrationDate, 104)              AS lastCalibration
        ,CONVERT(VARCHAR(10), d.NextCalibrationDate,   104)              AS nextCalibration
        ,d.SerialNumber                                                  AS serialNumber
        ,d.CalibrationLocation                                           AS calibrationLocation
        ,d.DeviceDescription                                            AS deviceDescription
        ,d.DeviceManufacturer                                           AS deviceManufacturer
        ,d.DeviceModel                                                   AS deviceModel
        ,d.Sku                                                           AS sku
        ,d.ShippingMethod                                               AS shippingMethod
        ,d.LastReport                                                    AS lastReport
        ,d.CustomerName                                                  AS customerName
    FROM devices AS d
    WHERE d.IsLatestOrder = 1
    ORDER BY d.ActualCalibrationDate DESC
    OPTION (RECOMPILE);
END

GO
/* ===== dbo.GetCustomerInvoicesFromPriority ===== */
GO
CREATE OR ALTER PROCEDURE dbo.GetCustomerInvoicesFromPriority
    @LoggedInUserEmail NVARCHAR(100),
    /* MBA-936: the branch the caller chose, when their address serves several customers.
       Verified below - an unverified id is ignored rather than trusted, so this cannot be
       used to read another customer's data. */
    @SelectedCustomerId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @CustomerId INT, @Cust INT;
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
    SELECT TOP 1 @CustomerId = CustomerId FROM dbo.CustomerContacts
          WHERE CustomerContactEmail = @LoggedInUserEmail AND ISNULL(IsDeleted,0)=0
          ORDER BY CustomerContactId ASC   /* deterministic pick when the e-mail is duplicated - same rule as GetCustomerPortalContactByEmail */;
    SELECT @Cust = TRY_CONVERT(INT, CustomerIdFromSource) FROM dbo.Customers WHERE CustomerId=@CustomerId;
    IF @Cust IS NULL RETURN;
    SELECT iv.IVNUM AS invoiceNumber,
        CONVERT(varchar(10), DATEADD(MINUTE, iv.IVDATE, '1988-01-01'), 104) AS invoiceDate,
        iv.TOTPRICE AS totalPrice, iv.IVBALANCE AS balance,
        CAST(CASE WHEN iv.IVBALANCE = 0 THEN 1 ELSE 0 END AS bit) AS isPaid
    FROM [31.168.173.93].amaba.dbo.INVOICES AS iv
    WHERE iv.CUST = @Cust
    ORDER BY iv.IVDATE DESC;
END
GO
/* ===== dbo.GetCustomerInvoicesQuotes ===== */
GO
-- =============================================
-- Proc:        dbo.GetCustomerInvoicesQuotes
-- Jira:        MBA-797 (Customer Invoice/Quotes page — customer/invoice)
-- Description: Customer-portal Invoices/Quotes grid (screen has two tabs: "quotes" and
--              "invoices"). Identity input matches the other customer-portal SPs
--              (@LoggedInUserEmail -> CustomerId via dbo.CustomerContacts) and is scoped
--              to the calling customer only, consistent with dbo.GetCustomerDashboardData
--              / dbo.GetCustomerDeviceList.
--
--              *** PARTIAL / SCAFFOLD — see the "BLOCKED" note below. ***
--              The Calibrator DB holds calibration ORDERS with per-line pricing
--              (OrderDetails.PRICE = net, OrderDetails.VPRICE = VAT-inclusive), but it does
--              NOT hold billing/financial DOCUMENTS. It has no invoice numbers, no quote
--              numbers, no discount amounts, and no "paid by" party. Those live in the
--              Priority ERP and are not synced into Calibrator on STAGE:
--                  - OrderWorkPlans.BK_DOC_N is 100% NULL (0 distinct values on STAGE).
--                  - There is no Quotes / Invoices / Discount / Payments table.
--              This SP therefore returns one row per calibration order with the fields that
--              ARE legitimately available, and returns NULL for every field that must come
--              from Priority. It does NOT fabricate invoice/quote numbers or discounts.
--
--              There is also no data in Calibrator to split rows into "quotes" vs
--              "invoices"; @DocType is accepted for forward-compatibility but currently only
--              affects nothing (all rows are order-derived). FE tabs can filter later once
--              the Priority-sourced document type exists.
--
-- Output columns (superset covering both FE tabs; camelCase to match FE Raw* row types):
--   id, orderNumber, date, invoiceNumber, invoiceDate, quoteNumber,
--   price, discount, finalPrice, paidBy
--     * date / invoiceDate -> DD.MM.YYYY (CONVERT style 104) from WorkPlanOpenDate.
--     * price              -> SUM(OrderDetails.PRICE)  net, per order, 2dp string.
--     * finalPrice         -> SUM(OrderDetails.VPRICE) VAT-inclusive, per order, 2dp string.
--                             (NOTE: this is VAT-inclusive total, NOT a post-discount final;
--                              a true finalPrice needs the Priority discount — see BLOCKED.)
--     * invoiceNumber / invoiceDate / quoteNumber / discount / paidBy -> NULL (Priority ERP).
--
-- REVIEW / OPEN QUESTION (Ariel / Dako): confirm whether the Invoices/Quotes screen should
--   be sourced from a Priority sync (invoice/quote documents, discounts, paid-by) rather
--   than from Calibrator orders. If yes, this screen is blocked on that sync; if the intent
--   is "order pricing" only, drop the invoice/quote/discount/paidBy columns from the design.
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[GetCustomerInvoicesQuotes]
    @LoggedInUserEmail NVARCHAR(50),
    @DocType           VARCHAR(10) = NULL   -- reserved: 'quotes' | 'invoices' (no source yet)
    /* MBA-936: the branch the caller chose, when their address serves several customers.
       Verified below - an unverified id is ignored rather than trusted. */
   ,@SelectedCustomerId INT = NULL
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

    ;WITH orderTotals AS
    (
        SELECT
             wp.OrderWorkPlanId
            ,wp.OrderNumber
            ,wp.WorkPlanOpenDate
            ,SUM(ISNULL(od.PRICE, 0))  AS NetTotal
            ,SUM(ISNULL(od.VPRICE, 0)) AS VatTotal
        FROM [dbo].[OrderWorkPlans] AS wp
        JOIN [dbo].[OrderDetails]   AS od ON od.OrderWorkPlanId = wp.OrderWorkPlanId
        WHERE wp.CustomerId          = @CustomerId
          AND wp.IsCancelled         = 0
          AND ISNULL(od.IsDeleted, 0)  = 0
          AND ISNULL(od.IsCancelled,0) = 0
        GROUP BY wp.OrderWorkPlanId, wp.OrderNumber, wp.WorkPlanOpenDate
    )
    SELECT
         ot.OrderWorkPlanId                                        AS id
        ,ot.OrderNumber                                            AS orderNumber
        ,CONVERT(VARCHAR(10), ot.WorkPlanOpenDate, 104)           AS date
        ,CAST(NULL AS NVARCHAR(50))                                AS invoiceNumber   -- Priority ERP (not in Calibrator)
        ,CONVERT(VARCHAR(10), ot.WorkPlanOpenDate, 104)           AS invoiceDate     -- placeholder = order date; real invoice date is Priority
        ,CAST(NULL AS NVARCHAR(50))                                AS quoteNumber     -- Priority ERP (not in Calibrator)
        ,CONVERT(VARCHAR(20), CAST(ot.NetTotal AS DECIMAL(18,2)))  AS price           -- net
        ,CAST(NULL AS NVARCHAR(20))                                AS discount        -- Priority ERP (not in Calibrator)
        ,CONVERT(VARCHAR(20), CAST(ot.VatTotal AS DECIMAL(18,2)))  AS finalPrice      -- VAT-inclusive total (see header note)
        ,CAST(NULL AS NVARCHAR(100))                               AS paidBy          -- Priority ERP (not in Calibrator)
    FROM orderTotals AS ot
    ORDER BY ot.WorkPlanOpenDate DESC
    OPTION (RECOMPILE);
END

GO
/* ===== dbo.GetCustomerProfile ===== */
GO
-- =============================================
-- Author:      Claude (subagent)
-- Create date: 04/08/2026
-- Description: Returns the customer profile / main-site header for the
--              logged-in customer user (screen: customer/profile, MBA-612).
--              Customer-scoped: @CustomerId is resolved from dbo.CustomerContacts
--              by @LoggedInUserEmail (same convention as GetCustomerDashboardData),
--              with a fallback to dbo.Users so support/portal logins also resolve.
--              Returns a single header row. The sub-sites list and the MABA
--              contact cards on the same screen are served by the existing
--              GetCustomerSites / GetCustomerContacts / GetCustomerSupportData SPs
--              and are intentionally NOT duplicated here.
-- JiraLink:    MBA-612
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[GetCustomerProfile]
    @LoggedInUserEmail NVARCHAR(50),
    /* MBA-936: the branch the caller chose, when their address serves several customers.
       Verified below - an unverified id is ignored rather than trusted, so this cannot be
       used to read another customer's data. */
    @SelectedCustomerId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @CustomerId INT = NULL;

    -- Primary resolution: portal contact login
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
    SELECT TOP 1 @CustomerId = cc.CustomerId
        FROM dbo.CustomerContacts AS cc
        WHERE cc.CustomerContactEmail = @LoggedInUserEmail
        ORDER BY cc.CustomerContactId ASC;   /* deterministic pick when the e-mail is duplicated - same rule as GetCustomerPortalContactByEmail */

    -- Fallback: user account login (support / staff mapped to a customer)
    IF @CustomerId IS NULL
    BEGIN
        SELECT TOP 1 @CustomerId = u.CustomerId
        FROM dbo.Users AS u
        WHERE u.Email = @LoggedInUserEmail;
    END

    SELECT
         c.CustomerId
        ,c.CustomerCode                                              AS SiteNumber
        ,c.CustomerName                                             AS MainSiteName
        ,c.CustomerNameENG                                          AS MainSiteNameENG
        ,c.CustomerName                                             AS AccountName
        ,c.CustomerNameENG                                          AS AccountNameENG
        -- No dedicated report-language column exists; report output preference
        -- is currently a UI toggle. Returned NULL so FE can default to 'he'.
        ,CAST(NULL AS NVARCHAR(2))                                  AS ReportLanguage
        ,LTRIM(RTRIM(
            CONCAT(
                c.CustomerAddress,
                CASE WHEN NULLIF(LTRIM(RTRIM(c.CustomerCity)), '') IS NOT NULL
                     THEN N', ' + c.CustomerCity ELSE N'' END
            )))                                                    AS SiteAddress
        ,LTRIM(RTRIM(
            CONCAT(
                c.CustomerAddressENG,
                CASE WHEN NULLIF(LTRIM(RTRIM(c.CustomerCityENG)), '') IS NOT NULL
                     THEN N', ' + c.CustomerCityENG ELSE N'' END
            )))                                                    AS SiteAddressENG
        ,c.CustomerPhone                                           AS SitePhone
        ,c.ReportRequired                                          AS ReportRequired
        ,c.ShipTypeDescr                                           AS ShippingMethod
        ,c.SignatureAmount                                         AS SignatureAmount
        -- Count of sub-sites so FE can show/toggle "all sites"; the list itself
        -- comes from GetCustomerSites.
        ,(SELECT COUNT(*) FROM dbo.CustomerSites AS s
          WHERE s.CustomerId = c.CustomerId AND s.IsDeleted = 0)   AS SubSitesCount
    FROM dbo.Customers AS c
    WHERE c.CustomerId = @CustomerId
      AND c.IsDeleted = 0;
END

GO
/* ===== dbo.GetCustomerQuotesFromPriority ===== */
GO
CREATE OR ALTER PROCEDURE dbo.GetCustomerQuotesFromPriority
    @LoggedInUserEmail NVARCHAR(100),
    /* MBA-936: the branch the caller chose, when their address serves several customers.
       Verified below - an unverified id is ignored rather than trusted, so this cannot be
       used to read another customer's data. */
    @SelectedCustomerId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @CustomerId INT, @Cust INT;
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
    SELECT TOP 1 @CustomerId = CustomerId FROM dbo.CustomerContacts
          WHERE CustomerContactEmail = @LoggedInUserEmail AND ISNULL(IsDeleted,0)=0
          ORDER BY CustomerContactId ASC   /* deterministic pick when the e-mail is duplicated - same rule as GetCustomerPortalContactByEmail */;
    SELECT @Cust = TRY_CONVERT(INT, CustomerIdFromSource) FROM dbo.Customers WHERE CustomerId=@CustomerId;
    IF @Cust IS NULL RETURN;
    SELECT cp.CPROFNUM AS quoteNumber,
        CONVERT(varchar(10), DATEADD(MINUTE, cp.PDATE, '1988-01-01'), 104) AS quoteDate,
        CONVERT(varchar(10), DATEADD(MINUTE, NULLIF(cp.EXPIRYDATE,0), '1988-01-01'), 104) AS validUntil,
        cp.TOTPRICE AS totalPrice, cp.DISPRICE AS finalPrice,
        (cp.TOTPRICE - cp.DISPRICE) AS discount, cp.CPROFSTAT AS statusCode
    FROM [31.168.173.93].amaba.dbo.CPROF AS cp
    WHERE cp.CUST = @Cust
    ORDER BY cp.PDATE DESC;
END
GO
/* ===== dbo.GetCustomerRequests ===== */
GO
-- =============================================
-- Proc:        dbo.GetCustomerRequests
-- Jira:        MBA-858 (Customer Support — customer-inquiry / requests list + action modals)
-- Description: Read SP that backs the customer-portal "requests / inquiries" list shown in the
--              Customer Support area (FE: components/customers/QuotesDialog.tsx, mock MOCK_QUOTES,
--              row shape TQuoteRow in components/customers/constants/quotes-dialog.ts). Returns one
--              row per calibration order (OrderWorkPlan) belonging to the logged-in customer — an
--              order IS the "request/quote" the customer submitted and that the 4 action modals
--              (cancel calibration / devices deleted / order for shipping / reject request) act on.
--
--              Identity + scoping follow the other customer-portal SPs
--              (@LoggedInUserEmail -> CustomerId via dbo.CustomerContacts), consistent with
--              dbo.GetCustomerDashboardData / dbo.GetCustomerDeviceList. Filtering / sorting are
--              done client-side (TanStack table), so the full clean set is returned, no paging.
--
-- Output columns (camelCase, exactly matching FE TQuoteRow):
--   status, quoteNumber, deviceCount, expectedCalibrationDate, calibrationLocation, price, note
--     * status                 -> FE quoteStatuses code. Sourced from the OrderStatus category
--                                 (StatusesCategories.StatusCategoryId = 9) via
--                                 COALESCE(wp.OrderStatusId, wp.OrderOverallStatusId). The 4 codes
--                                 the FE combobox styles are mapped explicitly; any other status
--                                 falls back to a lower-camel of StatusDescriptionENG (same pattern
--                                 as GetCustomerDeviceList).
--                                   66 Sent                -> 'sent'
--                                   72 Rejected            -> 'rejected'
--                                   73 AwaitingConfirmation -> 'waitingForCustomer'
--                                   76 WaitingForCalibration-> 'waitingForCalibration'
--     * quoteNumber            -> wp.OrderNumber.
--     * deviceCount            -> COUNT of non-deleted OrderDetailsItems in the order.
--     * expectedCalibrationDate-> DD.MM.YYYY (CONVERT 104) — MIN(OrderDetailsItems.NextCalibrationDate).
--     * calibrationLocation    -> 'lab' if any order line IsInHouse=1, else 'customer' (NULL if no lines).
--     * price                  -> SUM(OrderDetails.PRICE) net, DECIMAL(18,2) (NULL if none).
--     * note                   -> wp.Notes (fallback wp.CustomerComment).
--
-- NOTE for review (Ariel / Dako) — best-guess mappings, please confirm:
--   * status: STAGE has wp.OrderStatusId 100% NULL and wp.OrderOverallStatusId = 76 for every
--     order, so every row currently returns 'waitingForCalibration'. The id->FE-code map above is
--     the assumed lifecycle; confirm which OrderStatus ids represent sent / rejected / waiting-for-
--     customer once real status data flows in.
--   * expectedCalibrationDate: no dedicated column exists — using earliest item NextCalibrationDate.
--     Alt candidates: wp.WorkPlanOpenDate, OrderDetails.ActualCalibrationDate.
--   * price: net (PRICE). Alt: VPRICE (VAT-inclusive), as used by dbo.GetCustomerInvoicesQuotes.
--   Write actions (cancel calibration / devices deleted / order for shipping / reject request) are
--   OUT OF SCOPE here and tracked as separate follow-ups — see the Jira ticket.
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[GetCustomerRequests]
    @LoggedInUserEmail NVARCHAR(50),
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

    ;WITH req AS
    (
        SELECT
             wp.OrderWorkPlanId
            ,wp.OrderNumber
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
        FROM [dbo].[OrderWorkPlans] AS wp
        WHERE wp.CustomerId  = @CustomerId
          AND wp.IsCancelled = 0
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
    FROM req AS r
    LEFT JOIN [dbo].[Statuses] AS st
           ON st.StatusId = r.StatusId
          AND st.StatusCategoryId = 9      -- OrderStatus category
    ORDER BY r.OrderWorkPlanId DESC
    OPTION (RECOMPILE);
END

GO
/* ===== dbo.GetCustomerShipments ===== */
GO
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
    @LoggedInUserEmail NVARCHAR(50),
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

GO
/* ===== dbo.GetCustomerSites ===== */
GO
-- =============================================
-- Author:      Eduard Kudlaiev
-- Create date: 04/05/2026
-- Description: Sites (sub-sites) of the customer the caller belongs to.
--              Used by the internal customer-management screen AND by the customer
--              portal profile screen.
--
-- 2026-08-30 ג€” FIX: portal users could not resolve.
--
--              Identical defect to GetCustomerContacts: the customer was resolved only
--              through dbo.GetSourceFilterByEmail, a table-valued function over
--              dbo.Users. A portal user lives in dbo.CustomerContacts and has no Users
--              row, so the function returned no rows, @CustomerId stayed NULL, and
--              `WHERE cs.CustomerId = @CustomerId` was always false.
--
--              Now: resolve from dbo.CustomerContacts first, fall back to the function,
--              so the internal screen is unaffected.
--
--              The SELECT list is unchanged; no caller needs to change.
-- JiraLink:
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[GetCustomerSites]
@LoggedInUserEmail NVARCHAR(100),
    /* MBA-936: the branch the caller chose, when their address serves several customers.
       Verified below - an unverified id is ignored rather than trusted, so this cannot be
       used to read another customer's data. */
    @SelectedCustomerId INT = NULL
AS

SET NOCOUNT ON;

DECLARE @CustomerId INT = NULL;

-- Primary resolution: portal contact login
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
    SELECT TOP 1 @CustomerId = cc.CustomerId
    FROM dbo.CustomerContacts AS cc
    WHERE cc.CustomerContactEmail = @LoggedInUserEmail
        ORDER BY cc.CustomerContactId ASC;   /* deterministic pick when the e-mail is duplicated - same rule as GetCustomerPortalContactByEmail */

-- Fallback: internal staff account mapped to a customer
IF @CustomerId IS NULL
BEGIN
    SELECT TOP 1 @CustomerId = d.CustomerId
    FROM dbo.GetSourceFilterByEmail(@LoggedInUserEmail) AS d;
END

SELECT cs.[CustomerId]
      ,cs.[CustomerSiteId]
      ,cs.[CustomerSiteAddress]
      ,cs.[CustomerSiteState]
      ,cs.[CustomerSiteZIP]
      ,cs.[CustomerSitePhone]
      ,cs.[CustomerSiteDescription]
      ,cs.[CustomerSiteCode]
      ,cs.[CreateDate]
      ,cs.[UpdatedDate]
      ,cs.[UpdateUserID]
      ,cs.[SourceId]
      ,s.[SourceDisplayName] AS [SourceName]
      ,cs.[CustomerSiteAddressENG]
      ,cs.[CustomerSiteStateENG]
      ,cs.[CustomerSiteDescriptionENG]
      ,cs.[IsDeleted]
  FROM [dbo].[CustomerSites] as cs
  LEFT JOIN [dbo].[Source] as s ON cs.[SourceId] = s.[SourceId]
  WHERE /*cs.[IsDeleted] = 0 AND */cs.CustomerId = @CustomerId

GO
/* ===== dbo.GetCustomerSupportData ===== */
GO
-- =============================================
-- Author:      Eduard Kudlaiev
-- Create date: 10/03/2026
-- Description: The MABA account manager shown on the customer portal dashboard
--              ("׳©׳¨׳•׳× ׳׳§׳•׳—׳•׳× ׳׳‘\"׳" card). One employee per customer.
--
-- 2026-08-30 ג€” FIX: the customer was resolved from dbo.Users only.
--
--              Portal users are CUSTOMER CONTACTS, not staff accounts, so that lookup
--              could not work: of the 2,070 rows in dbo.CustomerContacts exactly one
--              appears in dbo.Users, and none of them carry a CustomerId there. The
--              variable therefore came back NULL and the final predicate
--              `WHERE c.CustomerId = @CustomerId` was always false ג€” the card was empty
--              for every portal user since the day it was written.
--
--              Now resolved from dbo.CustomerContacts first, falling back to dbo.Users,
--              which is the same convention GetCustomerProfile, GetCustomerDashboardData
--              and GetCustomerDeviceList already use. This SP was the only one in the
--              portal set that did not.
--
--              Output columns are unchanged, so the front end needs no change.
-- =============================================
CREATE OR ALTER PROCEDURE [dbo].[GetCustomerSupportData]
    @LoggedInUserEmail NVARCHAR(50),
    /* MBA-936: the branch the caller chose, when their address serves several customers.
       Verified below - an unverified id is ignored rather than trusted, so this cannot be
       used to read another customer's data. */
    @SelectedCustomerId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @CustomerId INT = NULL;

    -- Primary resolution: portal contact login
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
    SELECT TOP 1 @CustomerId = cc.CustomerId
        FROM dbo.CustomerContacts AS cc
        WHERE cc.CustomerContactEmail = @LoggedInUserEmail
        ORDER BY cc.CustomerContactId ASC;   /* deterministic pick when the e-mail is duplicated - same rule as GetCustomerPortalContactByEmail */

    -- Fallback: user account login (support / staff mapped to a customer)
    IF @CustomerId IS NULL
    BEGIN
        SELECT TOP 1 @CustomerId = u.CustomerId
        FROM dbo.Users AS u
        WHERE u.Email = @LoggedInUserEmail;
    END

    IF @CustomerId IS NULL
        RETURN;

    SELECT
         u.FirstName
        ,u.LastName
        ,u.Email
        ,u.Phone
    FROM dbo.Customers AS c
    JOIN dbo.Users     AS u ON u.ID = c.CustomerSupportContactId
    WHERE c.CustomerId = @CustomerId;
END

GO
/* ===== dbo.GetWorkPlanData ===== */
GO
-- =============================================
-- Proc:        dbo.GetWorkPlanData
-- Jira:        MBA — "אישור תיאום כיול ע"י הלקוח" (order-approval by e-mail)
-- Description: Verbatim copy of the live dbo.GetWorkPlanData with ONE behavioural change:
--              the fallback ClientConfirmationStatus for orders whose
--              OrderWorkPlans.ClientConfirmationStatusId is NULL is now 'New' (חדש)
--              instead of 'Pending' (ממתין).
--
--              Why: 'Pending' now means "a coordination e-mail was sent and we are waiting
--              for the customer to answer" — it is the status that triggers the mail. Orders
--              that arrived from the Priority sync and were never sent to the customer must
--              not look pending; they are 'New'. (On STG that is ~990 of ~997 orders.)
--
--              Requires dbo.ClientConfirmationStatus.New.seed.sql to have run first, otherwise
--              @ClientConfirmationStatusDefault resolves to NULL.
--
-- Everything below this header is the live definition as of the change, only
-- CREATE OR ALTER PROCEDURE -> CREATE OR ALTER PROCEDURE and the one WHERE line differ.
-- =============================================
-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 03/04/2025
-- Description:	Get work plan data
-- =============================================
CREATE   PROCEDURE [dbo].[GetWorkPlanData]
    @PageNumber AS INT = 1,                  -- Resulting page for pagination, starting in 1
    @RowsOfPage AS INT = 50,                 -- Result page size
    @OrderBy AS NVARCHAR(MAX) = 'OrderWorkPlanId',      -- OrderBy column
    @OrderByAsc AS BIT = 1,                  -- OrderBy direction (ASC/DESC)
    -- Filter parameters (all nullable)
	@ClientName NVARCHAR(255) = NULL,
	@Date DATE = NULL,
	@MainCategory NVARCHAR(100) = NULL,
	@SecondCategory NVARCHAR(100) = NULL,
	@Location NVARCHAR(100) = NULL,
	@ProductType NVARCHAR(100) = NULL,
	@ProducedIn NVARCHAR(255) = NULL,
	@DeviceModel NVARCHAR(100) = NULL,
	@DateFrom DATETIME2(0) = NULL,
	@DateTo DATETIME2(0) = NULL,
	@DeviceNumber NVARCHAR(20) = NULL,
	@DeviceManufacturer NVARCHAR(255) = NULL,
	@AssignedCalibratorsIds NVARCHAR(MAX) = NULL, -- -1 means that we should include orders with empty calibrator
	@EquipmentIds NVARCHAR(MAX) = NULL,
	@SpecialCareTypeIds NVARCHAR(255) = NULL,
	@OrderNumber NVARCHAR(MAX) = NULL,
	@GlobalSearch NVARCHAR(200) = NULL,
	@WorkPlanOpenDate DATETIME2(0) = NULL,
	@CarsIds NVARCHAR(MAX) = NULL,
	@Notes NVARCHAR(255) = NULL,
	@Page NVARCHAR(100),
	@LoggedInUserEmail NVARCHAR(50) = NULL,
	@ExcludeRejectedOrders BIT = 0,
	@ClientId INT = NULL,
	-- MBA-806/filter fix: the "קוד לקוח" field is Customers.CustomerCode (NVARCHAR, can be
	-- alphanumeric e.g. 'T005585') and is NOT Customers.CustomerId. Prefer this parameter.
	@ClientCode NVARCHAR(50) = NULL
AS

BEGIN
    SET NOCOUNT ON;
	SET ANSI_WARNINGS OFF;

	/* ---------------------------------------------------------------------------------
	   Customer filter resolution (MBA: "קוד לקוח" returned the wrong customer / no rows).
	   Customers has THREE different ids and their ranges overlap:
	     CustomerId           - local surrogate key, what OrderWorkPlans.CustomerId points at
	     CustomerIdFromSource - Priority CUST
	     CustomerCode         - the HP / קוד לקוח the user types on screen
	   Example: code 877 = 'אלכם מדיקל' (CustomerId 4428), while CustomerId 877 is a
	   different company ('פינקלמן') with no work plans - so filtering by the typed code
	   against CustomerId silently returned an empty screen.
	   @ClientCode is the correct input. @ClientId is kept for back-compat and is resolved
	   as a CODE first (that is what the UI sends today), falling back to a real CustomerId.
	   --------------------------------------------------------------------------------- */
	DECLARE @ResolvedCustomerId INT = NULL;

	IF @ClientCode IS NOT NULL
	BEGIN
		SELECT TOP (1) @ResolvedCustomerId = c.CustomerId
		FROM dbo.Customers AS c
		WHERE c.CustomerCode = @ClientCode AND ISNULL(c.IsDeleted, 0) = 0;

		IF @ResolvedCustomerId IS NULL SET @ResolvedCustomerId = -1;  -- unknown code -> no rows
	END
	ELSE IF @ClientId IS NOT NULL
	BEGIN
		SELECT TOP (1) @ResolvedCustomerId = c.CustomerId
		FROM dbo.Customers AS c
		WHERE c.CustomerCode = CAST(@ClientId AS NVARCHAR(20)) AND ISNULL(c.IsDeleted, 0) = 0;

		IF @ResolvedCustomerId IS NULL SET @ResolvedCustomerId = @ClientId;  -- treat as a real CustomerId
	END

	DECLARE @LoggedInUserId INT = 0
	DECLARE @SourceId TINYINT

	SELECT 
	 @LoggedInUserId  = d.UserId 
	,@SourceId = d.SourceId
	FROM dbo.GetSourceFilterByEmail(@LoggedInUserEmail) as d

	/*
	Filter logic by page
	/coordinator-orders - @page = ‘coordinator-orders’ 
	/external-schedule - @page = ‘external-schedule’
	/internal-orders - @page = ‘internal-orders’
	/calibration-wizard - @page = ‘calibration-wizard’ 
	/external-orders - @page = 'external-orders'
	*/
	/*-------------------------------------------------*/
	/* MBA-902 / MBA-293 AC1: "As soon as Calibrator finishes calibration and generates the report,
	   the Validator should see the calibration validation screen." The validator pages had no status
	   filter at all - internal-validator, external-validator and internal-orders returned an
	   identical 500 rows - so the screen listed orders that had not been calibrated yet, which is
	   why every CRM-sourced column on it came back empty.
	   MBA-293 AC1 is "finishes calibration AND GENERATES THE REPORT", and the report number is the
	   report - so a device belongs on the validator screen once it HAS one. That is the test used
	   below, and it is the only one that holds up in the data: CalibrationStatusId is set on 91 of
	   3,823 items, and 3,470 of the 3,471 items carrying a real report number have no calibration
	   status at all. Filtering on the status instead produced 49 orders of which 43 showed a blank
	   report number, which is the opposite of what the screen is for.
	   The status list is kept here for when the lifecycle is actually maintained. */
	DECLARE @ValidatorDeviceStatuses NVARCHAR(200) = N'29,32,33,34,35,36,37,38'
	/* The eight device statuses the design actually defines - Figma node 5429-395, the legend MBA-293
	   links. In screen order: 37 ממתין לכיול, 38 כיול, 36 ממתין לחתימה, 35 ממתין להערות,
	   34 לא ניתן לקבוע, 32 נבדק עומד, 33 נבדק - לא עומד, 29 מוכן לאריזה.

	   23 CalibrationSuccess (כיול הצליח) is NOT one of them and was wrongly listed here before. It is
	   also the status the system writes most: of the 90 items that carry any calibration status,
	   71 are 23, 16 are 33 and 3 are 32. Every other status in the category, including five of the
	   eight the design defines, has never been written once.

	   Note the near-duplicate pairs in dbo.Statuses: the design's ממתין לכיול and כיול are 37 and 38,
	   while 19 WaitingForCalibration and 20 InCalibration say the same thing and are what the
	   front-end constant maps to. Both pairs are unused, so nothing depends on the answer yet. */

	DECLARE @ExtIntFilter BIT = NULL

	/* MBA-902: external-validator and internal-validator were in neither list, so both pages
	   returned the same rows. The mechanism was already here and coordinator-orders uses it -
	   od.IsInHouse is the internal/external definition in this system. */
	IF @Page IN (N'external-schedule',N'external-orders',N'coordinator-orders',N'external-validator') SET @ExtIntFilter = 0 -- IsInHouse = 0 for external orders

	IF @Page IN (N'internal-orders',N'internal-validator') SET @ExtIntFilter = 1 -- IsInHouse = 1 for internal orders
	--validator-orders
	/*-------------------------------------------------*/

	--IF @OrderBy NOT IN 
	--(N'OrderNumber',N'SpecialCares',N'ClientName',N'Location',N'WorkPlanOpenDate',
	--N'Cars',N'Calibrators',N'EquipmentNames',N'Notes',N'MainCategory',N'CalibDate',N'ClientConfirmationStatus',N'ExpectedReturnDate',
	--N'ActualReturnDate',N'CustomerPackingExists',N'PrintedReport',N'ReceivingDate',N'WorkPlanStatus')
	--THROW 51000, 'Incorrect value for parameter @OrderBy. Available values |OrderNumber|SpecialCares|ClientName|
	--ExpectedReturnDate|ActualReturnDate
	--|Location|WorkPlanOpenDate|Cars|Calibrators|EquipmentNames|Notes|MainCategory|CalibDate|ClientConfirmationStatus', 1;

	/* MBA-902: the sparse CRM columns. Sorting one of them ascending put every empty row first, so
	   the screen opened on nothing but dashes even though values exist further down - 6 of 38 rows
	   carry a report number and 11 carry the return dates. Rows that HAVE a value now always come
	   first and the requested direction orders them, the same treatment Cars, Calibrators and
	   EquipmentNames already get below.
	   The expressions are repeated rather than referenced by alias: ORDER BY may use a select-list
	   alias on its own, but not wrapped inside IIF, and CalibratorMabaNumber is a correlated
	   subquery rather than a plain column. */
	DECLARE @SortExpr NVARCHAR(MAX) = NULL

	IF @OrderBy = N'CalibratorMabaNumber' SET @SortExpr = N'(SELECT MIN(i9.MbaReportNumber) FROM [dbo].[OrderDetailsItems] as i9 JOIN [dbo].[OrderDetails] as od9 ON od9.OrderDetailId = i9.OrderDetailId WHERE od9.OrderWorkPlanId = wp.[OrderWorkPlanId] AND ISNULL(od9.IsDeleted,0) = 0 AND ISNULL(i9.IsDeleted,0) = 0 AND i9.MbaReportNumber LIKE ''[0-9][0-9][0-9][0-9][0-9][0-9][0-9]/%'')'
	IF @OrderBy = N'ExpectedReturnDate'   SET @SortExpr = N'MAX(itm.ExpectedReturnDate)'
	IF @OrderBy = N'ActualReturnDate'     SET @SortExpr = N'MAX(itm.ActualReturnDate)'

	IF @SortExpr IS NOT NULL
	BEGIN
		SET @OrderBy = CONCAT(N'IIF(', @SortExpr, N' IS NULL,1,0) ASC, ', @SortExpr, N' ',
		                      CASE WHEN @OrderByAsc = 0 THEN N'DESC' ELSE N'ASC' END)
		SET @OrderByAsc = NULL
	END

	IF @OrderBy IN (N'Cars')
		BEGIN
		SET @OrderBy = CONCAT(N'IIF([Cars] IS NULL,0,1) ',CASE WHEN @OrderByAsc = 1 THEN ' ASC' WHEN @OrderByAsc = 0 THEN ' DESC'  ELSE '' END ,N' ,IIF([Calibrators] IS NULL,0,1)', N' ,IIF([EquipmentNames] IS NULL,0,1)')

		SET @OrderByAsc = NULL
		END

	IF @OrderBy IN (N'Calibrators')
		BEGIN
		SET @OrderBy = CONCAT(N' IIF([Cars] IS NULL,0,1) DESC',N' ,IIF([Calibrators] IS NULL,0,1) ',CASE WHEN @OrderByAsc = 1 THEN ' ASC' WHEN @OrderByAsc = 0 THEN ' DESC'  ELSE '' END , N' ,IIF([EquipmentNames] IS NULL,0,1)')

		SET @OrderByAsc = NULL
		END

	IF @OrderBy IN (N'EquipmentNames')
		BEGIN
		SET @OrderBy = CONCAT(N' IIF([Cars] IS NULL,0,1) DESC',N' ,IIF([Calibrators] IS NULL,0,1) DESC', N' ,IIF([EquipmentNames] IS NULL,0,1)',CASE WHEN @OrderByAsc = 1 THEN ' ASC' WHEN @OrderByAsc = 0 THEN ' DESC'  ELSE '' END )

		SET @OrderByAsc = NULL
		END	
    /*Apply filter by orders on external order page to get only orders assigned by calibrator for specific date*/
	DECLARE @FilterExternalOrdersForCalibrator BIT = 0
    IF @Page = N'external-orders' AND @DateFrom IS NOT NULL AND @DateTo IS NOT NULL
		BEGIN
			SET @FilterExternalOrdersForCalibrator = 1

			DROP TABLE IF EXISTS #FilterExternalOrdersForCalibrator
			CREATE TABLE #FilterExternalOrdersForCalibrator
			(
			[OrderWorkPlanId] INT
			)
			INSERT #FilterExternalOrdersForCalibrator([OrderWorkPlanId])
			SELECT DISTINCT cal.OrderWorkPlanId 
			FROM [dbo].[CalibratorsToWorkPlan] as cal
			JOIN [dbo].[CarsToOrder] as c ON cal.OrderWorkPlanId = c.OrderWorkPlanId AND cal.AssigmentDate = c.AssignDate AND c.IsDeleted = 0
			WHERE (cal.CalibratorId = @LoggedInUserId OR @SourceId IS NULL)
			AND cal.AssigmentDate >= @DateFrom AND cal.AssigmentDate <=@DateTo
		END

	DROP TABLE IF EXISTS #AssignedCalibrators
	CREATE TABLE #AssignedCalibrators
	(
	[OrderWorkPlanId] INT
	)
	INSERT #AssignedCalibrators([OrderWorkPlanId])
	SELECT DISTINCT wp.OrderWorkPlanId FROM dbo.ParseCSVToTable(@AssignedCalibratorsIds) as f
	JOIN [dbo].[CalibratorsToWorkPlan] as wp ON wp.CalibratorId = f.Value and wp.IsDeleted = 0

	IF EXISTS (SELECT 1 FROM dbo.ParseCSVToTable(@AssignedCalibratorsIds) WHERE [Value] = -1)
	INSERT #AssignedCalibrators([OrderWorkPlanId])
	SELECT DISTINCT wp.[OrderWorkPlanId]
	FROM [dbo].[OrderWorkPlans] as wp
	LEFT JOIN [dbo].[CalibratorsToWorkPlan] as cwp ON wp.OrderWorkPlanId = cwp.OrderWorkPlanId and cwp.IsDeleted = 0
	WHERE wp.IsCancelled = 0 AND cwp.OrderWorkPlanId IS NULL

	DROP TABLE IF EXISTS #EquipmentId
	CREATE TABLE #EquipmentId
	(
	[OrderWorkPlanId] INT
	)
	INSERT #EquipmentId([OrderWorkPlanId])
	SELECT DISTINCT ce.OrderWorkPlanId FROM dbo.ParseCSVToTable(@EquipmentIds) as f
	JOIN [dbo].[MeasurementDevicesToOrderHeaders] as ce ON ce.MeasurementDeviceId = f.Value and ce.IsDeleted = 0
	
	DROP TABLE IF EXISTS #CarsIds
	CREATE TABLE #CarsIds
	(
	[OrderWorkPlanId] INT
	)
	INSERT #CarsIds([OrderWorkPlanId])	
	SELECT DISTINCT value 
	FROM STRING_SPLIT(@CarsIds,',') as sp
    JOIN [dbo].[CarsToOrder] as c ON sp.value = c.CarId
	JOIN [dbo].[OrderWorkPlans] as wp ON wp.OrderWorkPlanId = c.OrderWorkPlanId
	WHERE wp.IsCancelled = 0 AND c.IsDeleted = 0 

	DROP TABLE IF EXISTS #SpecialCareTypes
	CREATE TABLE #SpecialCareTypes
	(
	[SpecialCareTypeId] INT
	)
	INSERT #SpecialCareTypes([SpecialCareTypeId])
	SELECT DISTINCT f.Value FROM dbo.ParseCSVToTable(@SpecialCareTypeIds) as f

	IF @MainCategory IS NOT NULL
	BEGIN
	DROP TABLE IF EXISTS #MainCategory
	CREATE TABLE #MainCategory
	(
	[ID] INT
	)
	INSERT #MainCategory([ID])
	SELECT ID FROM [dbo].[MainCategories] as mc WHERE mc.MainCategoryName LIKE CONCAT('%',@MainCategory,'%')
	END

	IF @SecondCategory IS NOT NULL
	BEGIN
	DROP TABLE IF EXISTS #SecondCategory
	CREATE TABLE #SecondCategory
	(
	[ID] INT
	)
	INSERT #SecondCategory([ID])
	SELECT ID FROM [dbo].[SecondaryCategories] as sc WHERE sc.SecondaryCategoryName LIKE CONCAT('%',@SecondCategory,'%')
	END

	DECLARE @ClientConfirmationStatusDefault NVARCHAR(50)
	SELECT
	    @ClientConfirmationStatusDefault = s.StatusDescriptionENG
	FROM [dbo].[StatusesCategories] as c
	JOIN [dbo].[Statuses] as s ON c.StatusCategoryId = s.StatusCategoryId
	WHERE c.StatusDescriptionENG = N'ClientConfirmationStatus' AND s.StatusDescriptionENG = N'New'

	DECLARE @StatusesForOrders NVARCHAR(MAX)

	/* MBA-902: this excluded 'Executed', a status that does not exist in dbo.Statuses - so it
	   excluded nothing and finished orders stayed on every working screen. The status it meant is
	   75 Finished (הסתיים); 'Executed' was presumably its earlier name and the rename never
	   reached here.
	   A finished order now leaves the working screens and appears on the calibration history page,
	   which asks for exactly the statuses the others drop. */
	DECLARE @FinishedOrderStatus NVARCHAR(50) = N'Finished'

	SELECT @StatusesForOrders=STRING_AGG(s.StatusId,',')
	FROM [dbo].[Statuses] as s
	JOIN [dbo].[StatusesCategories] as sc ON s.StatusCategoryId = sc.StatusCategoryId
	WHERE sc.StatusDescriptionENG='OrderStatus'
	  AND (  (@Page =  N'calibration-history' AND s.StatusDescriptionENG =  @FinishedOrderStatus)
	      OR (@Page <> N'calibration-history' AND s.StatusDescriptionENG <> @FinishedOrderStatus)
	      OR @Page IS NULL)

	DROP TABLE IF EXISTS #OrderNumbers
	CREATE TABLE #OrderNumbers
	(
	[OrderWorkPlanId] INT
	)
	INSERT #OrderNumbers([OrderWorkPlanId])	
	SELECT DISTINCT wp.[OrderWorkPlanId] 
	FROM STRING_SPLIT(@OrderNumber,',') as sp
	JOIN [dbo].[OrderWorkPlans] as wp ON wp.OrderNumber = sp.value
	WHERE wp.IsCancelled = 0 

	IF @ExcludeRejectedOrders = 1
	BEGIN
		DECLARE @ClientConfirmationStatus NVARCHAR(MAX)

		SELECT @ClientConfirmationStatus=STRING_AGG(s.StatusId,',')
		FROM [dbo].[Statuses] as s
		JOIN [dbo].[StatusesCategories] as sc ON s.StatusCategoryId = sc.StatusCategoryId
		WHERE sc.StatusDescriptionENG='ClientConfirmationStatus' AND s.StatusDescriptionENG = 'Rejected'
	END

	-------------------------------------------------------------------------
	-- Pre-calculate metrics that use STRING_AGG into temp tables
	-------------------------------------------------------------------------

	-- 1. Main Category Names
	DROP TABLE IF EXISTS #MainCatNames;
	CREATE TABLE #MainCatNames (
		OrderWorkPlanId INT,
		MainCategoryName NVARCHAR(400) COLLATE Latin1_General_100_CI_AI_SC
	);
	INSERT INTO #MainCatNames (OrderWorkPlanId, MainCategoryName)
	SELECT maincat.OrderWorkPlanId, STRING_AGG(maincat.MainCategoryName,',') as MainCategoryName
	FROM (
		SELECT DISTINCT wp.OrderWorkPlanId, mcf.MainCategoryName 
		FROM [dbo].[OrderWorkPlans] as wp  
		JOIN [dbo].[OrderDetails] as od ON wp.OrderWorkPlanId = od.OrderWorkPlanId
		JOIN [dbo].[MainCategories] as mcf ON od.MainCategoryId = mcf.ID
	) as maincat
	GROUP BY maincat.OrderWorkPlanId;

	CREATE UNIQUE CLUSTERED INDEX UC_IDX_MainCatNames ON #MainCatNames(OrderWorkPlanId)

	-- 2. Cars and Placement Dates
	DROP TABLE IF EXISTS #CarsAndPlacement;
	CREATE TABLE #CarsAndPlacement (
		OrderWorkPlanId INT,
		Cars NVARCHAR(400) COLLATE Latin1_General_100_CI_AI_SC,
		/* MBA: the EARLIEST assignment date, not a list.
		   An order can run over several days, so CarsToOrder holds one row per day. This used to
		   be a STRING_AGG of all of them - "2026-06-03 00:00:00,2026-06-09 00:00:00,2026-05-14
		   00:00:00", unsorted - which no caller could parse and which made MAX() below compare
		   strings rather than dates. Per product: an order that spans days is dated by its first
		   day. Kept NVARCHAR, and the shape is one element of the old list, so nothing that reads
		   this column has to change. */
		PlacementDate NVARCHAR(19) COLLATE Latin1_General_100_CI_AI_SC
	);
	IF @DateFrom IS NOT NULL AND @DateTo IS NOT NULL AND @Page <> N'external-orders'
	BEGIN
		INSERT INTO #CarsAndPlacement (OrderWorkPlanId, Cars, PlacementDate)
		SELECT co.OrderWorkPlanId, STRING_AGG(CAST(co.CarId as NVARCHAR(MAX)),','), CONVERT(NVARCHAR(19), MIN(co.AssignDate), 120)
		FROM [dbo].[CarsToOrder] as co 
		WHERE co.IsDeleted = 0 AND co.[AssignDate] >= @DateFrom AND co.[AssignDate] <= @DateTo
		GROUP BY co.OrderWorkPlanId;
	END
	ELSE
	BEGIN
		INSERT INTO #CarsAndPlacement (OrderWorkPlanId, Cars, PlacementDate)
		SELECT co.OrderWorkPlanId, STRING_AGG(CAST(co.CarId as NVARCHAR(MAX)),','), CONVERT(NVARCHAR(19), MIN(co.AssignDate), 120)
		FROM [dbo].[CarsToOrder] as co 
		WHERE co.IsDeleted = 0
		GROUP BY co.OrderWorkPlanId;
	END
	CREATE UNIQUE CLUSTERED INDEX UC_IDX_CarsAndPlacement ON #CarsAndPlacement(OrderWorkPlanId)

	-- 3. Calibrators
	DROP TABLE IF EXISTS #WorkPlanCalibrators;
	CREATE TABLE #WorkPlanCalibrators (
		OrderWorkPlanId INT,
		Calibrators NVARCHAR(800) COLLATE Latin1_General_100_CI_AI_SC
	);
	INSERT INTO #WorkPlanCalibrators (OrderWorkPlanId, Calibrators)
	SELECT cwp.OrderWorkPlanId, STRING_AGG(CONCAT(u.FirstName,' ',u.LastName),',') as Calibrators
	FROM [dbo].[CalibratorsToWorkPlan] as cwp
	JOIN [dbo].[Users] as u ON cwp.CalibratorId = u.ID
	WHERE cwp.IsDeleted = 0
	GROUP BY cwp.OrderWorkPlanId;
	
	CREATE UNIQUE CLUSTERED INDEX UC_IDX_WorkPlanCalibrators ON #WorkPlanCalibrators(OrderWorkPlanId)


	-- 4. Statuses (SpecialCareTypeId Statuses)
	DROP TABLE IF EXISTS #WorkPlanStatuses;
	CREATE TABLE #WorkPlanStatuses (
		OrderWorkPlanId INT,
		StatusDescriptionENG NVARCHAR(800) COLLATE Latin1_General_100_CI_AI_SC,
		StatusDescriptionHEB NVARCHAR(800) COLLATE Latin1_General_100_CI_AI_SC
	);
	INSERT INTO #WorkPlanStatuses (OrderWorkPlanId, StatusDescriptionENG, StatusDescriptionHEB)
	SELECT OrderWorkPlanId, STRING_AGG(StatusDescriptionENG,',') AS StatusDescriptionENG, STRING_AGG(StatusDescriptionHEB,',') AS StatusDescriptionHEB
	FROM (
		SELECT DISTINCT od.OrderWorkPlanId, s.StatusDescriptionENG, s.StatusDescriptionHEB
		FROM [dbo].[OrderDetails] as od
		JOIN [dbo].[Statuses] as s ON od.SpecialCareTypeId = s.StatusId
	) ds 
	GROUP BY OrderWorkPlanId;

	CREATE UNIQUE CLUSTERED INDEX UC_IDX_WorkPlanStatuses ON #WorkPlanStatuses(OrderWorkPlanId)

	-- 5. Equipment
	DROP TABLE IF EXISTS #WorkPlanEquipment;
	CREATE TABLE #WorkPlanEquipment (
		OrderWorkPlanId INT,
		EquipmentIds NVARCHAR(800) COLLATE Latin1_General_100_CI_AI_SC,
		EquipmentNames NVARCHAR(800) COLLATE Latin1_General_100_CI_AI_SC
	);
	INSERT INTO #WorkPlanEquipment (OrderWorkPlanId, EquipmentIds, EquipmentNames)
	SELECT coh.OrderWorkPlanId, STRING_AGG(CAST(coh.MeasurementDeviceId AS NVARCHAR(MAX)),', ') as EquipmentIds, STRING_AGG(ce.Description,', ') as EquipmentNames
	FROM [dbo].[MeasurementDevicesToOrderHeaders] as coh
	JOIN [dbo].[MeasurementDevices] as ce ON coh.MeasurementDeviceId = ce.ID AND ce.IsDeleted = 0
	WHERE coh.IsDeleted = 0 
	GROUP BY coh.OrderWorkPlanId;

	CREATE UNIQUE CLUSTERED INDEX UC_IDX_WorkPlanEquipment ON #WorkPlanEquipment(OrderWorkPlanId)

	-- 6. Special Cares
	DROP TABLE IF EXISTS #WorkPlanSpecialCares;
	CREATE TABLE #WorkPlanSpecialCares (
		OrderWorkPlanId INT,
		SpecialCares NVARCHAR(800) COLLATE Latin1_General_100_CI_AI_SC
	);
	INSERT INTO #WorkPlanSpecialCares (OrderWorkPlanId, SpecialCares)
	SELECT OrderWorkPlanId, STRING_AGG(CAST(SpecialCareTypeId AS NVARCHAR(MAX)),',') as SpecialCares
	FROM [dbo].[OrderDetails]
	GROUP BY OrderWorkPlanId;

	CREATE UNIQUE CLUSTERED INDEX UC_IDX_WorkPlanSpecialCares ON #WorkPlanSpecialCares(OrderWorkPlanId)

DECLARE @sql NVARCHAR(MAX) =
CONCAT(
'SELECT 
  --      MAX(CASE ''',@Page,'''
		--	WHEN ''internal-validator'' THEN itm.MbaReportNumber
		--	WHEN ''external-validator'' THEN itm.MbaReportNumber
		--	WHEN ''validator-orders'' THEN itm.MbaReportNumber	
		--	ELSE wp.[OrderNumber] 
		--END) AS [OrderNumber],
		wp.[OrderNumber],
        MAX(co.[PlacementDate]) AS [CalibDate], -- one row per work plan, so this is the earliest assignment; see #CarsAndPlacement
		wp.[CustomerId] as [CustomerId], 
		wp.[OrderWorkPlanId],
        spc.[SpecialCares],
        c.[CustomerName] as [ClientName],
        IIF(css.CustomerSiteId IS NOT NULL,CONCAT_WS('', '',css.CustomerSiteAddress,css.CustomerSiteState,css.CustomerSiteZIP), CONCAT_WS('', '',c.CustomerAddress, c.CustomerCity)) as [Location],
        wp.[WorkPlanOpenDate] as [WorkPlanOpenDate],
		sp.StatusDescriptionENG AS SpecialCareENG,
		sp.StatusDescriptionHEB AS SpecialCareHEB, 
        co.[Cars],
        coh.EquipmentIds,
		coh.EquipmentNames,
		cwp.Calibrators,
        wp.Notes as Notes,
		MIN(mcat.[MainCategoryName]) as MainCategory,
		wp.[IsCancelled],
		MAX(CAST(od.CustomerPackingExists as TINYINT)) as CustomerPackingExists,
		MAX(itm.ExpectedReturnDate) as ExpectedReturnDate,
		MAX(itm.ActualReturnDate) as ActualReturnDate,
		(SELECT MIN(i9.MbaReportNumber) FROM [dbo].[OrderDetailsItems] as i9 JOIN [dbo].[OrderDetails] as od9 ON od9.OrderDetailId = i9.OrderDetailId WHERE od9.OrderWorkPlanId = wp.[OrderWorkPlanId] AND ISNULL(od9.IsDeleted,0) = 0 AND ISNULL(i9.IsDeleted,0) = 0 AND i9.MbaReportNumber LIKE ''[0-9][0-9][0-9][0-9][0-9][0-9][0-9]/%'') as CalibratorMabaNumber, 
		/* MBA-902: the delivery note. Priority calls it ShippingDoc and it is what the packing
		   screen means by its order-number column - the values are D26009347, D26009342 and the
		   like. 2,353 of the 3,838 items carry one and every single one starts with D. An order can
		   be shipped on more than one note, so they are listed rather than reduced to the first.
		   STRING_AGG over a DISTINCT subquery rather than FOR XML: the XML data type methods need
		   particular SET options and fail on a connection that does not have them. */
		(SELECT STRING_AGG(sd.ShippingDoc, N'', '')
		   FROM (SELECT DISTINCT i8.ShippingDoc
		           FROM [dbo].[OrderDetailsItems] as i8
		           JOIN [dbo].[OrderDetails] as od8 ON od8.OrderDetailId = i8.OrderDetailId
		          WHERE od8.OrderWorkPlanId = wp.[OrderWorkPlanId]
		            AND ISNULL(od8.IsDeleted,0) = 0 AND ISNULL(i8.IsDeleted,0) = 0
		            AND NULLIF(LTRIM(RTRIM(i8.ShippingDoc)), '''') IS NOT NULL) as sd) as ShippingDoc, 
		/* MBA-907: the notes a coordinator or validator wrote on this order. The column shows the
		   latest and the count; the popup calls dbo.GetOrderNotes for the thread. */
		(SELECT TOP 1 n.NoteText FROM dbo.OrderNote AS n
		  WHERE n.OrderWorkPlanId = wp.[OrderWorkPlanId] AND n.IsDeleted = 0
		  ORDER BY n.CreatedDate DESC, n.OrderNoteId DESC) as LatestOrderNote,
		(SELECT COUNT(*) FROM dbo.OrderNote AS n
		  WHERE n.OrderWorkPlanId = wp.[OrderWorkPlanId] AND n.IsDeleted = 0) as OrderNotesCount, /* MBA-902: a correlated subquery, not an aggregate over itm. The report number belongs to the ORDER, and aggregating over itm would only see the items the validator status filter let through - on STAGE that is 1 order out of 49 instead of 6, because 3,470 of the 3,471 items carrying a real report number have no calibration status at all. */  
	    COALESCE(MAX(clst.StatusDescriptionENG),''',@ClientConfirmationStatusDefault,''') as ClientConfirmationStatus,
		MAX(wp.ShipTypeDesc) AS ShipTypeDesc,
		MAX(c.ReportRequired) AS PrintedReport,
		MAX(wp.CreatedDate) AS ReceivingDate,
		MAX(wpstat.StatusDescriptionENG) AS WorkPlanStatus,
		MAX(wp.CustomerComment) as CustomerComment,
		-- MBA-792: הנחיות לביצוע — Priority ORDERSTEXT, NEGATIVE-ORD side, served from the local cache.
		-- The positive-ORD side is the printed order document (mostly boilerplate) and is NOT this.
		(SELECT ci.InstructionsText   -- plain text; raw HTML is available via GetOrderInstructionsByOrder
		   FROM dbo.CrmOrderInstructions ci WHERE ci.ORD = wp.OrderSourceId) as OrderInstructions,
		MAX(co.[PlacementDate]) AS [PlacementDate],
		MIN(boxcnt.BoxesCount) as BoxesCount,
		COUNT(1) OVER(PARTITION BY 1 ORDER BY wp.[OrderNumber] ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) as ItemsCount
    FROM [dbo].[OrderWorkPlans] as wp'
	,IIF(@FilterExternalOrdersForCalibrator = 1,' JOIN #FilterExternalOrdersForCalibrator as filo ON wp.OrderWorkPlanId = filo.OrderWorkPlanId ',' ')
	,IIF(@AssignedCalibratorsIds IS NOT NULL,' JOIN #AssignedCalibrators as ac ON wp.OrderWorkPlanId = ac.OrderWorkPlanId ',' ')
	,IIF(@EquipmentIds IS NOT NULL,' JOIN #EquipmentId as eid ON wp.OrderWorkPlanId = eid.OrderWorkPlanId ',' ')
	,IIF(@CarsIds IS NOT NULL,' JOIN #CarsIds as cid ON wp.OrderWorkPlanId = cid.OrderWorkPlanId ',' ')
	,IIF(@OrderNumber IS NOT NULL,' JOIN #OrderNumbers as ordnf ON wp.OrderWorkPlanId = ordnf.OrderWorkPlanId ',' ')
	,'JOIN [dbo].[OrderDetails] as od ON wp.OrderWorkPlanId = od.OrderWorkPlanId
	  LEFT JOIN [dbo].[OrderDetailsItems] as itm ON itm.OrderDetailId = od.OrderDetailId
	  LEFT JOIN [dbo].[Customers] as c ON wp.[CustomerId] = c.[CustomerId]
	  LEFT JOIN [dbo].[Statuses] as wpstat ON wp.[OrderOverallStatusId] = wpstat.[StatusId]
	  LEFT JOIN [dbo].[Statuses] as clst ON wp.[ClientConfirmationStatusId] = clst.[StatusId]
	  LEFT JOIN [dbo].[MainCategories] as mcf ON od.MainCategoryId	= mcf.ID
	  LEFT JOIN [dbo].[CalibratorsToWorkPlan] as ctwp ON ctwp.[OrderWorkPlanId] = wp.[OrderWorkPlanId] AND ctwp.[CalibratorId] = ',@LoggedInUserId,' AND ctwp.IsDeleted = 0
	  LEFT JOIN [dbo].[CalibratorsToWorkPlan] as ctwpdef ON ctwpdef.[OrderWorkPlanId] = wp.[OrderWorkPlanId] AND ctwpdef.IsDeleted = 0
	  LEFT JOIN [dbo].[SecondaryCategories] as scf ON od.SecondaryCategoryId = scf.ID
	  LEFT JOIN [dbo].[CustomerSites] as css ON css.CustomerSiteId = od.CustomerSiteId
	',IIF(@SpecialCareTypeIds IS NOT NULL,' JOIN #SpecialCareTypes as sct ON od.SpecialCareTypeId = sct.SpecialCareTypeId ',' ')
	 ,IIF(@MainCategory IS NOT NULL,' JOIN #MainCategory as mainc ON od.MainCategoryId = mainc.ID ',' ')
	 ,IIF(@SecondCategory IS NOT NULL,' JOIN #SecondCategory as secc ON od.SecondaryCategoryId = secc.ID ',' ')
	,'LEFT JOIN #MainCatNames as mcat ON wp.OrderWorkPlanId = mcat.OrderWorkPlanId
	'
	,CASE WHEN @DateFrom IS NOT NULL AND @DateTo IS NOT NULL AND @Page <> N'external-orders' THEN '' ELSE 'LEFT' END
	,'
	JOIN #CarsAndPlacement as co ON wp.OrderWorkPlanId = co.OrderWorkPlanId
	LEFT JOIN #WorkPlanCalibrators as cwp ON wp.OrderWorkPlanId = cwp.OrderWorkPlanId
	LEFT JOIN #WorkPlanStatuses as sp ON wp.OrderWorkPlanId = sp.OrderWorkPlanId
	LEFT JOIN #WorkPlanEquipment as coh ON wp.OrderWorkPlanId = coh.OrderWorkPlanId
	LEFT JOIN #WorkPlanSpecialCares as spc ON wp.OrderWorkPlanId = spc.OrderWorkPlanId	
	OUTER APPLY
	(
	SELECT COUNT(DISTINCT pb.PackingBoxId) as BoxesCount
	FROM [dbo].[PackingBox] as pb
	LEFT JOIN [dbo].[PackingBoxToOrderDetailsItems] as itm ON pb.PackingBoxId = itm.PackingBoxId
	LEFT JOIN [dbo].[OrderDetailsItems] as oi ON itm.OrderDetailsItemId = oi.OrderDetailsItemId
	LEFT JOIN [dbo].[OrderDetails] as od ON oi.OrderDetailId = od.OrderDetailId
	WHERE od.OrderWorkPlanId = wp.OrderWorkPlanId AND pb.IsDeleted = 0 AND itm.IsDeleted = 0 
	GROUP BY od.OrderWorkPlanId
	) as boxcnt 
	WHERE wp.OrderOverallStatusId IN(',@StatusesForOrders,') '
	,CASE WHEN @LoggedInUserEmail IS NOT NULL AND @SourceId IS NOT NULL THEN ' AND wp.SourceId = '+CAST(@SourceId AS NVARCHAR(50))  ELSE ' ' END
	,CASE WHEN @ExcludeRejectedOrders = 1 THEN ' AND COALESCE(wp.ClientConfirmationStatusId,0) NOT IN ('+@ClientConfirmationStatus+') 'ELSE ' ' END
	,CASE WHEN @ClientName IS NOT NULL THEN ' AND c.CustomerName LIKE N''%'+ @ClientName +'%'' 'ELSE ' ' END
	,CASE WHEN @ResolvedCustomerId IS NOT NULL THEN ' AND wp.CustomerId = '+ CAST(@ResolvedCustomerId AS NVARCHAR(20)) +' 'ELSE ' ' END
--	,CASE WHEN @Date IS NOT NULL AND  @Date > '1900-01-01' THEN ' AND wp.AssigmentDate = '''+CAST(@Date as NVARCHAR(MAX)) +''' 'ELSE ' ' END
	,CASE WHEN @Location  IS NOT NULL THEN ' AND IIF(css.CustomerSiteId IS NOT NULL,CONCAT_WS('', '',css.CustomerSiteAddress,css.CustomerSiteState,css.CustomerSiteZIP), CONCAT_WS('', '',c.CustomerAddress, c.CustomerCity)) LIKE N''%'+@Location +'%'' 'ELSE ' ' END
	,CASE WHEN @ProductType IS NOT NULL THEN ' AND od.PartName LIKE N''%'+ @ProductType +'%'' 'ELSE ' ' END
	,CASE WHEN @ProducedIn IS NOT NULL THEN ' AND itm.OrdersDeviceManufacturer LIKE N''%'+ @ProducedIn +'%'' 'ELSE ' ' END
	,CASE WHEN @DeviceModel IS NOT NULL THEN ' AND itm.DeviceModel LIKE N''%'+ @DeviceModel +'%'' 'ELSE ' ' END
	,CASE WHEN @DeviceNumber IS NOT NULL THEN ' AND itm.SerialNumber LIKE N''%'+ @DeviceNumber +'%'' 'ELSE ' ' END
	,CASE WHEN @DeviceManufacturer IS NOT NULL THEN ' AND dm.OrdersDeviceManufacturerDescription LIKE N''%'+ @DeviceManufacturer +'%'''ELSE ' ' END
    ,CASE WHEN @GlobalSearch IS NOT NULL THEN ' AND CONCAT(cwp.[Calibrators],mcf.[MainCategoryName],c.[CustomerCity],c.[CustomerName],scf.[SecondaryCategoryName],sp.[StatusDescriptionENG],wp.[OrderNumber],c.[CustomerCode],wp.[CustomerId]) LIKE N''%'+ @GlobalSearch +'%'''ELSE ' ' END
	,CASE WHEN @WorkPlanOpenDate IS NOT NULL THEN ' AND wp.WorkPlanOpenDate = '''+CAST(@WorkPlanOpenDate as NVARCHAR(MAX)) +''' 'ELSE ' ' END
	,CASE WHEN @Notes IS NOT NULL THEN ' AND wp.Notes LIKE N''%'+ @Notes +'%'''ELSE ' ' END
	,CASE WHEN @ExtIntFilter IS NOT NULL THEN ' AND od.IsInHouse='+CAST(@ExtIntFilter as NVARCHAR(MAX))+' 'ELSE ' ' END
	/* MBA: what the coordinator screen is allowed to show.
	   Recent work, plus anything confirmed that was scheduled in the last week - so an older
	   order still on the road does not vanish off the screen. Scheduling is manual, so most
	   orders carry no assignment at all and are matched by the first leg alone.
	   The second leg matches if ANY of a multi-day order's days falls in the window. */
	,CASE WHEN @Page = N'coordinator-orders'
	      THEN ' AND ( wp.WorkPlanOpenDate >= DATEADD(month,-3,GETDATE())
	                OR EXISTS (SELECT 1
	                             FROM dbo.CarsToOrder AS cf
	                             JOIN dbo.Statuses    AS sf ON sf.StatusId = wp.ClientConfirmationStatusId
	                            WHERE cf.OrderWorkPlanId = wp.OrderWorkPlanId
	                              AND cf.IsDeleted = 0
	                              AND sf.StatusDescriptionENG = ''Confirmed''
	                              AND cf.AssignDate <  GETDATE()
	                              AND cf.AssignDate >= DATEADD(day,-7,GETDATE())) ) '
	      ELSE ' ' END
	/* MBA-902: a device reaches the validator once its report exists. */
	,CASE WHEN @Page IN (N'internal-validator',N'external-validator',N'validator-orders')
	      THEN ' AND itm.MbaReportNumber LIKE ''[0-9][0-9][0-9][0-9][0-9][0-9][0-9]/%'' ' ELSE ' ' END
	,'GROUP BY 
	wp.[CustomerId],
 --   CASE ''',@Page,'''
	--	WHEN ''internal-validator'' THEN itm.MbaReportNumber
	--	WHEN ''external-validator'' THEN itm.MbaReportNumber
	--	WHEN ''validator-orders'' THEN itm.MbaReportNumber
	--ELSE wp.[OrderNumber] 
	--END, 
	wp.[OrderNumber],
	wp.[OrderWorkPlanId],
	spc.[SpecialCares],
	c.[CustomerName], 
	IIF(css.CustomerSiteId IS NOT NULL,CONCAT_WS('', '',css.CustomerSiteAddress,css.CustomerSiteState,css.CustomerSiteZIP), CONCAT_WS('', '',c.CustomerAddress, c.CustomerCity)),
	wp.[WorkPlanOpenDate],
	co.[Cars],
    coh.EquipmentIds,
	coh.EquipmentNames,
	cwp.Calibrators,
	wp.Notes,
	sp.StatusDescriptionENG,
	sp.StatusDescriptionHEB, 
	wp.[IsCancelled],
	wp.OrderSourceId '
  ,  'ORDER BY ' , @OrderBy , CASE WHEN @OrderByAsc = 1 THEN ' ASC' WHEN @OrderByAsc = 0 THEN ' DESC'  ELSE '' END , ' OFFSET ',(@PageNumber -1) * @RowsOfPage,' ROWS FETCH NEXT ', @RowsOfPage ,'ROWS ONLY OPTION(RECOMPILE); ')
PRINT LEN(@sql)
PRINT CAST(@sql as VARCHAR(MAX))
EXEC (@sql)

END
GO
/* ===== dbo.RefreshCrmTextCache ===== */
GO

CREATE OR ALTER PROCEDURE [dbo].[RefreshCrmTextCache]
    @IncrementalOnly BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    IF OBJECT_ID('dbo.CrmCatalogText') IS NULL
        CREATE TABLE dbo.CrmCatalogText(PART INT PRIMARY KEY, CatalogText NVARCHAR(MAX) NULL, RefreshedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME());
    IF OBJECT_ID('dbo.CrmDeviceText') IS NULL
        CREATE TABLE dbo.CrmDeviceText(SERN INT PRIMARY KEY, DeviceText NVARCHAR(MAX) NULL, RefreshedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME());
    IF OBJECT_ID('dbo.CrmOrderInstructions') IS NULL
        CREATE TABLE dbo.CrmOrderInstructions(
             ORD                INT PRIMARY KEY      -- = OrderWorkPlans.OrderSourceId (positive)
            ,OrderInstructionsZ VARBINARY(MAX) NULL  -- COMPRESS(HTML). 18.2:1 on real data.
            ,InstructionsText   NVARCHAR(MAX)  NULL  -- tags stripped, for table cells
            ,RefreshedAt        DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME());
    IF OBJECT_ID('dbo.CrmPartInfo') IS NULL
        CREATE TABLE dbo.CrmPartInfo(
             PartName          NVARCHAR(30) NOT NULL PRIMARY KEY  -- = OrderDetails.PartName = PART.PARTNAME
            ,PART              INT           NULL                 -- the real Priority key
            ,PartDescription   NVARCHAR(200) NULL                 -- PART.PARTDES (תיאור מכשיר)
            ,FamilyId          INT           NULL                 -- PART.FAMILY
            ,FamilyDescription NVARCHAR(200) NULL                 -- FAMILY.FAMILYDES
            ,RefreshedAt       DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME());

    -- ── what the cache is expected to hold; in incremental mode only what it is missing ──────
    -- COLLATE DATABASE_DEFAULT is required: a temp table inherits tempdb's collation
-- (Latin1_General_100_CI_AI_SC here) while the user database is Hebrew_CI_AS, so every
-- comparison against a local column fails with a collation conflict.
    CREATE TABLE #WantedName(PartName NVARCHAR(30) COLLATE DATABASE_DEFAULT PRIMARY KEY);
    INSERT INTO #WantedName(PartName)
    SELECT DISTINCT LTRIM(RTRIM(od.PartName)) FROM dbo.OrderDetails AS od
    WHERE od.PartName IS NOT NULL AND LTRIM(RTRIM(od.PartName)) <> N''
      AND (@IncrementalOnly = 0 OR NOT EXISTS (SELECT 1 FROM dbo.CrmPartInfo c WHERE c.PartName = LTRIM(RTRIM(od.PartName))));

    CREATE TABLE #WantedSern(SERN INT PRIMARY KEY);
    INSERT INTO #WantedSern(SERN)
    SELECT DISTINCT itm.SERN FROM dbo.OrderDetailsItems AS itm
    WHERE itm.SERN IS NOT NULL
      AND (@IncrementalOnly = 0 OR NOT EXISTS (SELECT 1 FROM dbo.CrmDeviceText c WHERE c.SERN = itm.SERN));

    CREATE TABLE #WantedOrd(ORD INT PRIMARY KEY);
    INSERT INTO #WantedOrd(ORD)
    SELECT DISTINCT wp.OrderSourceId FROM dbo.OrderWorkPlans AS wp
    WHERE wp.OrderSourceId IS NOT NULL
      AND (@IncrementalOnly = 0 OR NOT EXISTS (SELECT 1 FROM dbo.CrmOrderInstructions c WHERE c.ORD = wp.OrderSourceId));

    IF @IncrementalOnly = 0
    BEGIN
        TRUNCATE TABLE dbo.CrmCatalogText;
        TRUNCATE TABLE dbo.CrmDeviceText;
        TRUNCATE TABLE dbo.CrmPartInfo;
        TRUNCATE TABLE dbo.CrmOrderInstructions;
    END

    -- ── part description + family, resolved by CATALOG NUMBER ────────────────────────────────
    IF EXISTS (SELECT 1 FROM #WantedName)
        INSERT INTO dbo.CrmPartInfo(PartName, PART, PartDescription, FamilyId, FamilyDescription)
        SELECT w.PartName,
               p.PART,
               LTRIM(RTRIM(CONVERT(NVARCHAR(200), p.PARTDES))),
               p.FAMILY,
               LTRIM(RTRIM(CONVERT(NVARCHAR(200), f.FAMILYDES)))
        FROM #WantedName AS w
        -- both sides collated explicitly: the remote PARTNAME comes back as
        -- Latin1_General_100_CI_AI_SC and the local column is Hebrew_CI_AS, which cannot be
        -- compared without this.
        JOIN [31.168.173.93].amaba.dbo.PART AS p
             ON LTRIM(RTRIM(p.PARTNAME)) COLLATE Hebrew_BIN = w.PartName COLLATE Hebrew_BIN
        LEFT JOIN [31.168.173.93].amaba.dbo.FAMILY AS f ON f.FAMILY = p.FAMILY;

    -- ── catalog text, for the PARTs we just resolved ─────────────────────────────────────────
    CREATE TABLE #WantedPart(PART INT PRIMARY KEY);
    INSERT INTO #WantedPart(PART)
    SELECT DISTINCT c.PART FROM dbo.CrmPartInfo c
    WHERE c.PART IS NOT NULL
      AND (@IncrementalOnly = 0 OR NOT EXISTS (SELECT 1 FROM dbo.CrmCatalogText t WHERE t.PART = c.PART));

    IF EXISTS (SELECT 1 FROM #WantedPart)
        INSERT INTO dbo.CrmCatalogText(PART, CatalogText)
        SELECT pt.PART,
               STRING_AGG(REVERSE(CONVERT(NVARCHAR(MAX), pt.[TEXT])), N' ') WITHIN GROUP (ORDER BY pt.TEXTLINE, pt.TEXTORD)
        FROM [31.168.173.93].amaba.dbo.PARTTEXT AS pt
        WHERE pt.PART IN (SELECT PART FROM #WantedPart)
        GROUP BY pt.PART;

    IF EXISTS (SELECT 1 FROM #WantedSern)
        INSERT INTO dbo.CrmDeviceText(SERN, DeviceText)
        SELECT st.SERN,
               STRING_AGG(REVERSE(CONVERT(NVARCHAR(MAX), st.[TEXT])), N' ') WITHIN GROUP (ORDER BY st.TEXTLINE, st.TEXTORD)
        FROM [31.168.173.93].amaba.dbo.SERNUMBERSTEXT AS st
        WHERE st.SERN IN (SELECT SERN FROM #WantedSern)
        GROUP BY st.SERN;

    /* ORDERSTEXT is ~89.6M rows, so it is fetched in BATCHES over the orders Calibrator knows.
       Measured: one order alone ~0.7s, but 20 in a single remote query ~1.9s together — roughly
       7x cheaper per order. NOTE THE MINUS SIGN; the cache key stays the positive OrderSourceId. */
    IF EXISTS (SELECT 1 FROM #WantedOrd)
    BEGIN
        CREATE TABLE #OrdQueue(ORD INT PRIMARY KEY);       -- drain a copy; #WantedOrd is needed below
        INSERT INTO #OrdQueue(ORD) SELECT ORD FROM #WantedOrd;

        DECLARE @OrdBatch TABLE(ORD INT PRIMARY KEY);
        WHILE EXISTS (SELECT 1 FROM #OrdQueue)
        BEGIN
            DELETE FROM @OrdBatch;
            INSERT INTO @OrdBatch(ORD) SELECT TOP (20) ORD FROM #OrdQueue ORDER BY ORD;

            INSERT INTO dbo.CrmOrderInstructions(ORD, OrderInstructionsZ)
            SELECT -ot.ORD,
                   COMPRESS(STRING_AGG(REVERSE(CONVERT(NVARCHAR(MAX), ot.[TEXT])), N' ') WITHIN GROUP (ORDER BY ot.TEXTLINE, ot.TEXTORD))
            FROM [31.168.173.93].amaba.dbo.ORDERSTEXT AS ot
            WHERE ot.ORD IN (SELECT -ORD FROM @OrdBatch)
            GROUP BY ot.ORD;

            DELETE q FROM #OrdQueue AS q WHERE q.ORD IN (SELECT ORD FROM @OrdBatch);
        END
    END

    /* Plain-text rendering for table cells. Outside the block above on purpose: that block only
       runs when there are new ORDs, so keeping this inside meant text added later never filled. */
    UPDATE ci SET ci.InstructionsText =
           dbo.fnStripHtml(CAST(DECOMPRESS(ci.OrderInstructionsZ) AS NVARCHAR(MAX)))
    FROM dbo.CrmOrderInstructions AS ci
    WHERE ci.OrderInstructionsZ IS NOT NULL AND ci.InstructionsText IS NULL;

    /* Negative caching — do not remove.
       Most keys have no CRM text at all, and without a row saying "checked, nothing there",
       absence is indistinguishable from "not cached yet": every incremental run re-queried them
       over the linked server, measured at 96.7s per no-op run versus 0.09s now. A row with NULL
       content means CHECKED-AND-EMPTY. Callers LEFT JOIN these tables and see NULL either way. */
    INSERT INTO dbo.CrmPartInfo(PartName, PART, PartDescription, FamilyId, FamilyDescription)
    SELECT w.PartName, NULL, NULL, NULL, NULL FROM #WantedName AS w
    WHERE NOT EXISTS (SELECT 1 FROM dbo.CrmPartInfo c WHERE c.PartName = w.PartName);

    INSERT INTO dbo.CrmCatalogText(PART, CatalogText)
    SELECT w.PART, NULL FROM #WantedPart AS w
    WHERE NOT EXISTS (SELECT 1 FROM dbo.CrmCatalogText c WHERE c.PART = w.PART);

    INSERT INTO dbo.CrmDeviceText(SERN, DeviceText)
    SELECT w.SERN, NULL FROM #WantedSern AS w
    WHERE NOT EXISTS (SELECT 1 FROM dbo.CrmDeviceText c WHERE c.SERN = w.SERN);

    INSERT INTO dbo.CrmOrderInstructions(ORD, OrderInstructionsZ)
    SELECT w.ORD, NULL FROM #WantedOrd AS w
    WHERE NOT EXISTS (SELECT 1 FROM dbo.CrmOrderInstructions c WHERE c.ORD = w.ORD);
END

GO
/* ===== dbo.fnMasterValueAfterCorrection ===== */
GO

CREATE OR ALTER FUNCTION dbo.fnMasterValueAfterCorrection
(
    @MeasurementDevicesId INT,
    @Reading              DECIMAL(18,6),
    @MeasurementId        INT = NULL
)
RETURNS TABLE
AS
RETURN
(
    WITH Ranked AS
    (
        SELECT c.MeasurementId, c.Value1, c.Value2, c.Deviation,
               Rnk = RANK() OVER (ORDER BY c.CorVersion DESC)
        FROM dbo.MeasurementDevicesCorrections AS c
        WHERE c.MeasurementDevicesId = @MeasurementDevicesId
          AND ISNULL(c.IsDeleted, 0) = 0
          AND c.Deviation IS NOT NULL
          AND @Reading IS NOT NULL
    ),
    Newest AS (SELECT MeasurementId, Value1, Value2, Deviation FROM Ranked WHERE Rnk = 1),
    Chosen AS
    (
        SELECT TOP (1) MeasurementId FROM Newest
        WHERE @MeasurementId IS NULL OR MeasurementId = @MeasurementId
        GROUP BY MeasurementId ORDER BY COUNT(*) DESC, MeasurementId
    ),
    Pts    AS (SELECT n.Value1, n.Value2, n.Deviation FROM Newest AS n JOIN Chosen AS c ON c.MeasurementId = n.MeasurementId),
    /* Two different upper edges, and confusing them is what made 31-77 look truncated.
       LastPoint is the highest calibrated point - interpolation cannot go past it, so that is
       where the deviation starts being clamped, exactly as the C# does.
       CertTop is the end of the last RANGE, which is how far the certificate actually covers.
       31-77: last point 349.98, certificate top 399.923. A reading of 380 is inside the
       certificate and must not be reported as beyond it. */
    Bounds AS (SELECT LoEdge  = MIN(Value1),
                      HiEdge  = MAX(Value1),
                      CertTop = MAX(COALESCE(Value2, Value1)) FROM Pts),
    Below  AS (SELECT TOP (1) Value1, Deviation FROM Pts WHERE Value1 <= @Reading ORDER BY Value1 DESC),
    Above  AS (SELECT TOP (1) Value1, Deviation FROM Pts WHERE Value1 >  @Reading ORDER BY Value1 ASC),
    Edge   AS (SELECT LoDev = (SELECT TOP (1) Deviation FROM Pts ORDER BY Value1 ASC),
                      HiDev = (SELECT TOP (1) Deviation FROM Pts ORDER BY Value1 DESC)),
    /* how many decimals the reading itself carries, once trailing zeros are dropped */
    Scale AS
    (
        SELECT Decimals = CASE WHEN CHARINDEX('.', t.txt) = 0 THEN 0
                               ELSE LEN(t.txt) - CHARINDEX('.', t.txt) END
        FROM (SELECT s1 = CAST(@Reading AS NVARCHAR(40))) AS a
        CROSS APPLY (SELECT txt = CASE WHEN CHARINDEX('.', a.s1) = 0 THEN a.s1
                                       ELSE LEFT(a.s1, LEN(REPLACE(RTRIM(REPLACE(a.s1,'0',' ')),' ','0'))) END) AS b
        CROSS APPLY (SELECT txt = CASE WHEN RIGHT(b.txt,1) = '.' THEN LEFT(b.txt, LEN(b.txt)-1) ELSE b.txt END) AS t
    ),
    Dev AS
    (
        SELECT Deviation =
            CASE
                WHEN b.LoEdge IS NULL     THEN NULL
                WHEN @Reading <  b.LoEdge THEN e.LoDev
                WHEN @Reading >= b.HiEdge THEN e.HiDev
                WHEN a.Value1  IS NULL    THEN lo.Deviation
                WHEN lo.Value1 = @Reading THEN lo.Deviation
                ELSE lo.Deviation
                     + ((a.Deviation - lo.Deviation) / NULLIF(a.Value1 - lo.Value1, 0))
                       * (@Reading - lo.Value1)
            END,
            UsedMeasurementId = (SELECT MeasurementId FROM Chosen),
            OutOfRange = CASE WHEN b.LoEdge IS NULL     THEN NULL
                              WHEN @Reading < b.LoEdge  THEN CAST(1 AS BIT)
                              WHEN @Reading > b.CertTop THEN CAST(1 AS BIT)
                              ELSE CAST(0 AS BIT) END,
            /* the deviation stopped following the curve and is being held flat */
            Extrapolated = CASE WHEN b.LoEdge IS NULL    THEN NULL
                                WHEN @Reading < b.LoEdge THEN CAST(1 AS BIT)
                                WHEN @Reading > b.HiEdge THEN CAST(1 AS BIT)
                                ELSE CAST(0 AS BIT) END,
            CertificateTop = b.CertTop,
            LastCalibratedPoint = b.HiEdge
        FROM Bounds AS b
        CROSS JOIN Edge AS e
        LEFT JOIN Below AS lo ON 1 = 1
        LEFT JOIN Above AS a  ON 1 = 1
    )
    SELECT Deviation = CAST(d.Deviation AS DECIMAL(18,6)),
           /* full precision - use this for anything that is stored or calculated on */
           CorrectedExact = CAST(@Reading - d.Deviation AS DECIMAL(18,6)),
           /* for the screen: as many decimals as the reading itself carries */
           /* At least 3 decimals, however few the reading carried. Rounding purely to the
              reading's own precision erased the correction: a reading of 23 has deviation
              -0.001792 and came back as 23, so the calibrator saw nothing happen. Three is
              enough to show every deviation in the data - they run from about 0.001 to 2 -
              without printing six digits the measurement cannot justify. */
           Corrected      = CAST(ROUND(@Reading - d.Deviation,
                                       CASE WHEN s.Decimals < 3 THEN 3 ELSE s.Decimals END)
                                 AS DECIMAL(18,6)),
           ReadingDecimals = s.Decimals,
           d.OutOfRange,
           d.Extrapolated,
           d.CertificateTop,
           d.LastCalibratedPoint,
           d.UsedMeasurementId
    FROM Dev AS d CROSS JOIN Scale AS s
);

GO
/* ===== dbo.fnStripHtml ===== */
GO
-- =============================================
-- Func:        dbo.fnStripHtml
-- Jira:        MBA-792 / MBA-806
-- Description: Turns the CRM's Word-exported HTML into readable single-line plain text, so a
--              coordinator sees "כיול מבוצע ע\"י לרית / לרית צריכים להגיע עם 1000 ק\"ג" in a table
--              cell instead of "<P dir=rtl><SPAN lang=HE style='FONT-SIZE...".
--
-- Deliberately used at CACHE-FILL time (dbo.RefreshCrmTextCache), not inside a list query: this is
-- a scalar UDF with a WHILE loop, so it is fine over ~1,000 rows once and a bad idea per request.
--
-- Order matters: the <style> block goes first (it is CSS, not content), then block-level tags
-- become separators so two sentences do not weld into one, then all remaining tags are stripped,
-- then entities are decoded, then whitespace is collapsed.
-- =============================================
CREATE OR ALTER FUNCTION dbo.fnStripHtml (@html NVARCHAR(MAX))
RETURNS NVARCHAR(MAX)
WITH SCHEMABINDING
AS
BEGIN
    IF @html IS NULL RETURN NULL;

    DECLARE @s NVARCHAR(MAX) = @html;
    DECLARE @i INT, @j INT;

    -- 1. drop the CSS block entirely
    SET @i = CHARINDEX('<style', @s);
    WHILE @i > 0
    BEGIN
        SET @j = CHARINDEX('</style>', @s, @i);
        IF @j = 0 BREAK;
        SET @s = STUFF(@s, @i, @j + 8 - @i, N'');
        SET @i = CHARINDEX('<style', @s);
    END

    -- 2. block-level tags become separators, so lines stay distinguishable
    SET @s = REPLACE(@s, N'<BR>',  N' | ');
    SET @s = REPLACE(@s, N'<br>',  N' | ');
    SET @s = REPLACE(@s, N'<BR/>', N' | ');
    SET @s = REPLACE(@s, N'</P>',  N' | ');
    SET @s = REPLACE(@s, N'</p>',  N' | ');
    SET @s = REPLACE(@s, N'</DIV>', N' | ');
    SET @s = REPLACE(@s, N'</div>', N' | ');
    SET @s = REPLACE(@s, N'</LI>', N' | ');
    SET @s = REPLACE(@s, N'</TR>', N' | ');
    SET @s = REPLACE(@s, N'</tr>', N' | ');
    -- MBA-902: most of this text is a two-column instructions table, so a cell boundary is a real
    -- separator. Without these, "סוג לקוח:" ran straight into its value and the popup read as one
    -- unbroken wall of words.
    SET @s = REPLACE(@s, N'</TD>', N' | ');
    SET @s = REPLACE(@s, N'</td>', N' | ');
    SET @s = REPLACE(@s, N'</TABLE>', N' | ');
    SET @s = REPLACE(@s, N'</table>', N' | ');
    SET @s = REPLACE(@s, N'</UL>', N' | ');
    SET @s = REPLACE(@s, N'</ul>', N' | ');
    SET @s = REPLACE(@s, N'</li>', N' | ');

    -- 3. strip every remaining tag, leaving a SPACE behind rather than nothing.
    --    Priority breaks its text mid-sentence across TEXTLINE rows, and the reconstruction joins
    --    them with no delimiter, so removing a tag outright welds words together
    --    ("חייב להיות עד27/08/26"). The space is collapsed again in step 5.
    SET @i = CHARINDEX('<', @s);
    WHILE @i > 0
    BEGIN
        SET @j = CHARINDEX('>', @s, @i);
        IF @j = 0 BREAK;                      -- a stray '<' with no closing '>' — leave it alone
        SET @s = STUFF(@s, @i, @j - @i + 1, N' ');
        SET @i = CHARINDEX('<', @s);
    END

    -- 4. entities
    SET @s = REPLACE(@s, N'&nbsp;', N' ');
    SET @s = REPLACE(@s, N'&amp;',  N'&');
    SET @s = REPLACE(@s, N'&quot;', N'"');
    SET @s = REPLACE(@s, N'&#39;',  N'''');
    SET @s = REPLACE(@s, N'&lt;',   N'<');
    SET @s = REPLACE(@s, N'&gt;',   N'>');

    -- 5. collapse whitespace and tidy the separators
    SET @s = REPLACE(REPLACE(REPLACE(@s, CHAR(13), N' '), CHAR(10), N' '), CHAR(9), N' ');
    WHILE CHARINDEX(N'  ', @s) > 0 SET @s = REPLACE(@s, N'  ', N' ');
    WHILE CHARINDEX(N'| |', @s) > 0 SET @s = REPLACE(@s, N'| |', N'|');
    SET @s = LTRIM(RTRIM(@s));
    WHILE LEN(@s) > 0 AND RIGHT(@s, 1) IN (N'|', N' ') SET @s = LTRIM(RTRIM(LEFT(@s, LEN(@s) - 1)));
    WHILE LEN(@s) > 0 AND LEFT(@s, 1) IN (N'|', N' ') SET @s = LTRIM(RTRIM(RIGHT(@s, LEN(@s) - 1)));

    RETURN NULLIF(@s, N'');
END

GO
/* ===== dbo.fnUnreverseVisualText ===== */
GO
/*
    dbo.fnUnreverseVisualText
    ---------------------------------------------------------------------------------------------
    Priority stores text in VISUAL order. The Hebrew reads correctly, but every run of digits or
    Latin inside it is reversed: a 150 mm caliper is stored "׳–׳—׳•׳ ׳׳׳§׳˜׳¨׳•׳ ׳™ ׳¢׳“ 051", and a 100 kg
    scale as "׳׳׳–׳ ׳™׳™׳ ׳¢׳“ 001 ׳§'׳’".

    This walks the string and reverses each non-Hebrew run in place, leaving the Hebrew alone.
    Brackets come out right on their own - ")3-1M(" reverses to "(M1-3)" - so they are NOT mirrored
    separately; doing both would flip them back.

    TRAILING SENTENCE PUNCTUATION IS NOT PART OF THE RUN                        (fixed 31/08/2026)
    ------------------------------------------------------------------------------------------
    Priority reverses only the strong LTR characters and leaves a neutral like ':' where it is.
    Verified by code point, not by looking at a terminal - a terminal re-orders bidi text and will
    lie to you about what is stored. The subject "RE: ׳”׳¦׳¢׳× ׳׳—׳™׳¨ A26004904" is stored as:

        E(69) R(82) :(58) space  ׳” ׳¦ ׳¢ ׳×  space  ׳ ׳— ׳™ ׳¨  space  4 0 9 4 0 0 6 2 A

    so the letters are reversed, "RE" -> "ER", while the colon stays at the end. Reversing the
    whole run produced ":RE". The run is now split: a tail of :;!? is peeled off, the core is
    reversed, and the tail is put back unchanged.

    THREE characters are deliberately NOT in that set, each for its own reason:

      '.' and ','  are numeric separators here far more often than sentence punctuation. 24 device
                   descriptions store a leading decimal fraction such as ".0005" as "'5000." -
                   the period has to travel with the reversal to land back in front. Peeling it
                   produced "0005'." Measured on STAGE before shipping; this is why the set is
                   narrow.

      brackets     a mirrored pair has to travel with the reversal. Reversing ")3-1M(" is what
                   turns it back into "(M1-3)"; peeling would break what already worked.

    A ':' inside a run - a time like "10:30" - is untouched, because only a TRAILING run of these
    characters is peeled.

    AMBIGUOUS RUNS ARE LEFT ALONE. Priority does not place the neutral consistently: "RE:" is
    stored "ER:" with the colon last, but "FW:" is stored ":WF" with it first, because the bidi
    algorithm resolves a neutral from whatever surrounds it. When a run carries one of these
    characters at BOTH ends - ":dwF:" from a forwarded chain - there is no way to tell which end
    is the sentence punctuation, so nothing is peeled and the previous whole-run reversal stands.
    Better an unchanged oddity than a confidently wrong repair.

    What it cannot recover, and callers must not assume it does:
      - the case of Latin letters. "MN 622-0" becomes "NM 0-226"; the instrument is 0-226 Nm.
      - the order of several runs separated by Hebrew or spaces.
    dbo.CrmDeviceDescription.NeedsReview marks both cases.
*/
CREATE OR ALTER FUNCTION dbo.fnUnreverseVisualText(@s NVARCHAR(400))
RETURNS NVARCHAR(400)
AS
BEGIN
    IF @s IS NULL RETURN NULL;

    DECLARE @out  NVARCHAR(400) = N'',
            @run  NVARCHAR(400) = N'',
            @tail NVARCHAR(400) = N'',
            @i    INT = 1,
            @n    INT = LEN(@s),
            @c    NCHAR(1);

    /* Neutrals that trail an LTR run in logical order and are left in place by Priority.
       Deliberately excludes '.' ',' and brackets - see the header. */
    DECLARE @trailing NVARCHAR(10) = N':;!?';

    WHILE @i <= @n
    BEGIN
        SET @c = SUBSTRING(@s, @i, 1);
        IF (UNICODE(@c) BETWEEN 1424 AND 1535) OR @c = N' '   -- 0x0590..0x05FF is Hebrew
        BEGIN
            SET @tail = N'';
            /* Only peel when the run does not ALSO start with one of these - see the header. */
            IF LEN(@run) > 0 AND CHARINDEX(LEFT(@run, 1), @trailing) = 0
                WHILE LEN(@run) > 0 AND CHARINDEX(RIGHT(@run, 1), @trailing) > 0
                BEGIN
                    SET @tail = RIGHT(@run, 1) + @tail;
                    SET @run  = LEFT(@run, LEN(@run) - 1);
                END

            SET @out = @out + REVERSE(@run) + @tail + @c;
            SET @run = N'';
        END
        ELSE
            SET @run = @run + @c;
        SET @i += 1;
    END

    /* Same peel for a run that ends the string. */
    SET @tail = N'';
    IF LEN(@run) > 0 AND CHARINDEX(LEFT(@run, 1), @trailing) = 0
        WHILE LEN(@run) > 0 AND CHARINDEX(RIGHT(@run, 1), @trailing) > 0
        BEGIN
            SET @tail = RIGHT(@run, 1) + @tail;
            SET @run  = LEFT(@run, LEN(@run) - 1);
        END

    RETURN @out + REVERSE(@run) + @tail;
END

GO
/* ===== stg.MergeCustomersContactsData ===== */
GO
CREATE OR ALTER PROCEDURE [stg].[MergeCustomersContactsData]
-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 04/06/2025
-- Description:	Merge customer contact data and create user for them to be able login to app
-- JiraLink: 
-- =============================================
AS
BEGIN

	SET NOCOUNT ON;

	MERGE INTO [dbo].[CustomerContacts] AS dest
	USING (
		SELECT 
			 c.[CustomerId]
			,cc.[CustomerContactName]
			,cc.[CustomerContactPersonRole]
			,cc.[CustomerContactPhone]
			,cc.[CustomerContactAdditionalPhoneNumber]
			,cc.[CustomerContactEmail]
			,cc.[CustomerContactIdFromSource]
			,ss.SourceId as [SourceId]
			,0 [UpdateUserID]
			,ISNULL(cc.[IsPrimary],0) as [IsPrimary]
			,ISNULL(cc.[DoNotMail],0) as [DoNotMail]
		FROM stg.stg_CustomerContacts as cc
		JOIN dbo.Source as ss ON cc.SourceSystem = ss.SourceName
		JOIN [dbo].[Customers] as c ON cc.[CustomerId] = c.[CustomerIdFromSource] AND c.[SourceId] = ss.SourceId 
		) AS source
		ON dest.CustomerContactIdFromSource = source.CustomerContactIdFromSource
			AND dest.[SourceId] = source.[SourceId]
	/* This used to AND every comparison together, so a row only updated when EVERY field had
	   changed at once - which never happens, and one of the lines even tested for equality.
	   OR is what was meant: update when anything differs. */
	WHEN MATCHED
		AND (   ISNULL(dest.[CustomerContactName],N'')                  <> ISNULL(source.[CustomerContactName],N'')
			 OR ISNULL(dest.[CustomerContactPersonRole],N'')            <> ISNULL(source.[CustomerContactPersonRole],N'')
			 OR ISNULL(dest.[CustomerContactPhone],N'')                 <> ISNULL(source.[CustomerContactPhone],N'')
			 OR ISNULL(dest.[CustomerContactAdditionalPhoneNumber],N'') <> ISNULL(source.[CustomerContactAdditionalPhoneNumber],N'')
			 OR ISNULL(dest.[CustomerContactEmail],N'')                 <> ISNULL(source.[CustomerContactEmail],N'')
			 OR ISNULL(dest.[IsPrimary],0)                              <> source.[IsPrimary]
			 OR ISNULL(dest.[DoNotMail],0)                              <> source.[DoNotMail])
		THEN
			UPDATE
			SET  dest.[CustomerId] = source.[CustomerId]
				,dest.[CustomerContactName] = source.[CustomerContactName]
				,dest.[CustomerContactPersonRole] = source.[CustomerContactPersonRole]
				,dest.[CustomerContactPhone] = source.[CustomerContactPhone]
				,dest.[CustomerContactAdditionalPhoneNumber] = source.[CustomerContactAdditionalPhoneNumber]
				,dest.[CustomerContactEmail] = source.[CustomerContactEmail]
				,dest.[CustomerContactIdFromSource] = source.[CustomerContactIdFromSource]
				,dest.[IsPrimary] = source.[IsPrimary]
				,dest.[DoNotMail] = source.[DoNotMail]
				,dest.[UpdatedDate] = GETDATE()
				,dest.[UpdateUserID] = 0
	WHEN NOT MATCHED
		THEN
			INSERT (
				 [CustomerId]
				,[CustomerContactName]
				,[CustomerContactPersonRole]
				,[CustomerContactPhone]
				,[CustomerContactAdditionalPhoneNumber]
				,[CustomerContactEmail]
				,[CustomerContactIdFromSource]
				,[SourceId]
				,[UpdateUserID]
				,[IsPrimary]
				,[DoNotMail]
				)
			VALUES (
				 source.[CustomerId]
				,source.[CustomerContactName]
				,source.[CustomerContactPersonRole]
				,source.[CustomerContactPhone]
				,source.[CustomerContactAdditionalPhoneNumber]
				,source.[CustomerContactEmail]
				,source.[CustomerContactIdFromSource]
				,source.[SourceId]
				,source.[UpdateUserID]
				,source.[IsPrimary]
				,source.[DoNotMail]
				);
/*
--Add customer contact as a user
	DECLARE @UserRoleId INT
	SELECT @UserRoleId = UserRoleId FROM UserRoles
	WHERE UserRoleDescriptionENG = N'Customer'

	MERGE INTO [dbo].[Users] AS dest
	USING (
		SELECT 
			 IIF(CHARINDEX(N' ', c.CustomerContactName) > 0,LEFT(c.CustomerContactName, CHARINDEX(N' ', c.CustomerContactName) - 1),'') as [FirstName]
			,IIF(CHARINDEX(N' ', REVERSE(c.CustomerContactName)) > 0,RIGHT(c.CustomerContactName,CHARINDEX(N' ', REVERSE(c.CustomerContactName)) - 1),'') as [LastName]
			,c.[CustomerContactEmail] as [Email]
			,1234 AS [Password]
			,IIF(LEN(c.[CustomerContactPhone]) > 0,c.[CustomerContactPhone], c.[CustomerContactAdditionalPhoneNumber]) as [Phone]
			,1 as [IsActive]
			,0 as [UpdateUserID]
			,@UserRoleId as[UserRoleId]
			,c.[SourceId]
	FROM [dbo].[CustomerContacts] as c
	WHERE LEN(c.[CustomerContactEmail]) > 0
		) AS source
		ON dest.[Email] = source.[Email]
	/*WHEN MATCHED
		THEN
			UPDATE
			SET  dest.[FirstName] = source.[FirstName]
				,dest.[LastName] = source.[LastName]
				,dest.[Password] = source.[Password]
				,dest.[Phone] = source.[Phone]
				,dest.[IsActive] = source.[IsActive]
				,dest.[UpdateUserID] = source.[UpdateUserID]
				,dest.[UserRoleId] = source.[UserRoleId]
				,dest.[SourceId] = source.[SourceId]*/
	WHEN NOT MATCHED BY TARGET
		THEN
			INSERT (
				 [FirstName]
				,[LastName]
				,[Email]
				,[Password]
				,[Phone]
				,[IsActive]
				,[UpdateUserID]
				,[UserRoleId]
				,[SourceId]
				)
			VALUES (
				 source.[FirstName]
				,source.[LastName]
				,source.[Email]
				,source.[Password]
				,source.[Phone]
				,source.[IsActive]
				,source.[UpdateUserID]
				,source.[UserRoleId]
				,source.[SourceId]
				);
				*/

END

GO
/* ===== stg.MergeOrdersData ===== */
GO

-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 02/04/2025
-- Description:	Merge orders data from amaba
-- JiraLink: 
-- =============================================
CREATE OR ALTER PROCEDURE [stg].[MergeOrdersData]
AS
BEGIN

SET NOCOUNT ON;

/*Clean-up Main categories*/

UPDATE t
SET MainCategorySourceId =
    CASE LTRIM(RTRIM(t.MainCategorySourceId))
        WHEN N'אורך'                    THEN N'אורך וזווית'
        WHEN N'אורך מדוייקים'           THEN N'אורך וזווית'
        WHEN N'אל חמה'                  THEN N'NA'
        WHEN N'אלקטרוניקה'              THEN N'אלקטרוניקה'
        WHEN N'בדיקות דגם'              THEN N'NA'
        WHEN N'גלאי גזים'               THEN N'גזים'
        WHEN N'גפן'                     THEN N'NA'
        WHEN N'זמן'                     THEN N'זמן'
        WHEN N'טמפרטורה'                THEN N'טמפרטורה ולחות'
        WHEN N'כח'                      THEN N'כוח'
        WHEN N'לחות'                    THEN N'טמפרטורה ולחות'
        WHEN N'לחץ'                     THEN N'לחץ'
        WHEN N'ללא מחלקה'               THEN N'NA'
        WHEN N'מאגנוס'                  THEN N'אלקטרוניקה'
        WHEN N'מדידים'                  THEN N'אורך וזווית'
        WHEN N'מהירות אוויר'            THEN N'מהירות אוויר'
        WHEN N'מומנט'                   THEN N'מומנט'
        WHEN N'מכונות'                  THEN N'NA'
        WHEN N'מסה'                     THEN N'מסה'
        WHEN N'מקבילונים'               THEN N'אורך וזווית'
        WHEN N'נפח'                     THEN N'נפח'
        WHEN N'סיבוב'                   THEN N'אורך וזווית'
        WHEN N'ספיקה'                   THEN N'ספיקה'
        WHEN N'קבלני משנה'              THEN N'NA'
        WHEN N'קבלני משנה כללי'         THEN N'NA'
        WHEN N'קושי'                    THEN N'קשיות'
        WHEN N'רדיומטריה ופוטומטריה'    THEN N'רדיומטריה'
        WHEN N'שירותי איכות ורגולציה'   THEN N'NA'
        WHEN N'תעשיה אוירית'            THEN N'NA'
        ELSE t.MainCategorySourceId
    END
FROM [stg].[stg_Orders] AS t;



DROP TABLE IF EXISTS #OrderStatus
CREATE TABLE #OrderStatus
(
StatusId INT NOT NULL,
CodeINT INT,
StatusType NVARCHAR(50)COLLATE Latin1_General_100_CI_AI_SC,
Code NVARCHAR(255) COLLATE Latin1_General_100_CI_AI_SC,
StatusDescriptionENG NVARCHAR(255) COLLATE Latin1_General_100_CI_AI_SC
)
INSERT #OrderStatus (StatusId,CodeINT,StatusType,Code,StatusDescriptionENG)
SELECT s.StatusId, TRY_CAST(s.Code AS INT) as CodeINT, sc.StatusDescriptionENG as StatusType, s.Code ,s.StatusDescriptionENG
FROM [dbo].[Statuses] as s
JOIN [dbo].[StatusesCategories] as sc ON s.StatusCategoryId = sc.StatusCategoryId
WHERE sc.StatusDescriptionENG IN('OrderStatus','ReportStatus','CalibrationStatuses')

DECLARE @InintialOrderStatus INT  
SELECT @InintialOrderStatus = StatusId FROM #OrderStatus as os WHERE os.StatusType = N'OrderStatus' AND os.StatusDescriptionENG = 'WaitingForCalibration'

MERGE INTO [dbo].[OrderWorkPlans] AS dest
USING (
SELECT DISTINCT
	     o.ORDNAME as [OrderNumber]
		,o.OpenDate as [WorkPlanOpenDate]
		,GETDATE() AS [CreatedDate]
		,0 as [UpdateUserID]
		,0 as [CreatedByUserId]
		,0 as [IsCancelled]
		,c.[CustomerId]
		,NULL as [Notes]
		,ss.[SourceId]
		,@InintialOrderStatus as OrderOverallStatusId
		,IIF(LEN(o.[ShipTypeDesc]) > 1,o.[ShipTypeDesc],NULL) as [ShipTypeDesc]
		,o.SourceOrderId as [OrderSourceId]
		FROM [stg].[stg_Orders] as o
	JOIN [dbo].[Source] as ss ON o.[SourceSystem] = ss.SourceName
    LEFT JOIN [dbo].[Customers] as c ON c.CustomerIdFromSource = o.CustomerSourceId AND c.SourceId = ss.SourceId AND c.IsDeleted = 0
	) AS source
	ON dest.[OrderSourceId] = source.[OrderSourceId] AND dest.[SourceId] = source.[SourceId]
WHEN NOT MATCHED BY TARGET
	THEN
		INSERT (
             [OrderNumber]
			,[WorkPlanOpenDate]
			,[CreatedDate]
			,[CreatedByUserId]
			,[UpdateUserID]
			,[IsCancelled]
			,[Notes]
			,[OrderSourceId]
			,[SourceId]
			,[CustomerId]
			,[OrderOverallStatusId]
			,[ShipTypeDesc]
			)
		VALUES (
			 source.[OrderNumber]
			,source.[WorkPlanOpenDate]
			,source.[CreatedDate]
			,source.[CreatedByUserId]
			,source.[UpdateUserID]
			,source.[IsCancelled]
			,source.[Notes]
			,source.[OrderSourceId]
			,source.[SourceId]
			,source.[CustomerId]
			,source.[OrderOverallStatusId]
			,source.[ShipTypeDesc]

			);


MERGE INTO [dbo].[OrderDetails] AS dest
USING (
	SELECT DISTINCT
	    wp.[OrderWorkPlanId]
		,o.[SpecialCareTypeId]
		,CASE 
			WHEN RIGHT(o.[PartName], 2) IN ('-7','-8','-9') AND TRY_CAST(RIGHT(o.[PartName], 2) AS INT) IS NOT NULL THEN 0 
			WHEN RIGHT(o.[PartName], 2) IN ('-3','-0','-1') AND TRY_CAST(RIGHT(o.[PartName], 2) AS INT) IS NOT NULL THEN 1 --10 should be external 
		ELSE NULL END  as [IsInHouse]
		,o.[PartName]
		--,o.[KLINE]
		,o.[PART]
		,GETDATE() as [CreatedDate]
		,GETDATE() as [UpdatedDate]
		,0 as [CreatedByUserId]
		,0 as [UpdateUserID]
		,o.OrderLineCnt
		,pt.OrdersProductTypeId
		,o.DeviceType 
		,o.OrderDetailId as OrderDetailSourceId
		,o.VPRICE	
		,o.PRICE
		,mc.[ID] as [MainCategoryId]
		,sc.ID as [SecondaryCategoryId]
		,o.[CustomerPackingExists]
	    ,o.[PackageLocation]
		,cs.CustomerSiteId
	FROM [stg].[stg_Orders] as o
	JOIN [dbo].[Source] as s ON o.SourceSystem = s.SourceName
	JOIN [dbo].[OrderWorkPlans] as wp ON wp.OrderSourceId = o.SourceOrderId AND o.SourceSystem = s.SourceName
	LEFT JOIN [dbo].[OrdersProductTypes] as pt ON pt.OrdersProductTypeName = o.DeviceType and pt.IsDeleted = 0
	LEFT JOIN [dbo].[MainCategories] as mc ON o.MainCategorySourceId = mc.MainCategoryName and mc.IsDeleted = 0
	LEFT JOIN [dbo].[SecondaryCategories] as sc ON o.SecondCategorySourceId = sc.SecondaryCategoryName and sc.IsDeleted = 0
    LEFT JOIN [dbo].[Customers] as c ON c.CustomerIdFromSource = o.CustomerSourceId AND c.SourceId = s.SourceId AND c.IsDeleted = 0
	LEFT JOIN [dbo].[CustomerSites] as cs ON c.CustomerId = cs.CustomerId AND cs.CustomerSiteCode = o.[DESTCODE] AND cs.IsDeleted = 0
	) AS source
	ON dest.[OrderWorkPlanId] = source.[OrderWorkPlanId] AND source.OrderDetailSourceId = dest.[OrderDetailSourceId] 
WHEN MATCHED AND
	(
		  COALESCE(dest.[SpecialCareTypeId],0) <> COALESCE(source.[SpecialCareTypeId],0)
		OR COALESCE(dest.[IsInHouse],0) <> COALESCE(source.[IsInHouse],0)
		OR COALESCE(dest.[OrderLineCnt],0) <> COALESCE(source.[OrderLineCnt],0)
		OR COALESCE(dest.OrdersProductTypeId,0) <> COALESCE(source.[OrdersProductTypeId],0)
		OR COALESCE(dest.[PART],0) <> COALESCE(source.[PART],0)
		OR COALESCE(dest.[VPRICE],0) <> COALESCE(source.[VPRICE],0)
		OR COALESCE(dest.[PRICE],0) <> COALESCE(source.[PRICE],0)
		OR COALESCE(dest.[MainCategoryId],0) <> COALESCE(source.[MainCategoryId],0)
		OR COALESCE(dest.[SecondaryCategoryId],0) <> COALESCE(source.[SecondaryCategoryId],0)
		OR COALESCE(dest.[CustomerPackingExists],0) <> COALESCE(source.[CustomerPackingExists],0) 
		OR COALESCE(dest.[CustomerSiteId],0) <> COALESCE(source.[CustomerSiteId],0)
		OR COALESCE(dest.[PackageLocation],'') <> COALESCE(source.[PackageLocation],'')
		OR COALESCE(dest.[PartName],'') <> COALESCE(source.[PartName],'')
	)
	THEN
		UPDATE
		SET  dest.[SpecialCareTypeId] = source.[SpecialCareTypeId]
			,dest.[IsInHouse] = source.[IsInHouse]
			,dest.[UpdatedDate] = source.[UpdatedDate]
			,dest.[UpdateUserID] = source.[UpdateUserID]
			,dest.[OrderLineCnt] = source.[OrderLineCnt]
			,dest.[OrdersProductTypeId] = source.[OrdersProductTypeId]
			,dest.[PART] = source.[PART]
			,dest.[VPRICE] = source.[VPRICE]
			,dest.[PRICE] = source.[PRICE]
			,dest.[MainCategoryId] = source.[MainCategoryId]
			,dest.[SecondaryCategoryId] = source.[SecondaryCategoryId]
			,dest.[CustomerPackingExists] = source.[CustomerPackingExists]
			,dest.[CustomerSiteId] = source.[CustomerSiteId]
			,dest.[PackageLocation] = source.[PackageLocation]
			,dest.[PartName] = source.[PartName]

WHEN NOT MATCHED BY TARGET
	THEN
		INSERT (
			[OrderWorkPlanId]
			,[SpecialCareTypeId]
			,[IsInHouse]
			,[PartName]
			--,[KLINE]
			,[CreatedDate]
			,[UpdatedDate]
			,[CreatedByUserId]
			,[UpdateUserID]
			,[OrderLineCnt]
			,[OrdersProductTypeId]
			,[PART]
			,[OrderDetailSourceId]
			,[VPRICE]	
			,[PRICE]
			,[MainCategoryId]
			,[SecondaryCategoryId]
			,[CustomerPackingExists]
			,[CustomerSiteId]
			,[PackageLocation]
			)
		VALUES (
			 source.[OrderWorkPlanId]
			,source.[SpecialCareTypeId]
			,source.[IsInHouse]
			,source.[PartName]
		--	,source.[KLINE]
			,source.[CreatedDate]
			,source.[UpdatedDate]
			,source.[CreatedByUserId]
			,source.[UpdateUserID]
			,source.[OrderLineCnt]
			,source.[OrdersProductTypeId]
			,source.[PART]
			,source.[OrderDetailSourceId]
			,source.[VPRICE]	
			,source.[PRICE]
			,source.[MainCategoryId]
			,source.[SecondaryCategoryId]
			,source.[CustomerPackingExists]
			,source.[CustomerSiteId]
			,source.[PackageLocation]
			);

MERGE INTO [dbo].[OrderDetailsItems] AS dest
USING (
	SELECT DISTINCT
	     o.[SerialNumber]
		,od.OrderDetailId
		,o.[ManufacturerNumber]
		,REVERSE(o.[Devicemodel]) as [DeviceModel]
		,o.[SpecialCareTypeId]
		,o.[InHouse] as [IsInHouse]
		,o.[PartName]
		,o.[MbaReportNumber]
		,c.[CustomerId]
		,o.[KLINE]
		,o.[SERN]
	    ,o.[ProductLocation]
		,NULL AS [StatusId]
		,GETDATE() as [CreatedDate]
		,GETDATE() as [UpdatedDate]
		,0 as [CreatedByUserId]
		,0 as [UpdateUserID]
		,o.[Doc]
		,o.[NextCalibrationDate]
		,o.AdditionalDeviceNumber
		,NULL /*o.CalibDate*/ as [ActualCalibrationDate]
		--,os.StatusId as CalibrationReportStatusId
		--,IIF(os2.Code <> N'CO',os2.StatusId,-1) as CalibrationStatusId
		,NULL AS CustomerReceivingDate
		,IIF(LEN(o.ShippingDoc) > 1,o.ShippingDoc,NULL) as ShippingDoc
		,IIF(LEN(o.ShippingAddress) > 1,o.ShippingAddress,NULL) as  ShippingAddress
		,o.DOC_N
	    ,IIF(o.[ActualReturnDate] > GETDATE()-100,o.[ActualReturnDate],NULL) as [ActualReturnDate]
	    ,IIF(o.[ExpectedReturnDate] > GETDATE()-100,o.[ExpectedReturnDate],NULL) as [ExpectedReturnDate]
		,o.OrdersDeviceManufacturer
	FROM [stg].[stg_Orders] as o
	JOIN [dbo].[Source] as s ON o.SourceSystem = s.SourceName
	JOIN [dbo].[OrderWorkPlans] as wp ON wp.OrderSourceId = o.SourceOrderId
	JOIN [dbo].[OrderDetails] as od ON wp.[OrderWorkPlanId] = od.[OrderWorkPlanId] AND od.OrderDetailSourceId = o.OrderDetailId
	LEFT JOIN [dbo].[Customers] as c ON c.CustomerIdFromSource = o.CustomerSourceId AND c.SourceId = s.SourceId and c.IsDeleted = 0
	--LEFT JOIN #OrderStatus AS os ON o.CurrentCalibrationStatus = os.Code AND os.StatusType = N'ReportStatus'
	--LEFT JOIN #OrderStatus AS os2 ON o.CurrentCalibrationStatus = os2.Code AND os2.StatusType = N'CalibrationStatuses'
	WHERE o.OrderDetailId IS NOT NULL AND o.Doc IS NOT NULL
	) AS source
	ON dest.OrderDetailId = source.OrderDetailId AND source.[Doc] = dest.[Doc]
  WHEN MATCHED
        AND (
		-- change-detection corrected 2026-08-23: every predicate below is '<>', the group closes
		-- at the END of the list, and dest.[Doc] = source.[Doc] is gone because the MERGE ON
		-- clause already requires it — as a predicate it was always TRUE and on its own forced
		-- an UPDATE of every matched row on every run.
		   COALESCE(dest.[SerialNumber],'') <> COALESCE(source.[SerialNumber],'')
		OR COALESCE(dest.[ManufacturerNumber],'') <> COALESCE(source.[ManufacturerNumber],'')
		OR COALESCE(dest.[DeviceModel],'') <> COALESCE(source.[DeviceModel],'')
		OR COALESCE(dest.[MbaReportNumber],'') <> COALESCE(source.[MbaReportNumber],'')
		OR COALESCE(dest.[UpdatedDate],'1900-01-01') <> source.[UpdatedDate]
		OR COALESCE(dest.[UpdateUserID],0) <> source.[UpdateUserID]
		OR COALESCE(dest.[ProductLocation],'') <> COALESCE(source.[ProductLocation],'')
		OR COALESCE(dest.[NextCalibrationDate],'1900-01-01') <> COALESCE(source.[NextCalibrationDate],'1900-01-01')
		OR COALESCE(dest.[AdditionalDeviceNumber],'') <> COALESCE(source.[AdditionalDeviceNumber],'')
		OR COALESCE(dest.[ActualCalibrationDate],'1900-01-01') <> COALESCE(source.[ActualCalibrationDate],'1900-01-01')
		OR COALESCE(dest.CustomerReceivingDate,'1900-01-01') <> COALESCE(source.CustomerReceivingDate,'1900-01-01')
		OR COALESCE(dest.[ShippingDoc],'') <> COALESCE(source.[ShippingDoc],'')
		OR COALESCE(dest.[ShippingAddress],'') <> COALESCE(source.[ShippingAddress],'')
		OR COALESCE(dest.[DOC_N],0) <> COALESCE(source.[DOC_N],0)
		OR COALESCE(dest.[ActualReturnDate],'1900-01-01') <> COALESCE(source.[ActualReturnDate],'1900-01-01')
		OR COALESCE(dest.[ExpectedReturnDate],'1900-01-01') <> COALESCE(source.[ExpectedReturnDate],'1900-01-01')
		)


	THEN
		UPDATE
		SET  dest.[SerialNumber] = source.[SerialNumber]
			,dest.[ManufacturerNumber] = source.[ManufacturerNumber]
			,dest.[DeviceModel] = source.[DeviceModel]
			,dest.[MbaReportNumber] = source.[MbaReportNumber]
			,dest.[UpdatedDate] = source.[UpdatedDate]
			,dest.[UpdateUserID] = source.[UpdateUserID]
			,dest.[ProductLocation] = source.[ProductLocation]
			,dest.[Doc] = source.[Doc]
			,dest.[NextCalibrationDate] = source.[NextCalibrationDate]
			,dest.[AdditionalDeviceNumber] = source.[AdditionalDeviceNumber]
			,dest.[ActualCalibrationDate] = source.[ActualCalibrationDate]
			--,dest.[CalibrationReportStatusId] = IIF(dest.[UpdateUserID] = 0,source.[CalibrationReportStatusId],dest.[CalibrationReportStatusId])
		   -- ,dest.[CalibrationStatusId] = IIF(dest.[UpdateUserID] = 0 and source.CalibrationStatusId > 0,source.CalibrationStatusId,dest.CalibrationStatusId) -- Calibration status can not be delivered, but on source report and calibration statuses same column 
		    ,dest.[CustomerReceivingDate] = source.[CustomerReceivingDate]
		    ,dest.[ShippingDoc] = source.[ShippingDoc]
		    ,dest.[ShippingAddress] = source.[ShippingAddress]
			,dest.[DOC_N] = source.[DOC_N]
			,dest.[ActualReturnDate] = source.[ActualReturnDate]
			,dest.[ExpectedReturnDate] = source.[ExpectedReturnDate]
			
WHEN NOT MATCHED BY TARGET
	THEN
		INSERT (
			[OrderDetailId]
			,[SerialNumber]
			,[ManufacturerNumber]
			,[DeviceModel]
			,[MbaReportNumber]
			,[CreatedDate]
			,[UpdatedDate]
			,[CreatedByUserId]
			,[UpdateUserID]
			,[SERN]
			,[ProductLocation]
			,[Doc]
			,[NextCalibrationDate]
			,[AdditionalDeviceNumber]
			,[ActualCalibrationDate]
		--	,[CalibrationReportStatusId]
		--  ,[CalibrationStatusId]
		    ,[CustomerReceivingDate]
		    ,[ShippingDoc]
		    ,[ShippingAddress]
			,[DOC_N]
			,[ActualReturnDate]
			,[ExpectedReturnDate]
			,[OrdersDeviceManufacturer]
			)
		VALUES (
			 source.[OrderDetailId]
			,source.[SerialNumber]
			,source.[ManufacturerNumber]
			,source.[DeviceModel]
			,source.[MbaReportNumber]
			,source.[CreatedDate]
			,source.[UpdatedDate]
			,source.[CreatedByUserId]
			,source.[UpdateUserID]
			,source.[SERN]
			,source.[ProductLocation]
			,source.[Doc]
			,source.[NextCalibrationDate]
			,source.[AdditionalDeviceNumber]
			,source.[ActualCalibrationDate]
		--	,source.[CalibrationReportStatusId]
		--  ,NULLIF(source.[CalibrationStatusId],-1)
		    ,source.[CustomerReceivingDate]
		    ,source.[ShippingDoc]
		    ,source.[ShippingAddress]
			,source.[DOC_N]
			,source.[ActualReturnDate]
			,source.[ExpectedReturnDate]
			,source.[OrdersDeviceManufacturer]
			);

			

	/* ---------------------------------------------------------------------------------------
	   Top up the Priority CRM cache (dbo.CrmCatalogText / CrmDeviceText / CrmPartInfo) for any
	   PART/SERN this sync just introduced. Hooked here on purpose: this sync is what creates new
	   keys, so the cache cannot drift and needs no SQL Agent job (the app login is db_owner on
	   Calibrator but has no server-level rights, so it cannot create one).
	   Incremental mode costs ~0.1s and issues NO linked-server traffic when nothing is new.
	   TRY/CATCH: a CRM top-up must never fail the order sync.
	   --------------------------------------------------------------------------------------- */
	BEGIN TRY
		EXEC dbo.RefreshCrmTextCache @IncrementalOnly = 1;
		/* Re-derive device categories from the Priority family. Must run AFTER the cache top-up
		   (it reads dbo.CrmPartInfo) and after the MERGEs above, which write MainCategoryId back
		   from staging for the rows in the rolling window and would otherwise undo the derivation
		   on exactly those rows. */
		EXEC dbo.ApplyPartFamilyCategories;
	END TRY
	BEGIN CATCH
		/* swallowed on purpose - see above */
	END CATCH
END

GO