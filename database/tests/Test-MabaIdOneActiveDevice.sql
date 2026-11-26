/*
    Test-MabaIdOneActiveDevice                                                          MBA-1060
    ---------------------------------------------------------------------------------------------
    One active device row per MABA number, and a clear reason when something tries to break it.
    Writes inside a transaction and rolls everything back. If a procedure's own CATCH ends that
    transaction, the test stops there instead of writing outside it. Returns one row per check:
    PASS / FAIL / SKIP and what was seen.

      1. EditEquipmentRecord: changing a device to another active device's MABA number -> 51070,
         and the message names the number.
      2. CreateEquipmentRecord: a MABA number an active device has -> 51070.
      3. EditEquipmentRecord: re-saving a device with its own unchanged number -> no error.
      4. A plain INSERT of a taken number -> 2601 on UX_MeasurementDevices_MabaID_Active
         (SKIP when the index is not there yet).
      5. GetMeasurementDevicesCorrections: for a MabaID with a retired copy that has corrections,
         every row returned belongs to the active copy (SKIP when no such MabaID exists).
      6. No MABA number has two active rows.

    Ids are taken from the data, never hard-coded, so it runs on STAGE, PROD or a local copy.
*/
SET NOCOUNT ON;
SET XACT_ABORT OFF;

DECLARE @R TABLE (N INT, CheckName NVARCHAR(100), Result VARCHAR(4), Seen NVARCHAR(1000));

DECLARE @A INT, @AMaba NVARCHAR(50), @B INT;
SELECT TOP (1) @A = ID, @AMaba = MabaID FROM dbo.MeasurementDevices WHERE IsDeleted = 0 ORDER BY ID;
SELECT TOP (1) @B = ID FROM dbo.MeasurementDevices WHERE IsDeleted = 0 AND MabaID <> @AMaba ORDER BY ID;

BEGIN TRAN;

/* 1 */
BEGIN TRY
    EXEC dbo.EditEquipmentRecord @ID = @B, @MabaID = @AMaba;
    INSERT @R VALUES (1, N'edit to a taken number refused', 'FAIL', N'no error');
END TRY
BEGIN CATCH
    INSERT @R VALUES (1, N'edit to a taken number refused',
        IIF(ERROR_NUMBER() = 51070 AND ERROR_MESSAGE() LIKE N'%' + @AMaba + N'%', 'PASS', 'FAIL'),
        CONCAT(ERROR_NUMBER(), N': ', ERROR_MESSAGE()));
END CATCH
IF XACT_STATE() = -1 BEGIN ROLLBACK; BEGIN TRAN; END

/* 2 */
IF @@TRANCOUNT = 0
BEGIN
    /* a procedure's own CATCH ran a bare ROLLBACK: nothing below may run outside a transaction */
    INSERT @R VALUES (2, N'transaction still open', 'FAIL', N'the test transaction was rolled back by a procedure; stopped here');
    GOTO Report;
END
BEGIN TRY
    EXEC dbo.CreateEquipmentRecord @MabaID = @AMaba, @EquipmentName = N'MBA-1060 test';
    INSERT @R VALUES (2, N'create with a taken number refused', 'FAIL', N'no error');
END TRY
BEGIN CATCH
    INSERT @R VALUES (2, N'create with a taken number refused',
        IIF(ERROR_NUMBER() = 51070, 'PASS', 'FAIL'), CONCAT(ERROR_NUMBER(), N': ', ERROR_MESSAGE()));
END CATCH
IF XACT_STATE() = -1 BEGIN ROLLBACK; BEGIN TRAN; END

/* 3 */
IF @@TRANCOUNT = 0
BEGIN
    /* a procedure's own CATCH ran a bare ROLLBACK: nothing below may run outside a transaction */
    INSERT @R VALUES (3, N'transaction still open', 'FAIL', N'the test transaction was rolled back by a procedure; stopped here');
    GOTO Report;
END
BEGIN TRY
    EXEC dbo.EditEquipmentRecord @ID = @A, @MabaID = @AMaba;
    INSERT @R VALUES (3, N'edit keeping its own number allowed', 'PASS', N'no error');
END TRY
BEGIN CATCH
    INSERT @R VALUES (3, N'edit keeping its own number allowed', 'FAIL', CONCAT(ERROR_NUMBER(), N': ', ERROR_MESSAGE()));
END CATCH
IF XACT_STATE() = -1 BEGIN ROLLBACK; BEGIN TRAN; END

/* 4 */
IF @@TRANCOUNT = 0
BEGIN
    /* a procedure's own CATCH ran a bare ROLLBACK: nothing below may run outside a transaction */
    INSERT @R VALUES (4, N'transaction still open', 'FAIL', N'the test transaction was rolled back by a procedure; stopped here');
    GOTO Report;
END
IF EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.MeasurementDevices') AND name = N'UX_MeasurementDevices_MabaID_Active')
BEGIN
    BEGIN TRY
        INSERT dbo.MeasurementDevices (MabaID) VALUES (@AMaba);
        INSERT @R VALUES (4, N'raw insert of a taken number blocked', 'FAIL', N'inserted');
    END TRY
    BEGIN CATCH
        INSERT @R VALUES (4, N'raw insert of a taken number blocked',
            IIF(ERROR_NUMBER() = 2601 AND ERROR_MESSAGE() LIKE N'%UX_MeasurementDevices_MabaID_Active%', 'PASS', 'FAIL'),
            CONCAT(ERROR_NUMBER(), N': ', ERROR_MESSAGE()));
    END CATCH
END
ELSE
    INSERT @R VALUES (4, N'raw insert of a taken number blocked', 'SKIP', N'index not created yet');

Report:
IF @@TRANCOUNT > 0 ROLLBACK;

/* 5 */
DECLARE @CMaba NVARCHAR(50) =
(
    SELECT TOP (1) d.MabaID
    FROM dbo.MeasurementDevices AS d
    WHERE d.IsDeleted = 1
      AND EXISTS (SELECT 1 FROM dbo.MeasurementDevicesCorrections c WHERE c.MeasurementDevicesId = d.ID AND c.IsDeleted = 0)
      AND EXISTS (SELECT 1 FROM dbo.MeasurementDevices a WHERE a.MabaID = d.MabaID AND a.IsDeleted = 0)
    ORDER BY d.ID
);
IF @CMaba IS NULL
    INSERT @R VALUES (5, N'certificate load ignores retired copies', 'SKIP', N'no MabaID with a retired copy that has corrections');
ELSE
BEGIN
    DECLARE @Cor TABLE (ID INT, Value1 DECIMAL(38,15), Value2 DECIMAL(38,15), Deviation DECIMAL(38,15), Note NVARCHAR(MAX),
                        MeasurementDevicesId INT, MeasurementId INT, UnitID INT, CreatedDate DATETIME2, CorVersion INT,
                        DepartmentId INT, Equation NVARCHAR(MAX));
    INSERT @Cor EXEC dbo.GetMeasurementDevicesCorrections @MabaID = @CMaba, @GetLatestVersionOnly = 1;
    INSERT @R
    SELECT 5, N'certificate load ignores retired copies',
           IIF(COUNT(*) > 0 AND SUM(IIF(md.IsDeleted = 1, 1, 0)) = 0, 'PASS', 'FAIL'),
           CONCAT(@CMaba, N': ', COUNT(*), N' rows, from device(s) ', STRING_AGG(CAST(c.MeasurementDevicesId AS NVARCHAR(MAX)), N','),
                  N', retired rows returned: ', SUM(IIF(md.IsDeleted = 1, 1, 0)))
    FROM @Cor AS c JOIN dbo.MeasurementDevices AS md ON md.ID = c.MeasurementDevicesId;
END

/* 6 */
INSERT @R
SELECT 6, N'no MABA number has two active rows', IIF(COUNT(*) = 0, 'PASS', 'FAIL'),
       CONCAT(COUNT(*), N' duplicated: ', STRING_AGG(MabaID, N', '))
FROM (SELECT MabaID FROM dbo.MeasurementDevices WHERE IsDeleted = 0 GROUP BY MabaID HAVING COUNT(*) > 1) AS d;

SELECT N, CheckName, Result, Seen FROM @R ORDER BY N;
