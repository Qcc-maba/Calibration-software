/*
    Loading master calibration certificates from kyulan                                  MBA-811
    ---------------------------------------------------------------------------------------------
    Deviation compensation showed a dash for almost every master, and it looked like a data-entry
    backlog: 189 of 3,453 devices carried a certificate. That was wrong. The certificates are in
    the legacy system - kyulan.dbo.tblInstrCorrections, 44,503 rows over 2,238 instruments - and
    kyulan is reachable from here over the existing Priority linked server (31.168.173.93).

    Two faults kept them out of reach.

    1. stg.stg_MeasurementDevicesCorrections was EMPTY, so stg.MergeMeasurementDevicesCorrection
       had nothing to merge. Whatever normally fills that staging table had not run.

    2. Worse: 18,994 of the 29,553 rows already in MeasurementDevicesCorrections carried a NULL
       MeasurementDevicesId - 64% of the table, orphaned and unreadable, the oldest from 2007.

       The merge causes this. Its INSERT does

           LEFT JOIN dbo.MeasurementDevices md ON md.MabaID = stg.MabaID

       so a staging row whose MabaID does not match still inserts, with a NULL device id. The
       UPDATE that closes the procedure cannot repair them either, because it joins on the very
       column it is trying to set:

           JOIN dbo.MeasurementDevices md ON md.ID = mdc.MeasurementDevicesId

       And re-running the merge never helped: it skips any row whose
       MeasurementDevicesCorrectionsSourceId already exists, and the orphans had taken those ids.
       The data was present the whole time, attached to nothing.

    Result: devices with a certificate 189 -> 1,421 of 3,453; MeasurementId populated on 1,437;
    orphans 18,994 -> 0. 31-90 now carries its 12 temperature ranges and reads identically to
    kyulan and the legacy screen.

    THE UNIT MAPPING is not taken from kyulan's own lookups - tblMeasurementUnits.Unit points at
    tblUnitGroups, which holds physical quantities (Area, Torque), not unit symbols. It is LEARNED
    from the rows that had already synced correctly: kyulan UnitID against our Measurements.NameEn
    over 29,553 live rows. 31-90 carries UnitID 14 -> degrees C.

    DEVIATION is not stored in kyulan. It is the range equation evaluated at RangeStart, verified
    against 21-260 version 33: -79.810 * -0.021542 + 0.070767 = 1.790034, exactly what is stored.

    DROPPED rather than forced:
      13,914  MabaID we do not hold - forcing these recreates the orphans this script exists to fix
         210  no DateAdded, against a NOT NULL CreatedDate
         634  equations that are not "x * (a) +/- b" - bare constants, and some carrying an int
              overflow sentinel. These still load; only the computed Deviation is NULL, and the
              Equation text is preserved verbatim.

    Safe to re-run: the load is keyed on source id, the merge skips what it holds, and the repair
    only touches rows whose device id is NULL.

    THIS IS A STOPGAP. The merge should stop inserting NULL device ids at all, and whatever owns
    the staging load needs to run on a schedule.
*/

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
  AND EXISTS (SELECT 1 FROM dbo.MeasurementDevices d
              WHERE LTRIM(RTRIM(d.MabaID)) = LTRIM(RTRIM(k.MabaID)));  /* no new orphans */


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
