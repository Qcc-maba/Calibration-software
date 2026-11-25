/*
    Tests for dbo.SaveMasterHumidityCorrectionPoints and dbo.GetMasterHumidityCorrectionPoints
                                                                                         MBA-950
    ---------------------------------------------------------------------------------------------
    Writes and rolls back. Anything other than PASS is a failure.

    Judged by the reader, as the temperature save is (Test-SaveMasterSensorCorrectionsBatch.sql):
    after a save, dbo.fnHumidityAfterCorrection must remove the deviation the calibrator entered.
    Points at 23 °C: reference 10 read 10.4, reference 50 read 50.0, reference 90 read 89.2,
    so deviations +0.4 / 0.0 / -0.8 and, read at a reference, the corrected value is that reference
    plus or minus the slope x deviation approximation (MBA-816) - exact at 50, where it is flat.

      1  the dry run writes nothing and says WouldSave
      2  @Apply = 1 saves version 1, Deviation = Reading - Reference
      3  the same points again: NoChange, no new version
      4  different points: version 2, and the function reads version 2 only
      5  the master's temperature certificate is untouched
      6  refused: a duplicate point, a humidity over 100, an unknown MabaID, no points
      7  dbo.GetMasterHumidityCorrectionPoints returns the newest version
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @Out TABLE (Seq INT IDENTITY, Test NVARCHAR(90), Expected NVARCHAR(60), Actual NVARCHAR(60), Result NVARCHAR(10));
DECLARE @Email NVARCHAR(255) = (SELECT TOP (1) Email FROM dbo.Users WHERE Email IS NOT NULL ORDER BY ID);

/* a live master that holds a temperature certificate, has no humidity points, and a unique MabaID */
DECLARE @D INT, @Maba NVARCHAR(50);
SELECT TOP (1) @D = md.ID, @Maba = LTRIM(RTRIM(md.MabaID))
FROM dbo.MeasurementDevices AS md
WHERE md.IsDeleted = 0
  AND NULLIF(LTRIM(RTRIM(md.MabaID)), N'') IS NOT NULL
  AND EXISTS (SELECT 1 FROM dbo.MeasurementDevicesCorrections AS c WHERE c.MeasurementDevicesId = md.ID AND c.IsDeleted = 0)
  AND NOT EXISTS (SELECT 1 FROM dbo.MeasurementDevicesHumidityCorrections AS h WHERE h.MeasurementDevicesId = md.ID)
  AND (SELECT COUNT(*) FROM dbo.MeasurementDevices AS o
       WHERE LTRIM(RTRIM(o.MabaID)) = LTRIM(RTRIM(md.MabaID)) AND o.IsDeleted = 0) = 1
ORDER BY md.ID;

DECLARE @V1 NVARCHAR(MAX) = N'[{"Temperature":23,"Reference":50,"Reading":50.0},
                               {"Temperature":23,"Reference":10,"Reading":10.4},
                               {"Temperature":23,"Reference":90,"Reading":89.2}]';
DECLARE @V2 NVARCHAR(MAX) = N'[{"Temperature":23,"Reference":50,"Reading":50.3}]';

CREATE TABLE #R (Outcome NVARCHAR(10), CorVersion INT, Temperature DECIMAL(18,6), ReferenceHumidity DECIMAL(18,6),
                 ReadingHumidity DECIMAL(18,6), Deviation DECIMAL(18,6));
CREATE TABLE #G (MeasurementDevicesId INT, MabaID NVARCHAR(50), NewestVersion INT, HasLegacyHumidityCurve BIT,
                 CorVersion INT, IsNewest BIT, Temperature DECIMAL(18,6), ReferenceHumidity DECIMAL(18,6),
                 ReadingHumidity DECIMAL(18,6), Deviation DECIMAL(18,6), Note NVARCHAR(500), CreatedDate DATETIME2(3),
                 UpdatedBy NVARCHAR(255));

DECLARE @Snap TABLE (Step INT, Outcomes NVARCHAR(100), Versions NVARCHAR(100), Devs NVARCHAR(200), Stored INT,
                     Corrected DECIMAL(18,6), TempRows INT, Err NVARCHAR(400));
DECLARE @TempRowsBefore INT = (SELECT COUNT(*) FROM dbo.MeasurementDevicesCorrections WHERE MeasurementDevicesId = @D);
DECLARE @Err NVARCHAR(400);

BEGIN TRAN;

/* 1 dry run */
INSERT #R EXEC dbo.SaveMasterHumidityCorrectionPoints @LoggedInUserEmail = @Email, @MabaID = @Maba, @Data = @V1;
INSERT @Snap (Step, Outcomes, Stored)
SELECT 1, STRING_AGG(Outcome, N','), (SELECT COUNT(*) FROM dbo.MeasurementDevicesHumidityCorrections WHERE MeasurementDevicesId = @D) FROM #R;
DELETE #R;

/* 2 apply */
INSERT #R EXEC dbo.SaveMasterHumidityCorrectionPoints @LoggedInUserEmail = @Email, @MabaID = @Maba, @Data = @V1, @Apply = 1;
INSERT @Snap (Step, Outcomes, Versions, Devs, Stored, Corrected)
SELECT 2, STRING_AGG(Outcome, N','), STRING_AGG(CAST(CorVersion AS NVARCHAR(10)), N','),
       STRING_AGG(CAST(Deviation AS NVARCHAR(30)), N',') WITHIN GROUP (ORDER BY ReferenceHumidity),
       (SELECT COUNT(*) FROM dbo.MeasurementDevicesHumidityCorrections WHERE MeasurementDevicesId = @D),
       (SELECT CorrectedExact FROM dbo.fnHumidityAfterCorrection(@D, 23, 50))
FROM #R;
DELETE #R;

/* 3 again */
INSERT #R EXEC dbo.SaveMasterHumidityCorrectionPoints @LoggedInUserEmail = @Email, @MeasurementDevicesId = @D, @Data = @V1, @Apply = 1;
INSERT @Snap (Step, Outcomes, Versions, Stored)
SELECT 3, STRING_AGG(Outcome, N','), STRING_AGG(CAST(CorVersion AS NVARCHAR(10)), N','),
       (SELECT COUNT(*) FROM dbo.MeasurementDevicesHumidityCorrections WHERE MeasurementDevicesId = @D) FROM #R;
DELETE #R;

/* 4 changed */
INSERT #R EXEC dbo.SaveMasterHumidityCorrectionPoints @LoggedInUserEmail = @Email, @MeasurementDevicesId = @D, @Data = @V2, @Apply = 1;
INSERT @Snap (Step, Outcomes, Versions, Stored, Corrected, TempRows)
SELECT 4, STRING_AGG(Outcome, N','), STRING_AGG(CAST(CorVersion AS NVARCHAR(10)), N','),
       (SELECT COUNT(*) FROM dbo.MeasurementDevicesHumidityCorrections WHERE MeasurementDevicesId = @D),
       (SELECT CorrectedExact FROM dbo.fnHumidityAfterCorrection(@D, 23, 30)),
       (SELECT COUNT(*) FROM dbo.MeasurementDevicesCorrections WHERE MeasurementDevicesId = @D)
FROM #R;
DELETE #R;

/* 7 reader */
INSERT #G EXEC dbo.GetMasterHumidityCorrectionPoints @MabaID = @Maba;
INSERT @Snap (Step, Versions, Stored)
SELECT 7, STRING_AGG(CAST(CorVersion AS NVARCHAR(10)), N','), COUNT(*) FROM #G;

ROLLBACK;

/* 6 refusals - each in its own try, nothing is written by any of them */
BEGIN TRY
    EXEC dbo.SaveMasterHumidityCorrectionPoints @LoggedInUserEmail = @Email, @MeasurementDevicesId = @D, @Apply = 1,
         @Data = N'[{"Temperature":23,"Reference":50,"Reading":50.1},{"Temperature":23,"Reference":50,"Reading":50.2}]';
    SET @Err = N'(accepted)';
END TRY BEGIN CATCH SET @Err = ERROR_MESSAGE(); END CATCH;
INSERT @Out VALUES (N'6 refused: two points at one temperature and humidity', N'share a temperature', @Err,
                    IIF(@Err LIKE N'%share a temperature%', N'PASS', N'FAIL'));

BEGIN TRY
    EXEC dbo.SaveMasterHumidityCorrectionPoints @LoggedInUserEmail = @Email, @MeasurementDevicesId = @D, @Apply = 1,
         @Data = N'[{"Temperature":23,"Reference":101,"Reading":100}]';
    SET @Err = N'(accepted)';
END TRY BEGIN CATCH SET @Err = ERROR_MESSAGE(); END CATCH;
INSERT @Out VALUES (N'6 refused: a reference humidity over 100', N'between 0 and 100', @Err,
                    IIF(@Err LIKE N'%between 0 and 100%', N'PASS', N'FAIL'));

BEGIN TRY
    EXEC dbo.SaveMasterHumidityCorrectionPoints @LoggedInUserEmail = @Email, @MabaID = N'no-such-master-950', @Apply = 1, @Data = @V1;
    SET @Err = N'(accepted)';
END TRY BEGIN CATCH SET @Err = ERROR_MESSAGE(); END CATCH;
INSERT @Out VALUES (N'6 refused: an unknown MabaID', N'No live master', @Err,
                    IIF(@Err LIKE N'No live master%', N'PASS', N'FAIL'));

BEGIN TRY
    EXEC dbo.SaveMasterHumidityCorrectionPoints @LoggedInUserEmail = @Email, @MeasurementDevicesId = @D, @Apply = 1, @Data = N'[]';
    SET @Err = N'(accepted)';
END TRY BEGIN CATCH SET @Err = ERROR_MESSAGE(); END CATCH;
INSERT @Out VALUES (N'6 refused: no points', N'At least one point', @Err,
                    IIF(@Err LIKE N'At least one point%', N'PASS', N'FAIL'));

INSERT @Out SELECT N'1 dry run: WouldSave, nothing stored', N'WouldSave x3, 0 rows', CONCAT(Outcomes, N', ', Stored, N' rows'),
       IIF(Outcomes = N'WouldSave,WouldSave,WouldSave' AND Stored = 0, N'PASS', N'FAIL') FROM @Snap WHERE Step = 1;
INSERT @Out SELECT N'2 saved as version 1, deviation = reading - reference', N'v1 0.400000,0.000000,-0.800000', CONCAT(N'v', LEFT(Versions, 1), N' ', Devs),
       IIF(Versions = N'1,1,1' AND Devs = N'0.400000,0.000000,-0.800000' AND Stored = 3, N'PASS', N'FAIL') FROM @Snap WHERE Step = 2;
INSERT @Out SELECT N'2 the function removes it: 50.0 at 50 reads back 50', N'50.000000', CAST(Corrected AS NVARCHAR(60)),
       IIF(Corrected = 50, N'PASS', N'FAIL') FROM @Snap WHERE Step = 2;
INSERT @Out SELECT N'3 same points again: NoChange, still 3 rows', N'NoChange v1, 3 rows', CONCAT(LEFT(Outcomes, 8), N' v', LEFT(Versions, 1), N', ', Stored, N' rows'),
       IIF(Outcomes = N'NoChange,NoChange,NoChange' AND Versions = N'1,1,1' AND Stored = 3, N'PASS', N'FAIL') FROM @Snap WHERE Step = 3;
INSERT @Out SELECT N'4 changed points: version 2, read alone', N'Saved v2, 4 rows, 29.700000', CONCAT(Outcomes, N' v', Versions, N', ', Stored, N' rows, ', Corrected),
       IIF(Outcomes = N'Saved' AND Versions = N'2' AND Stored = 4 AND Corrected = 29.7, N'PASS', N'FAIL') FROM @Snap WHERE Step = 4;
INSERT @Out SELECT N'5 the temperature certificate is untouched', CAST(@TempRowsBefore AS NVARCHAR(10)), CAST(TempRows AS NVARCHAR(10)),
       IIF(TempRows = @TempRowsBefore, N'PASS', N'FAIL') FROM @Snap WHERE Step = 4;
INSERT @Out SELECT N'7 the reader returns the newest version', N'2 (1 row)', CONCAT(Versions, N' (', Stored, N' row)'),
       IIF(Versions = N'2' AND Stored = 1, N'PASS', N'FAIL') FROM @Snap WHERE Step = 7;
INSERT @Out SELECT N'rolled back', N'0', CAST(COUNT(*) AS NVARCHAR(10)), IIF(COUNT(*) = 0, N'PASS', N'FAIL')
FROM dbo.MeasurementDevicesHumidityCorrections WHERE MeasurementDevicesId = @D;

IF @D IS NULL
    INSERT @Out VALUES (N'fixture: a master with a temperature certificate', N'one', N'none', N'FAIL');

SELECT Seq, Test, Expected, Actual, Result FROM @Out ORDER BY Seq;
