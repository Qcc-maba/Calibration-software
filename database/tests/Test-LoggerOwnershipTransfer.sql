/*
    Tests for logger ownership: the last save takes the whole logger                    MBA-1056
        dbo.AssignMeasurmentDevicesToCalibrator, dbo.GetLogersConfiguredByCalibrator,
        dbo.GetLoggerOtherOwners, dbo.GetLoggersTakenFromCalibrator,
        dbo.DismissLoggerOwnershipTransfers, table dbo.LoggerOwnershipTransfer
    ---------------------------------------------------------------------------------------------
    Run against a database where all of the above are deployed. Anything other than 'PASS' in
    Result is a failure; 'SKIP' means the database holds no row that fits, and says which.

    Every case runs in its own transaction and is rolled back, so the file leaves the database as
    it found it. The procedures run with XACT_ABORT ON, so a THROW dooms the transaction: each case
    reads what it needs into variables, rolls back, and only then records its result.

    Fixtures are picked from the data, never hard-coded - identities differ between STAGE and PROD.
    No address is printed; the output names cases, not people.

        @A, @B   two active users with a unique e-mail
        @L       a live data logger with no relation, channel or transfer row ever, so it starts clean
        @S1,@S2  two live sensors

    The scenario is the one found on STAGE on 25.11.2026: A configured the logger, B saves one of
    its sensors, and the logger must move to B whole - and A must be told.
*/
SET NOCOUNT ON;
SET XACT_ABORT OFF;   /* the procedures set their own; the harness must survive their THROWs */

DECLARE @Out TABLE (Seq INT IDENTITY, Test NVARCHAR(120), Expected NVARCHAR(60), Actual NVARCHAR(60),
                    Result NVARCHAR(80));

DROP TABLE IF EXISTS #Configured;
CREATE TABLE #Configured (LoggerMeasurementDeviceId INT, FlowRate NVARCHAR(20), Interval INT,
                          CommunicationProtocol NVARCHAR(100), CommunicationDetails NVARCHAR(100),
                          MabaID NVARCHAR(100), Model NVARCHAR(200), Manufacturer NVARCHAR(200),
                          ConnectionPoints INT, CountAssignedLoggers INT);
DROP TABLE IF EXISTS #Others;
CREATE TABLE #Others (UserId INT, FullName NVARCHAR(200), OwnedSince DATETIME2);
DROP TABLE IF EXISTS #Taken;
CREATE TABLE #Taken (LoggerMeasurementDeviceId INT, MabaID NVARCHAR(100), TakenByUserId INT,
                     TakenByName NVARCHAR(200), TransferredDate DATETIME2);
DROP TABLE IF EXISTS #Dismissed;
CREATE TABLE #Dismissed (Dismissed INT);

/* ---------------------------------------------------------------------------------------------
   Fixtures
   --------------------------------------------------------------------------------------------- */
DECLARE @A NVARCHAR(50), @B NVARCHAR(50), @AId INT, @BId INT, @L INT, @S1 INT, @S2 INT;

DECLARE @Users TABLE (n INT IDENTITY, ID INT, Email NVARCHAR(50));
INSERT @Users (ID, Email)
SELECT TOP (2) u.ID, u.Email
FROM dbo.Users AS u
WHERE u.IsActive = 1 AND u.Email LIKE N'%_@_%' AND LEN(u.Email) <= 50
  AND NOT EXISTS (SELECT 1 FROM dbo.Users AS d WHERE d.Email = u.Email AND d.ID <> u.ID)
ORDER BY u.ID;
SELECT @AId = ID, @A = Email FROM @Users WHERE n = 1;
SELECT @BId = ID, @B = Email FROM @Users WHERE n = 2;

SELECT TOP (1) @L = md.ID
FROM dbo.MeasurementDevices AS md
JOIN dbo.MeasurementDevicesMainClasses AS mc ON md.MainClassId = mc.Id
WHERE mc.NameEnglish = 'Data logger' AND md.IsDeleted = 0
  /* no history of any kind, deleted rows included: the cases count rows on this logger */
  AND NOT EXISTS (SELECT 1 FROM dbo.SensorToLoggerRelation AS r
                  WHERE r.LoggerMeasurementDeviceId = md.ID)
  AND NOT EXISTS (SELECT 1 FROM dbo.ChannelsToSensorRelation AS c
                  WHERE c.LoggerMeasurementDeviceId = md.ID)
  AND NOT EXISTS (SELECT 1 FROM dbo.LoggerOwnershipTransfer AS t
                  WHERE t.LoggerMeasurementDeviceId = md.ID)
ORDER BY md.ID;

DECLARE @Sensors TABLE (n INT IDENTITY, ID INT);
INSERT @Sensors (ID)
SELECT TOP (2) md.ID
FROM dbo.MeasurementDevices AS md
JOIN dbo.MeasurementDevicesMainClasses AS mc ON md.MainClassId = mc.Id
WHERE mc.NameEnglish = 'Sensor' AND md.IsDeleted = 0
ORDER BY md.ID;
SELECT @S1 = ID FROM @Sensors WHERE n = 1;
SELECT @S2 = ID FROM @Sensors WHERE n = 2;

IF @A IS NULL OR @B IS NULL OR @L IS NULL OR @S1 IS NULL OR @S2 IS NULL
BEGIN
    INSERT @Out (Test, Expected, Actual, Result)
    VALUES (N'fixtures', N'2 users, 1 free logger, 2 sensors', N'missing',
            N'SKIP - ' + CONCAT(IIF(@B IS NULL, N'users ', N''), IIF(@L IS NULL, N'logger ', N''),
                                IIF(@S2 IS NULL, N'sensors', N'')));
    SELECT Test, Expected, Actual, Result FROM @Out ORDER BY Seq;
    RETURN;
END

/* ---------------------------------------------------------------------------------------------
   Case 1: A configures two sensors, B saves one of them. The whole logger moves to B.
   --------------------------------------------------------------------------------------------- */
DECLARE @Err1 NVARCHAR(4000), @OwnedByB INT, @OwnedByOther INT, @Transfers INT,
        @BSees INT, @ASees INT, @OthersForB INT, @OthersForA INT, @OtherNameIsB INT,
        @TakenFromA INT, @TakenByIsB INT, @TakenFromB INT,
        @Dismissed INT, @TakenAfterDismiss INT, @DismissAgain INT,
        @AFromBack INT, @ATakenAfterBack INT, @TakenFromBAfterBack INT, @TransfersTotal INT;

BEGIN TRY
    BEGIN TRAN;

    EXEC dbo.AssignMeasurmentDevicesToCalibrator @LoggedInUserEmail = @A, @LoggerMeasurementDeviceId = @L,
         @FlowRate = N'Slow', @Interval = 1, @CommunicationProtocol = N'COM', @CommunicationDetails = N'COM3',
         @SensorMeasurementDeviceId = @S1, @UnitId = NULL, @WorkRangeUnitId = NULL, @ChannelNumbers = N'0';
    EXEC dbo.AssignMeasurmentDevicesToCalibrator @LoggedInUserEmail = @A, @LoggerMeasurementDeviceId = @L,
         @FlowRate = N'Slow', @Interval = 1, @CommunicationProtocol = N'COM', @CommunicationDetails = N'COM3',
         @SensorMeasurementDeviceId = @S2, @UnitId = NULL, @WorkRangeUnitId = NULL, @ChannelNumbers = N'1';

    /* B takes it, saving only S1 */
    EXEC dbo.AssignMeasurmentDevicesToCalibrator @LoggedInUserEmail = @B, @LoggerMeasurementDeviceId = @L,
         @FlowRate = N'Slow', @Interval = 1, @CommunicationProtocol = N'COM', @CommunicationDetails = N'COM5',
         @SensorMeasurementDeviceId = @S1, @UnitId = NULL, @WorkRangeUnitId = NULL, @ChannelNumbers = N'0';

    SELECT @OwnedByB = SUM(IIF(UpdateUserID = @BId, 1, 0)),
           @OwnedByOther = SUM(IIF(UpdateUserID = @BId, 0, 1))
    FROM dbo.SensorToLoggerRelation WHERE LoggerMeasurementDeviceId = @L AND IsDeleted = 0;

    SELECT @Transfers = COUNT(*) FROM dbo.LoggerOwnershipTransfer
    WHERE LoggerMeasurementDeviceId = @L AND FromUserId = @AId AND ToUserId = @BId AND DismissedDate IS NULL;

    INSERT #Configured EXEC dbo.GetLogersConfiguredByCalibrator @LoggedInUserEmail = @B;
    SELECT @BSees = COUNT(*) FROM #Configured WHERE LoggerMeasurementDeviceId = @L;
    DELETE #Configured;
    INSERT #Configured EXEC dbo.GetLogersConfiguredByCalibrator @LoggedInUserEmail = @A;
    SELECT @ASees = COUNT(*) FROM #Configured WHERE LoggerMeasurementDeviceId = @L;

    INSERT #Others EXEC dbo.GetLoggerOtherOwners @LoggedInUserEmail = @B, @LoggerMeasurementDeviceId = @L;
    SELECT @OthersForB = COUNT(*) FROM #Others;
    DELETE #Others;
    INSERT #Others EXEC dbo.GetLoggerOtherOwners @LoggedInUserEmail = @A, @LoggerMeasurementDeviceId = @L;
    SELECT @OthersForA = COUNT(*), @OtherNameIsB = SUM(IIF(UserId = @BId, 1, 0)) FROM #Others;

    INSERT #Taken EXEC dbo.GetLoggersTakenFromCalibrator @LoggedInUserEmail = @A;
    SELECT @TakenFromA = COUNT(*), @TakenByIsB = SUM(IIF(TakenByUserId = @BId, 1, 0))
    FROM #Taken WHERE LoggerMeasurementDeviceId = @L;
    DELETE #Taken;
    INSERT #Taken EXEC dbo.GetLoggersTakenFromCalibrator @LoggedInUserEmail = @B;
    SELECT @TakenFromB = COUNT(*) FROM #Taken WHERE LoggerMeasurementDeviceId = @L;
    DELETE #Taken;

    /* A dismisses the note; a second dismissal changes nothing */
    INSERT #Dismissed EXEC dbo.DismissLoggerOwnershipTransfers @LoggedInUserEmail = @A, @LoggerMeasurementDeviceId = @L;
    SELECT @Dismissed = Dismissed FROM #Dismissed;
    DELETE #Dismissed;
    INSERT #Taken EXEC dbo.GetLoggersTakenFromCalibrator @LoggedInUserEmail = @A;
    SELECT @TakenAfterDismiss = COUNT(*) FROM #Taken WHERE LoggerMeasurementDeviceId = @L;
    DELETE #Taken;
    INSERT #Dismissed EXEC dbo.DismissLoggerOwnershipTransfers @LoggedInUserEmail = @A, @LoggerMeasurementDeviceId = @L;
    SELECT @DismissAgain = Dismissed FROM #Dismissed;

    /* A takes it back: B is told, and A's own open notes on it are closed */
    UPDATE dbo.LoggerOwnershipTransfer SET DismissedDate = NULL
    WHERE LoggerMeasurementDeviceId = @L AND FromUserId = @AId;   /* reopen, to prove the save closes it */
    EXEC dbo.AssignMeasurmentDevicesToCalibrator @LoggedInUserEmail = @A, @LoggerMeasurementDeviceId = @L,
         @FlowRate = N'Slow', @Interval = 1, @CommunicationProtocol = N'COM', @CommunicationDetails = N'COM3',
         @SensorMeasurementDeviceId = @S2, @UnitId = NULL, @WorkRangeUnitId = NULL, @ChannelNumbers = N'1';
    SELECT @AFromBack = COUNT(*) FROM dbo.LoggerOwnershipTransfer
    WHERE LoggerMeasurementDeviceId = @L AND FromUserId = @AId AND DismissedDate IS NULL;
    INSERT #Taken EXEC dbo.GetLoggersTakenFromCalibrator @LoggedInUserEmail = @A;
    SELECT @ATakenAfterBack = COUNT(*) FROM #Taken WHERE LoggerMeasurementDeviceId = @L;
    DELETE #Taken;
    INSERT #Taken EXEC dbo.GetLoggersTakenFromCalibrator @LoggedInUserEmail = @B;
    SELECT @TakenFromBAfterBack = COUNT(*) FROM #Taken WHERE LoggerMeasurementDeviceId = @L;
    SELECT @TransfersTotal = COUNT(*) FROM dbo.LoggerOwnershipTransfer WHERE LoggerMeasurementDeviceId = @L;

    ROLLBACK;
END TRY
BEGIN CATCH
    SET @Err1 = ERROR_MESSAGE();
    IF @@TRANCOUNT > 0 ROLLBACK;
END CATCH

IF @Err1 IS NOT NULL
    INSERT @Out (Test, Expected, Actual, Result) VALUES (N'1 scenario ran', N'no error', LEFT(@Err1, 60), N'FAIL');
ELSE
    INSERT @Out (Test, Expected, Actual, Result)
    VALUES (N'1a both live relations owned by B',            N'2 / 0', CONCAT(@OwnedByB, N' / ', @OwnedByOther),
            IIF(@OwnedByB = 2 AND @OwnedByOther = 0, N'PASS', N'FAIL')),
           (N'1b one open transfer A -> B',                  N'1', CONCAT(@Transfers, N''),      IIF(@Transfers = 1, N'PASS', N'FAIL')),
           (N'1c page 2: B sees the logger',                 N'1', CONCAT(@BSees, N''),          IIF(@BSees = 1, N'PASS', N'FAIL')),
           (N'1d page 2: A no longer sees it',               N'0', CONCAT(@ASees, N''),          IIF(@ASees = 0, N'PASS', N'FAIL')),
           (N'1e other owners, asked by B',                  N'0', CONCAT(@OthersForB, N''),     IIF(@OthersForB = 0, N'PASS', N'FAIL')),
           (N'1f other owners, asked by A, is B',            N'1 / 1', CONCAT(@OthersForA, N' / ', @OtherNameIsB),
            IIF(@OthersForA = 1 AND @OtherNameIsB = 1, N'PASS', N'FAIL')),
           (N'1g A is told it went to B',                    N'1 / 1', CONCAT(@TakenFromA, N' / ', @TakenByIsB),
            IIF(@TakenFromA = 1 AND @TakenByIsB = 1, N'PASS', N'FAIL')),
           (N'1h B is not told anything',                    N'0', CONCAT(@TakenFromB, N''),     IIF(@TakenFromB = 0, N'PASS', N'FAIL')),
           (N'1i dismiss closes it',                         N'1 / 0', CONCAT(@Dismissed, N' / ', @TakenAfterDismiss),
            IIF(@Dismissed = 1 AND @TakenAfterDismiss = 0, N'PASS', N'FAIL')),
           (N'1j dismiss again changes nothing',             N'0', CONCAT(@DismissAgain, N''),   IIF(@DismissAgain = 0, N'PASS', N'FAIL')),
           (N'1k A takes it back: A''s notes closed',        N'0 / 0', CONCAT(@AFromBack, N' / ', @ATakenAfterBack),
            IIF(@AFromBack = 0 AND @ATakenAfterBack = 0, N'PASS', N'FAIL')),
           (N'1l A takes it back: B is told',                N'1', CONCAT(@TakenFromBAfterBack, N''), IIF(@TakenFromBAfterBack = 1, N'PASS', N'FAIL')),
           (N'1m transfer rows written in all',              N'2', CONCAT(@TransfersTotal, N''), IIF(@TransfersTotal = 2, N'PASS', N'FAIL'));

/* ---------------------------------------------------------------------------------------------
   Case 2: re-saving your own logger writes no transfer.
   --------------------------------------------------------------------------------------------- */
DECLARE @Err2 NVARCHAR(4000), @SelfTransfers INT;
BEGIN TRY
    BEGIN TRAN;
    EXEC dbo.AssignMeasurmentDevicesToCalibrator @LoggedInUserEmail = @A, @LoggerMeasurementDeviceId = @L,
         @FlowRate = N'Slow', @Interval = 1, @CommunicationProtocol = N'COM', @CommunicationDetails = N'COM3',
         @SensorMeasurementDeviceId = @S1, @UnitId = NULL, @WorkRangeUnitId = NULL, @ChannelNumbers = N'0';
    EXEC dbo.AssignMeasurmentDevicesToCalibrator @LoggedInUserEmail = @A, @LoggerMeasurementDeviceId = @L,
         @FlowRate = N'Slow', @Interval = 1, @CommunicationProtocol = N'COM', @CommunicationDetails = N'COM3',
         @SensorMeasurementDeviceId = @S1, @UnitId = NULL, @WorkRangeUnitId = NULL, @ChannelNumbers = N'0';
    SELECT @SelfTransfers = COUNT(*) FROM dbo.LoggerOwnershipTransfer WHERE LoggerMeasurementDeviceId = @L;
    ROLLBACK;
END TRY
BEGIN CATCH
    SET @Err2 = ERROR_MESSAGE();
    IF @@TRANCOUNT > 0 ROLLBACK;
END CATCH
INSERT @Out (Test, Expected, Actual, Result)
VALUES (N'2 re-saving your own logger: no transfer', N'0', COALESCE(LEFT(@Err2, 60), CONCAT(@SelfTransfers, N'')),
        IIF(@Err2 IS NULL AND @SelfTransfers = 0, N'PASS', N'FAIL'));

/* ---------------------------------------------------------------------------------------------
   Case 3: an unrelated owner-less (pre-MBA-902) relation is taken without a transfer row.
   --------------------------------------------------------------------------------------------- */
DECLARE @Err3 NVARCHAR(4000), @NullTransfers INT, @NullOwnedByB INT;
BEGIN TRY
    BEGIN TRAN;
    INSERT dbo.SensorToLoggerRelation (SensorMeasurementDeviceId, LoggerMeasurementDeviceId, UpdateUserID)
    VALUES (@S2, @L, NULL);
    EXEC dbo.AssignMeasurmentDevicesToCalibrator @LoggedInUserEmail = @B, @LoggerMeasurementDeviceId = @L,
         @FlowRate = N'Slow', @Interval = 1, @CommunicationProtocol = N'COM', @CommunicationDetails = N'COM5',
         @SensorMeasurementDeviceId = @S1, @UnitId = NULL, @WorkRangeUnitId = NULL, @ChannelNumbers = N'0';
    SELECT @NullTransfers = COUNT(*) FROM dbo.LoggerOwnershipTransfer WHERE LoggerMeasurementDeviceId = @L;
    SELECT @NullOwnedByB = COUNT(*) FROM dbo.SensorToLoggerRelation
    WHERE LoggerMeasurementDeviceId = @L AND IsDeleted = 0 AND UpdateUserID = @BId;
    ROLLBACK;
END TRY
BEGIN CATCH
    SET @Err3 = ERROR_MESSAGE();
    IF @@TRANCOUNT > 0 ROLLBACK;
END CATCH
INSERT @Out (Test, Expected, Actual, Result)
VALUES (N'3 unowned relation taken, no transfer row', N'0 / 2',
        COALESCE(LEFT(@Err3, 60), CONCAT(@NullTransfers, N' / ', @NullOwnedByB)),
        IIF(@Err3 IS NULL AND @NullTransfers = 0 AND @NullOwnedByB = 2, N'PASS', N'FAIL'));

/* ---------------------------------------------------------------------------------------------
   Case 4: an e-mail that is nobody's is refused, and the refusal reaches the caller.
   --------------------------------------------------------------------------------------------- */
DECLARE @Err4 INT, @RowsAfter4 INT;
BEGIN TRY
    BEGIN TRAN;
    EXEC dbo.AssignMeasurmentDevicesToCalibrator @LoggedInUserEmail = N'nobody+mba1056@invalid.example',
         @LoggerMeasurementDeviceId = @L, @FlowRate = N'Slow', @Interval = 1, @CommunicationProtocol = N'COM',
         @CommunicationDetails = N'COM3', @SensorMeasurementDeviceId = @S1, @UnitId = NULL,
         @WorkRangeUnitId = NULL, @ChannelNumbers = N'0';
    IF @@TRANCOUNT > 0 ROLLBACK;
END TRY
BEGIN CATCH
    SET @Err4 = ERROR_NUMBER();
    IF @@TRANCOUNT > 0 ROLLBACK;
END CATCH
SELECT @RowsAfter4 = COUNT(*) FROM dbo.SensorToLoggerRelation WHERE LoggerMeasurementDeviceId = @L AND IsDeleted = 0;
INSERT @Out (Test, Expected, Actual, Result)
VALUES (N'4 unknown e-mail refused with 51002', N'51002 / 0', CONCAT(@Err4, N' / ', @RowsAfter4),
        IIF(@Err4 = 51002 AND @RowsAfter4 = 0, N'PASS', N'FAIL'));

/* ---------------------------------------------------------------------------------------------
   Case 6 (PR #72 review): an owner id with no Users row does not make the logger unsaveable.
   SKIP if the database refuses such a row in the first place.
   --------------------------------------------------------------------------------------------- */
DECLARE @Err6 NVARCHAR(4000), @Ghost INT = (SELECT MAX(ID) + 1000 FROM dbo.Users), @GhostInserted BIT = 0,
        @GhostTransfers INT, @GhostOwnedByB INT;
BEGIN TRY
    BEGIN TRAN;
    BEGIN TRY
        INSERT dbo.SensorToLoggerRelation (SensorMeasurementDeviceId, LoggerMeasurementDeviceId, UpdateUserID)
        VALUES (@S2, @L, @Ghost);
        SET @GhostInserted = 1;
    END TRY
    BEGIN CATCH
        SET @GhostInserted = 0;
    END CATCH
    IF @GhostInserted = 1
    BEGIN
        EXEC dbo.AssignMeasurmentDevicesToCalibrator @LoggedInUserEmail = @B, @LoggerMeasurementDeviceId = @L,
             @FlowRate = N'Slow', @Interval = 1, @CommunicationProtocol = N'COM', @CommunicationDetails = N'COM5',
             @SensorMeasurementDeviceId = @S1, @UnitId = NULL, @WorkRangeUnitId = NULL, @ChannelNumbers = N'0';
        SELECT @GhostTransfers = COUNT(*) FROM dbo.LoggerOwnershipTransfer WHERE LoggerMeasurementDeviceId = @L;
        SELECT @GhostOwnedByB = COUNT(*) FROM dbo.SensorToLoggerRelation
        WHERE LoggerMeasurementDeviceId = @L AND IsDeleted = 0 AND UpdateUserID = @BId;
    END
    IF @@TRANCOUNT > 0 ROLLBACK;
END TRY
BEGIN CATCH
    SET @Err6 = ERROR_MESSAGE();
    IF @@TRANCOUNT > 0 ROLLBACK;
END CATCH
INSERT @Out (Test, Expected, Actual, Result)
VALUES (N'6 owner with no Users row: save still works', N'0 / 2',
        COALESCE(LEFT(@Err6, 60), IIF(@GhostInserted = 1, CONCAT(@GhostTransfers, N' / ', @GhostOwnedByB), N'-')),
        CASE WHEN @Err6 IS NOT NULL THEN N'FAIL'
             WHEN @GhostInserted = 0 THEN N'SKIP - the database refuses an owner with no Users row'
             WHEN @GhostTransfers = 0 AND @GhostOwnedByB = 2 THEN N'PASS' ELSE N'FAIL' END);

/* ---------------------------------------------------------------------------------------------
   Case 7 (PR #72 review): an unknown e-mail asking who else owns a logger is told nothing.
   --------------------------------------------------------------------------------------------- */
DECLARE @Err7 NVARCHAR(4000), @UnknownSees INT;
BEGIN TRY
    BEGIN TRAN;
    EXEC dbo.AssignMeasurmentDevicesToCalibrator @LoggedInUserEmail = @A, @LoggerMeasurementDeviceId = @L,
         @FlowRate = N'Slow', @Interval = 1, @CommunicationProtocol = N'COM', @CommunicationDetails = N'COM3',
         @SensorMeasurementDeviceId = @S1, @UnitId = NULL, @WorkRangeUnitId = NULL, @ChannelNumbers = N'0';
    DELETE #Others;
    INSERT #Others EXEC dbo.GetLoggerOtherOwners @LoggedInUserEmail = N'nobody+mba1056@invalid.example',
                                                 @LoggerMeasurementDeviceId = @L;
    SELECT @UnknownSees = COUNT(*) FROM #Others;
    ROLLBACK;
END TRY
BEGIN CATCH
    SET @Err7 = ERROR_MESSAGE();
    IF @@TRANCOUNT > 0 ROLLBACK;
END CATCH
INSERT @Out (Test, Expected, Actual, Result)
VALUES (N'7 unknown e-mail: no other owners listed', N'0', COALESCE(LEFT(@Err7, 60), CONCAT(@UnknownSees, N'')),
        IIF(@Err7 IS NULL AND @UnknownSees = 0, N'PASS', N'FAIL'));

/* ---------------------------------------------------------------------------------------------
   Case 5: the file left nothing behind.
   --------------------------------------------------------------------------------------------- */
DECLARE @Left INT = (SELECT COUNT(*) FROM dbo.SensorToLoggerRelation WHERE LoggerMeasurementDeviceId = @L)
                  + (SELECT COUNT(*) FROM dbo.LoggerOwnershipTransfer WHERE LoggerMeasurementDeviceId = @L)
                  + (SELECT COUNT(*) FROM dbo.ChannelsToSensorRelation WHERE LoggerMeasurementDeviceId = @L);
INSERT @Out (Test, Expected, Actual, Result)
VALUES (N'5 nothing left behind on the test logger', N'0', CONCAT(@Left, N''), IIF(@Left = 0, N'PASS', N'FAIL'));

SELECT Test, Expected, Actual, Result FROM @Out ORDER BY Seq;
