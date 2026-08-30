/*
    Tests for dbo.fnMasterValueAfterCorrection                                         MBA-811
    ---------------------------------------------------------------------------------------------
    Run against STAGE. Every expected value is computed here from the same certificate rows the
    function reads, so a change in behaviour surfaces as a failure rather than as a new number
    nobody notices.

    The out-of-range cases are the point of this file. Nofar's rule (MBA-811, 23/08) is to clamp to
    the nearest deviation, and a clamp is SILENT: the calibrator sees a value to six decimals with
    nothing saying it came from outside the certificate. 31-77's certificate stops at 349.98 and a
    reading of 1001 still returns a number. These tests pin that down so it cannot drift, and they
    are where an InRange / Clamped flag gets verified once it exists.

    Anything other than 'PASS' in Result is a failure.
*/
SET NOCOUNT ON;

DECLARE @Dev INT = (SELECT ID FROM dbo.MeasurementDevices WHERE MabaID = N'31-90');
IF @Dev IS NULL BEGIN SELECT Result = N'SKIP - master 31-90 is not present'; RETURN; END

DECLARE @V INT = (SELECT MAX(CorVersion) FROM dbo.MeasurementDevicesCorrections
                  WHERE MeasurementDevicesId = @Dev AND ISNULL(IsDeleted,0) = 0);

DECLARE @LoT DECIMAL(18,6), @LoD DECIMAL(18,6), @HiT DECIMAL(18,6), @HiD DECIMAL(18,6);
SELECT TOP (1) @LoT = Value1, @LoD = Deviation FROM dbo.MeasurementDevicesCorrections
 WHERE MeasurementDevicesId=@Dev AND CorVersion=@V AND ISNULL(IsDeleted,0)=0 ORDER BY Value1 ASC;
SELECT TOP (1) @HiT = Value1, @HiD = Deviation FROM dbo.MeasurementDevicesCorrections
 WHERE MeasurementDevicesId=@Dev AND CorVersion=@V AND ISNULL(IsDeleted,0)=0 ORDER BY Value1 DESC;

DECLARE @Cases TABLE (Seq INT IDENTITY, Name NVARCHAR(60), Reading DECIMAL(18,6), Expected DECIMAL(18,6));

/* the edges, and past them - the clamp */
INSERT @Cases (Name, Reading, Expected) VALUES
    (N'far below the certificate',   @LoT - 1000,  @LoT - 1000  - @LoD),
    (N'just below the first point',  @LoT - 0.001, @LoT - 0.001 - @LoD),
    (N'exactly on the first point',  @LoT,         @LoT         - @LoD),
    (N'exactly on the last point',   @HiT,         @HiT         - @HiD),
    (N'just above the last point',   @HiT + 0.001, @HiT + 0.001 - @HiD),
    (N'far above the certificate',   @HiT + 5000,  @HiT + 5000  - @HiD);

/* inside the range - interpolation, worked out independently */
DECLARE @Mid DECIMAL(18,6) = 25.0;
DECLARE @t1 DECIMAL(18,6), @d1 DECIMAL(18,6), @t2 DECIMAL(18,6), @d2 DECIMAL(18,6);
SELECT TOP (1) @t1=Value1, @d1=Deviation FROM dbo.MeasurementDevicesCorrections
 WHERE MeasurementDevicesId=@Dev AND CorVersion=@V AND ISNULL(IsDeleted,0)=0 AND Value1 <= @Mid ORDER BY Value1 DESC;
SELECT TOP (1) @t2=Value1, @d2=Deviation FROM dbo.MeasurementDevicesCorrections
 WHERE MeasurementDevicesId=@Dev AND CorVersion=@V AND ISNULL(IsDeleted,0)=0 AND Value1 >  @Mid ORDER BY Value1 ASC;
INSERT @Cases (Name, Reading, Expected)
VALUES (N'interpolated between two points', @Mid, @Mid - (@d1 + ((@d2-@d1)/(@t2-@t1)) * (@Mid-@t1)));

SELECT Test     = c.Name,
       Reading  = c.Reading,
       Expected = c.Expected,
       Actual   = f.Corrected,
       Result   = CASE WHEN f.Corrected IS NULL THEN N'FAIL - no value returned'
                       /* 1e-5: the function and this test divide in slightly different orders,
                          which lands the last digit up to 5e-6 apart. Far below anything a
                          calibration reading resolves to, and not worth chasing. */
                       WHEN ABS(f.Corrected - c.Expected) <= 0.00001 THEN N'PASS'
                       ELSE N'FAIL' END
FROM @Cases AS c
CROSS APPLY dbo.fnMasterValueAfterCorrection(@Dev, c.Reading, NULL) AS f
ORDER BY c.Seq;

/* the cases that must return nothing rather than a plausible number */
SELECT Test = N'a master with no certificate returns NULL',
       Result = CASE WHEN (SELECT Corrected FROM dbo.fnMasterValueAfterCorrection(x.ID, 25.0, NULL)) IS NULL
                     THEN N'PASS' ELSE N'FAIL' END
FROM (SELECT TOP (1) d.ID FROM dbo.MeasurementDevices d
      WHERE NOT EXISTS (SELECT 1 FROM dbo.MeasurementDevicesCorrections c
                        WHERE c.MeasurementDevicesId = d.ID AND ISNULL(c.IsDeleted,0)=0)) AS x;

SELECT Test = N'a NULL reading returns NULL',
       Result = CASE WHEN (SELECT Corrected FROM dbo.fnMasterValueAfterCorrection(@Dev, NULL, NULL)) IS NULL
                     THEN N'PASS' ELSE N'FAIL' END;

SELECT Test = N'only the newest certificate is used',
       Versions = (SELECT COUNT(DISTINCT CorVersion) FROM dbo.MeasurementDevicesCorrections
                   WHERE MeasurementDevicesId = @Dev AND ISNULL(IsDeleted,0)=0),
       Result = CASE WHEN (SELECT Deviation FROM dbo.fnMasterValueAfterCorrection(@Dev, @LoT, NULL)) = @LoD
                     THEN N'PASS' ELSE N'FAIL' END;

SELECT Test = N'every master with a certificate answers',
       Masters = COUNT(*),
       Answered = SUM(CASE WHEN f.Corrected IS NOT NULL THEN 1 ELSE 0 END),
       Result = CASE WHEN COUNT(*) = SUM(CASE WHEN f.Corrected IS NOT NULL THEN 1 ELSE 0 END)
                     THEN N'PASS' ELSE N'FAIL' END
FROM dbo.MeasurementDevices AS d
CROSS APPLY (SELECT n = COUNT(*) FROM dbo.MeasurementDevicesCorrections c
             WHERE c.MeasurementDevicesId = d.ID AND ISNULL(c.IsDeleted,0)=0) AS x
CROSS APPLY dbo.fnMasterValueAfterCorrection(d.ID, 25.0, NULL) AS f
WHERE x.n > 0;

/* the column width that caused all of this - one row per table that has the column */
SELECT Test = N'no MasterValue column is narrower than 12 digits',
       TableName = tb.name,
       Typ = CONCAT(t.name,'(',c.precision,',',c.scale,')'),
       Result = CASE WHEN c.precision - c.scale >= 12 THEN N'PASS' ELSE N'FAIL - too narrow' END
FROM sys.columns c
JOIN sys.tables tb ON tb.object_id = c.object_id
JOIN sys.types  t  ON t.user_type_id = c.user_type_id
WHERE c.name = 'MasterValue';
