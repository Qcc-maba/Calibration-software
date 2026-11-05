/*
    Putting the lab's precision sensors' ITS-90 coefficients on file                    MBA-831
    ---------------------------------------------------------------------------------------------
    The station converts a precision master's resistance to temperature with that sensor's own
    coefficients (dbo.GetSensorCoefficients) and refuses a master with none on file. Only 21-214
    was seeded (Save-Sensor-21-214-Coefficients.sql). Nofar (Jira 38167, 2026-11-05): the 34401A
    can use any of the lab's precision sensors as master, and she attached the lab's register,
    PT100.xls, to load them.

    These are the values of PT100.xls, sheet "סדר הרגשים", copied from the cells (not retyped),
    with the certificate number and update date of each row kept in the table below. Left out:
      - 21-48, 21-169 (TC-R thermocouples) and 21-100 (Pt-100 ASTM): all six values are 0 there.
      - 21-500: two live devices carry that MabaID on STAGE (691, 4645) - waiting for Nofar to say
        which one; dbo.SaveSensorCoefficients refuses an ambiguous MabaID.
    21-214 is included and reports NoChange (same values as the earlier seed).

    NOT YET CONFIRMED: a plausibility check against a typical sensor curve puts these sensors off by
    degrees in part of the range - 21-290, 21-347, 21-697, 21-699, 21-186 (above 0 C) and 21-344,
    21-291, 21-308, 21-343, 21-235 (below 0 C). They are loaded as PT100.xls has them; Nofar is
    checking them against the certificates (Jira, 2026-11-05). A corrected set is a new run of
    this script: the procedure adds a row when the values differ, and the station reads the newest.

    Run it on a server only after dbo.ConversionParameters' MBA-816 columns and
    dbo.SaveSensorCoefficients are there (PROD did not have them on 2026-11-05).

    @Apply = 0 (default) reports what would be saved and writes nothing. Before anything is saved,
    every MabaID must name exactly one live device; otherwise the script stops and saves nothing.
    Each sensor is saved in its own transaction, so a re-run after a failure picks up where it
    stopped: sensors already saved report NoChange.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @Apply BIT = 0;
DECLARE @LoggedInUserEmail NVARCHAR(255) = N'ezequiel_lo@mba.co.il';

DECLARE @Sensors TABLE
(
    MabaID      NVARCHAR(50)   NOT NULL PRIMARY KEY,
    RTP         DECIMAL(35,15) NOT NULL,
    A4          DECIMAL(35,15) NOT NULL,
    B4          DECIMAL(35,15) NOT NULL,
    A7          DECIMAL(35,15) NOT NULL,
    B7          DECIMAL(35,15) NOT NULL,
    C7          DECIMAL(35,15) NOT NULL,
    Certificate NVARCHAR(50)   NOT NULL,   /* PT100.xls "מספר דוח" */
    UpdatedOn   DATE           NOT NULL    /* PT100.xls "תאריך עדכון" */
);

INSERT @Sensors (MabaID, RTP, A4, B4, A7, B7, C7, Certificate, UpdatedOn)
VALUES
    (N'21-99', 25.40122, -0.0000932601, 0.00001366983, -0.0001088893, -0.00002064005, 0.000003473768, N'1012-KL-25030-21', '2025-12-10'),
    (N'21-417', 100.0268, -0.020773654, -0.00467749428, -0.020294836, 0.0000285539, -0.00041890985, N'2603003/85', '2026-03-18'),
    (N'21-418', 100.0216, -0.020110641, -0.00153123634, -0.02011322, -0.00072369306, 0.00032838868, N'2602003-48', '2026-03-18'),
    (N'21-214', 100.0018614, -0.0188349, 0.00064590173677, -0.01943119, -0.00032928408, 0.00022327774, N'2308008/52', '2023-08-21'),
    (N'21-199', 25.4348, -0.00009915909, -0.00001555931, 0.000001177548, -0.00009814489, 0.00003786818, N'2209010/65', '2022-11-29'),
    (N'21-344', 25.4882, 0.01353699686, 0.527934543, -0.0006095767, 0.00041471139, -0.00013587203, N'2507007-37', '2025-06-18'),
    (N'21-186', 99.9857, -0.019557580101, -0.000638130037, -0.021069156835, 0.021257451101, -0.07564678451, N'2402002/23', '2024-02-22'),
    (N'21-117', 100.015, -0.01856638132, 0.00049916669, -0.019127279, 0.00005169923, 0.00002497359, N'2406006/32', '2024-06-03'),
    (N'21-308', 25.60823373, -0.003123677, -0.054564288, -0.001096897, 0.00032444381, -0.0001206932, N'2609010/8', '2026-08-31'),
    (N'21-110', 99.9909, -0.01882266, 0.0003071388, -0.01908874, 0.0002660229, -0.0005409444, N'2409009/86', '2024-09-12'),
    (N'21-290', 99.997, -0.019434243194, -0.000299477263, -0.048912658616, 1.0868215463, -8.477109641514, N'2509009/', '2025-07-17'),
    (N'21-235', 100.0388, -0.019555976, -0.036798137, -0.020159388, 0.00076062892, -0.00025078064, N'2607007-46', '2026-07-19'),
    (N'21-250', 100.0169, -0.01969534, -0.00235292, -0.01860102, -0.005352377, 0.008638784, N'2504004/35', '2025-03-27'),
    (N'21-291', 100.0101, -0.017799321, 0.07382291, -0.0191755232, 0.0003466241126, -0.000125262893, N'2601001-51', '2026-01-11'),
    (N'21-416', 100.0114, -0.020121826, -0.00157855197, -0.019948647, -0.00039754723, -0.00009148603, N'2303003/39', '2023-03-07'),
    (N'21-343', 25.712, -0.00226580205, -0.0417590726, -0.000277015693, -0.000086672163, 0.00002929221723, N'2312012/47', '2023-12-13'),
    (N'21-477', 99.988, -0.018969718, 0.0004474437, -0.020185480584, 0.0009196592828, -0.0003776448273, N'2502002-85', '2025-01-27'),
    (N'21-478', 99.9837, -0.018958917, 0.0000289225, -0.020017295211, 0.0008492661437, -0.0003718080764, N'2502002-86', '2025-01-27'),
    (N'21-347', 99.94326, -0.01414587, 0.0652374717, -0.01718893, 0.0503087094, -0.51307995, N'2403003-98', '2024-04-10'),
    (N'21-695', 100.0179762, -0.01990047, -0.00137731194, -0.01818790207, -0.004883047942, 0.003533745, N'2409009/87', '2024-08-13'),
    (N'21-696', 100.022096, -0.01892142, 0.00021723995981, -0.02063853, 0.002498412837, -0.0021471931, N'2409009-88', '2024-09-04'),
    (N'21-697', 100.0179, -0.019599547862, -0.000623988893, -0.023584746183, 0.055983632412, -0.273125474463, N'2409009/89', '2024-08-20'),
    (N'21-698', 100.013096, -0.01881581, 0.00048811128312, -0.02049041, 0.002207927776, -0.00181614, N'2409009', '2024-09-04'),
    (N'21-699', 100.0102, -0.019440355759, -0.000504030812, -0.020942198254, 0.030826444019, -0.180754199331, N'2409009/90', '2024-08-21'),
    (N'21-700', 100.0164, -0.01884546, -0.00095323517363, -0.01981613, -0.00022597604, 0.000076420023, N'2409009/91', '2024-09-16');

/* ---- every MabaID must name exactly one live device, or nothing is saved ---- */
DECLARE @Unresolved NVARCHAR(MAX) =
(
    SELECT STRING_AGG(CONCAT(s.MabaID, N' (', d.Live, N' live)'), N', ')
    FROM @Sensors AS s
    CROSS APPLY (SELECT COUNT(*) AS Live
                 FROM dbo.MeasurementDevices AS md
                 WHERE LTRIM(RTRIM(md.MabaID)) = s.MabaID COLLATE DATABASE_DEFAULT
                   AND md.IsDeleted = 0) AS d
    WHERE d.Live <> 1
);
IF @Unresolved IS NOT NULL
BEGIN
    DECLARE @Message NVARCHAR(2048) = CONCAT(N'Nothing saved - these MabaIDs do not name exactly one live device: ', @Unresolved);
    THROW 51000, @Message, 1;
END;

/* ---- one call per sensor ---- */
CREATE TABLE #Outcome
(
    Outcome               NVARCHAR(10),
    ConversionParameterId INT,
    MeasurementDevicesId  INT,
    MabaID                NVARCHAR(50) COLLATE DATABASE_DEFAULT,
    RTP DECIMAL(35,15), A4 DECIMAL(35,15), B4 DECIMAL(35,15),
    A7  DECIMAL(35,15), B7 DECIMAL(35,15), C7 DECIMAL(35,15),
    OrderDetailsItemId    INT
);

DECLARE @MabaID NVARCHAR(50), @RTP DECIMAL(35,15), @A4 DECIMAL(35,15), @B4 DECIMAL(35,15),
        @A7 DECIMAL(35,15), @B7 DECIMAL(35,15), @C7 DECIMAL(35,15);

DECLARE sensor CURSOR LOCAL FAST_FORWARD FOR
    SELECT MabaID, RTP, A4, B4, A7, B7, C7 FROM @Sensors ORDER BY MabaID;
OPEN sensor;
FETCH NEXT FROM sensor INTO @MabaID, @RTP, @A4, @B4, @A7, @B7, @C7;
WHILE @@FETCH_STATUS = 0
BEGIN
    INSERT #Outcome
    EXEC dbo.SaveSensorCoefficients
        @LoggedInUserEmail = @LoggedInUserEmail,
        @MabaID            = @MabaID,
        @RTP = @RTP, @A4 = @A4, @B4 = @B4, @A7 = @A7, @B7 = @B7, @C7 = @C7,
        @Apply             = @Apply;

    FETCH NEXT FROM sensor INTO @MabaID, @RTP, @A4, @B4, @A7, @B7, @C7;
END;
CLOSE sensor;
DEALLOCATE sensor;

SELECT o.Outcome, o.ConversionParameterId, o.MeasurementDevicesId, o.MabaID,
       o.RTP, o.A4, o.B4, o.A7, o.B7, o.C7, s.Certificate, s.UpdatedOn
FROM #Outcome AS o
JOIN @Sensors AS s ON s.MabaID = o.MabaID
ORDER BY o.MabaID;

SELECT Outcome, COUNT(*) AS Sensors FROM #Outcome GROUP BY Outcome;

DROP TABLE #Outcome;
