/*
    Tranche D - PROD data loads                                          MBA-902, MBA-811, MBA-922
    =============================================================================================
    The only tranche that loads DATA. A, C, B and H deployed code; this one puts rows in front of
    calibrators, so it is deliberately separate and deliberately last.

    Four steps, in this order:

      1  stg.LoadCustomerContactsFromPriority   MBA-922  the Priority phonebook into staging
      2  stg.MergeCustomersContactsData                  staging into dbo.CustomerContacts
      3  dbo.ImportMissingDevicesFromKyulan     MBA-902  1,421 instruments that exist only in kyulan
      4  the kyulan certificate load            MBA-811  their calibration certificates

    STEP 4 AFTER STEP 3 IS NOT OPTIONAL. PROD holds 19,000 orphaned correction rows, but
    reattaching them without step 3 recovers SEVEN devices: 18,865 of those rows belong to 1,217
    MabaIDs PROD does not hold. The certificates have nowhere to attach until the devices exist.

    Step 1 loads a staging table and nothing else - it does NOT touch dbo.CustomerContacts. The
    first run of this tranche omitted step 2, so 60,370 contacts sat in staging while the live
    table stayed at 2,571 and the run looked like it had done nothing.

    PROD baselines, 31/08:

        before step 3    devices  2,070      after  3,491
        before step 4    masters with a certificate  200,  orphaned correction rows  19,000
        before step 2    customer contacts  2,571

    All four are safe to re-run. None writes anything back to Priority or kyulan. Nothing is
    dropped and no existing row is rewritten, except that step 4 repairs orphaned correction rows
    by filling in the device id they should always have had.

    Expect a few minutes: every step reads across the linked server to Priority (31.168.173.93).
*/

SET NOCOUNT ON;

/* ---- 1. MBA-922 - the Priority phonebook into staging --------------------------------------- */
EXEC stg.LoadCustomerContactsFromPriority @ReportOnly = 0;
GO

/* ---- 2. staging into the live table ---------------------------------------------------------- */
EXEC stg.MergeCustomersContactsData;
GO

/* ---- 3. MBA-902 - the instruments that exist only in kyulan ---------------------------------- */
/*  @Apply = 0 reports and writes nothing; the dry run against PROD on 31/08 said 1,421 would be
    created, 848 of them still within calibration date, 1,216 sensors, 102 data loggers, and 0
    whose work-range unit could not be mapped. Applied 31/08: 2,070 -> 3,491 devices, exactly
    +1,421. Re-running inserts nothing.  */
EXEC dbo.ImportMissingDevicesFromKyulan @Apply = 1;
GO

/* ---- 4. MBA-811 - their certificates --------------------------------------------------------- */
SET NOCOUNT ON;
SET XACT_ABORT ON;

DELETE FROM stg.stg_MeasurementDevicesCorrections;

DROP TABLE IF EXISTS #UnitMap;
CREATE TABLE #UnitMap (KUnitID INT PRIMARY KEY, ShortNameEn NVARCHAR(20));
INSERT #UnitMap VALUES
 (14,N'°C'), (37,N'%RH'), (53,N'Ω'), (19,N'°Ré'),
 (50,N'mV'), (17,N'°F'), (60,N'°C D.P'), (39,N'kPa a');

DROP TABLE IF EXISTS #K;
SELECT * INTO #K FROM OPENQUERY([31.168.173.93], '
  SELECT SourceId   = c.ID,
         RangeStart = c.RangeStart,
         RangeStop  = c.RangeStop,
         Equation   = c.Value,
         DateAdded  = c.DateAdded,
         CorVersion = c.CorVersion,
         KUnitID    = c.UnitID,
         MabaID     = i.MabaID
  FROM kyulan.dbo.tblInstrCorrections c
  JOIN kyulan.dbo.tblInstr i ON i.ID = c.InstrumentId
');

INSERT INTO stg.stg_MeasurementDevicesCorrections
      (RangeStart, RangeStop, Value, DateAdded, CorVersion, MabaID,
       MeasurementNameEn, MeasurementNameHe, ShortNameEn, LongNameEn, ShortNameHe, LongNameHe,
       DepartmentHeb, MeasurementDevicesCorrectionsSourceId, Deviation)
SELECT k.RangeStart,
       k.RangeStop,
       k.Equation,
       k.DateAdded,
       k.CorVersion,
       LTRIM(RTRIM(k.MabaID)),
       N'Temperature', N'טמפרטורה',
       um.ShortNameEn, um.ShortNameEn, um.ShortNameEn, um.ShortNameEn,
       N'טמפרטורה',
       k.SourceId,
       /* evaluate "x * (a) <sign> b" at RangeStart; anything unparseable stays NULL */
       TRY_CAST(
         TRY_CAST(SUBSTRING(k.Equation, CHARINDEX('(',k.Equation)+1,
                            NULLIF(CHARINDEX(')',k.Equation),0)-CHARINDEX('(',k.Equation)-1) AS FLOAT)
         * k.RangeStart
         + COALESCE(TRY_CAST(REPLACE(LTRIM(RTRIM(
             SUBSTRING(k.Equation, NULLIF(CHARINDEX(')',k.Equation),0)+1, 100))),' ','') AS FLOAT), 0)
       AS DECIMAL(25,15))
FROM #K AS k
JOIN #UnitMap AS um ON um.KUnitID = k.KUnitID
WHERE NULLIF(LTRIM(RTRIM(k.MabaID)), N'') IS NOT NULL
  AND k.DateAdded IS NOT NULL          /* CreatedDate is NOT NULL on the target */
  /* COLLATE DATABASE_DEFAULT because #K comes from OPENQUERY and carries the Priority server's
     collation (Hebrew_CI_AS), not ours (Latin1_General_100_CI_AI_SC). Comparing them raw fails
     with "cannot resolve the collation conflict" - it did on CalibratorProd, 31/08. It happens
     to work on STAGE, which is exactly why this had to be found in production. */
  AND EXISTS (SELECT 1 FROM dbo.MeasurementDevices d
              WHERE LTRIM(RTRIM(d.MabaID)) COLLATE DATABASE_DEFAULT
                  = LTRIM(RTRIM(k.MabaID)) COLLATE DATABASE_DEFAULT);  /* no new orphans */


/* ---- the existing merge, unchanged ---------------------------------------------------------- */
EXEC stg.MergeMeasurementDevicesCorrection;

/* ---- reattach the orphans the merge cannot fix itself --------------------------------------- */
UPDATE mdc
SET mdc.MeasurementDevicesId = d.ID,
    mdc.UpdatedDate = GETDATE()
FROM dbo.MeasurementDevicesCorrections AS mdc
JOIN stg.stg_MeasurementDevicesCorrections AS s
      ON s.MeasurementDevicesCorrectionsSourceId = mdc.MeasurementDevicesCorrectionsSourceId
JOIN dbo.MeasurementDevices AS d
      ON LTRIM(RTRIM(d.MabaID)) = LTRIM(RTRIM(s.MabaID))
WHERE mdc.MeasurementDevicesId IS NULL
  AND ISNULL(mdc.IsDeleted,0) = 0;

/* ---- what it achieved ----------------------------------------------------------------------- */
SELECT DevicesWithCertificate = COUNT(DISTINCT c.MeasurementDevicesId),
       Rows                   = COUNT(*),
       RemainingOrphans       = SUM(IIF(c.MeasurementDevicesId IS NULL,1,0))
FROM dbo.MeasurementDevicesCorrections AS c
WHERE ISNULL(c.IsDeleted,0) = 0;
