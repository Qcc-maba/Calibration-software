/*
    Seed dbo.PriorityCalibrationStatusCodes                                            MBA-911
    ---------------------------------------------------------------------------------------------
    Writes OUR half of each Priority calibration status code: English description, who writes it,
    its stage, and - where one exists - the dbo.Statuses order status it corresponds to.
    The Hebrew text and Priority's own id come from Priority on every run of
    dbo.RefreshPriorityCalibrationStatus, so this file holds no Hebrew (sqlcmd mangles it).

    Sources for the meanings: Priority's MBA_CALIBSTATUSES, and the lab's own status document
    (the lab's status overview, which also says CD is written on the FIRST report only and that
    TX locks the report so only update reports may follow).

    OrderStatusName is a NAME in dbo.Statuses (category OrderStatus), resolved at read time because
    ids differ between STAGE and PROD. Left NULL where no status matches, and for CO until the lab
    confirms what "collected" means (asked on MBA-911). Nothing reads it yet: the work-plan roll-up
    is a separate, later step.

    AppMayWrite marks the codes the Calibrator app may report (dbo.RecordPriorityStatusEvent reads
    it): the calibration-software codes except PR, UP and UX, which the app does not produce.

    Idempotent: writes only rows that differ. @Apply = 0 (default) reports and writes nothing.
*/
SET NOCOUNT ON;
DECLARE @Apply BIT = 0;

/* COLLATE DATABASE_DEFAULT: a table variable takes the SERVER collation, which is not the
   database's on these servers, and the comparisons below with dbo.Statuses would fail. */
DECLARE @Seed TABLE
(
    StatusCode      CHAR(2)       COLLATE DATABASE_DEFAULT NOT NULL PRIMARY KEY,
    DescriptionENG  NVARCHAR(100) COLLATE DATABASE_DEFAULT NOT NULL,
    WrittenBy       VARCHAR(20)   COLLATE DATABASE_DEFAULT NOT NULL,
    Stage           VARCHAR(20)   COLLATE DATABASE_DEFAULT NOT NULL,
    SortOrder       TINYINT       NOT NULL,
    OrderStatusName NVARCHAR(100) COLLATE DATABASE_DEFAULT NULL,
    AppMayWrite     BIT           NOT NULL
);

INSERT INTO @Seed VALUES
 ('AA', N'Received',                                  'Priority',            'Intake',         10, N'Received', 0),
 ('KM', N'Sent to subcontractor',                     'Priority',            'Subcontractor',  15, NULL, 0),
 ('AC', N'Calibration opened',                        'CalibrationSoftware', 'Calibration',    20, NULL, 1),
 ('DC', N'On hold (customer reason)',                 'CalibrationSoftware', 'OnHold',         25, NULL, 1),
 ('DM', N'On hold (MBA reason)',                      'CalibrationSoftware', 'OnHold',         26, NULL, 1),
 ('FC', N'Calibration resumed after hold',            'CalibrationSoftware', 'Calibration',    30, NULL, 1),
 ('CD', N'Calibration date (first report generated)', 'CalibrationSoftware', 'Report',         35, NULL, 1),
 ('GR', N'Calibration report generated',              'CalibrationSoftware', 'Report',         40, N'ReportGenerated', 1),
 ('PR', N'Computerized PDF created',                  'CalibrationSoftware', 'Report',         45, NULL, 0),
 ('H1', N'First signature',                           'CalibrationSoftware', 'Signature',      50, NULL, 1),
 ('HR', N'Report rejected by approver',               'CalibrationSoftware', 'Signature',      55, N'Rejected', 1),
 ('H2', N'Second signature',                          'CalibrationSoftware', 'Signature',      60, NULL, 1),
 ('UC', N'Update report opened',                      'CalibrationSoftware', 'UpdateReport',   70, NULL, 1),
 ('UD', N'Update report on hold (customer reason)',   'CalibrationSoftware', 'UpdateReport',   72, NULL, 1),
 ('UM', N'Update report on hold (MBA reason)',        'CalibrationSoftware', 'UpdateReport',   73, NULL, 1),
 ('UF', N'Update report resumed after hold',          'CalibrationSoftware', 'UpdateReport',   74, NULL, 1),
 ('UG', N'Update report generated',                   'CalibrationSoftware', 'UpdateReport',   76, NULL, 1),
 ('UP', N'Update report PDF created',                 'CalibrationSoftware', 'UpdateReport',   78, NULL, 0),
 ('UX', N'Update report sent to customer',            'CalibrationSoftware', 'UpdateReport',   80, NULL, 0),
 ('PI', N'Shipment packed',                           'Priority',            'Shipping',       85, N'Packed', 0),
 ('CO', N'Shipment collected',                        'Priority',            'Shipping',       90, NULL, 0),
 ('TX', N'Device sent to customer',                   'Priority',            'Shipping',       95, N'Sent', 0);

/* A name that matches no order status would silently map to nothing at read time. Say so now. */
SELECT s.StatusCode, s.OrderStatusName AS UnknownOrderStatusName
FROM @Seed AS s
WHERE s.OrderStatusName IS NOT NULL
  AND NOT EXISTS (SELECT 1
                  FROM dbo.Statuses AS st
                  JOIN dbo.StatusesCategories AS sc ON sc.StatusCategoryId = st.StatusCategoryId
                  WHERE sc.StatusDescriptionENG = N'OrderStatus'
                    AND st.StatusDescriptionENG = s.OrderStatusName);

SELECT s.*,
       CASE WHEN c.StatusCode IS NULL THEN 'insert' ELSE 'update' END AS Action_
INTO #Diff
FROM @Seed AS s
LEFT JOIN dbo.PriorityCalibrationStatusCodes AS c ON c.StatusCode = s.StatusCode
WHERE c.StatusCode IS NULL
   OR c.DescriptionENG <> s.DescriptionENG
   OR c.WrittenBy      <> s.WrittenBy
   OR c.Stage          <> s.Stage
   OR c.SortOrder      <> s.SortOrder
   OR ISNULL(c.OrderStatusName, N'') <> ISNULL(s.OrderStatusName, N'')
   OR c.AppMayWrite    <> s.AppMayWrite;

SELECT Action_, COUNT(*) AS Codes FROM #Diff GROUP BY Action_;

IF @Apply = 1
BEGIN
    MERGE dbo.PriorityCalibrationStatusCodes AS dest
    USING #Diff AS src ON dest.StatusCode = src.StatusCode
    WHEN MATCHED THEN UPDATE SET
         dest.DescriptionENG  = src.DescriptionENG,
         dest.WrittenBy       = src.WrittenBy,
         dest.Stage           = src.Stage,
         dest.SortOrder       = src.SortOrder,
         dest.OrderStatusName = src.OrderStatusName,
         dest.AppMayWrite     = src.AppMayWrite,
         dest.UpdatedAt       = SYSUTCDATETIME()
    WHEN NOT MATCHED BY TARGET THEN
         INSERT (StatusCode, DescriptionENG, WrittenBy, Stage, SortOrder, OrderStatusName, AppMayWrite)
         VALUES (src.StatusCode, src.DescriptionENG, src.WrittenBy, src.Stage, src.SortOrder,
                 src.OrderStatusName, src.AppMayWrite);

    SELECT @@ROWCOUNT AS CodesWritten;
END
ELSE
    SELECT StatusCode, Action_, DescriptionENG, WrittenBy, Stage, OrderStatusName, AppMayWrite FROM #Diff
    ORDER BY StatusCode;

DROP TABLE #Diff;
