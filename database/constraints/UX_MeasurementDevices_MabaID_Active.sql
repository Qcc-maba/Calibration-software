/*
    UX_MeasurementDevices_MabaID_Active                                                  MBA-1060
    ---------------------------------------------------------------------------------------------
    One ACTIVE device row per MABA number. Soft-deleted rows (IsDeleted = 1) may share it.

    Nothing enforced this before. CalibratorDB/ListOfAllEquipment.sql loaded the same 36 loggers
    three times into PROD (76 extra rows), and the equipment edit screen re-keyed rows onto a
    number in use (PROD 21-675, STAGE 10-30 / 21-500 / 21-540 / 21-675). With this index any
    writer that would create a second active row fails, and says which number:
        Cannot insert duplicate key row in object 'dbo.MeasurementDevices' with unique index
        'UX_MeasurementDevices_MabaID_Active'. The duplicate key value is (21-142).
    The equipment screens never get that far: dbo.CreateEquipmentRecord / dbo.EditEquipmentRecord
    refuse first with error 51070 and a sentence the app shows as "MABA number already in use".

    Run AFTER database/data/Retire-DuplicateMeasurementDevices.sql has been applied. If any MABA
    number still has more than one active row, this stops before creating anything and lists them.

    A filtered index makes SQL Server require QUOTED_IDENTIFIER and ANSI_NULLS ON in every module
    that writes the table (error 1934 otherwise). Measured 2026-11-26: on STAGE every module is ON.
    On PROD dbo.ImportInstrumentWorkRangeFromKyulan (the hand-run MBA-902 import, which UPDATEs
    this table) was created with QUOTED_IDENTIFIER OFF. Re-create it with it ON before running it
    on PROD again. dbo.RemoveCarAssignment is OFF too but does not write this table. The app's and
    the station's connections already write tables with filtered indexes (CalibrationReportFile,
    OrderNote), so their session settings are fine.

    Replayable: does nothing when the index exists.
*/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes
               WHERE object_id = OBJECT_ID(N'dbo.MeasurementDevices') AND name = N'UX_MeasurementDevices_MabaID_Active')
BEGIN
    DECLARE @Dups NVARCHAR(MAX) =
    (
        SELECT STRING_AGG(CONCAT(d.MabaID, N' (', d.n, N' rows)'), N', ')
        FROM (SELECT MabaID, COUNT(*) AS n FROM dbo.MeasurementDevices
              WHERE IsDeleted = 0 GROUP BY MabaID HAVING COUNT(*) > 1) AS d
    );

    IF @Dups IS NOT NULL
    BEGIN
        DECLARE @Msg NVARCHAR(2048) = LEFT(CONCAT(
            N'Not created: these MABA numbers still have more than one active device row: ', @Dups,
            N'. Apply database/data/Retire-DuplicateMeasurementDevices.sql first.'), 2048);
        THROW 51071, @Msg, 1;
    END

    CREATE UNIQUE NONCLUSTERED INDEX UX_MeasurementDevices_MabaID_Active
        ON dbo.MeasurementDevices (MabaID)
        WHERE IsDeleted = 0;
END
GO
