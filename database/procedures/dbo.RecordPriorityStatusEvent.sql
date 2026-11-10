/*
    dbo.RecordPriorityStatusEvent                                                      MBA-911
    ---------------------------------------------------------------------------------------------
    The one way the Calibrator app reports a calibration step for Priority. The app calls it at each
    action - calibration opened (AC), report generated (GR, and CD on the first one), first and
    second signature (H1, H2), rejection by the second signer (HR), on hold / resumed (DC, DM, FC),
    and the update-report family (UC, UD, UM, UF, UG). It checks the step, records it in
    dbo.PriorityStatusOutbox, and returns one row saying what happened.

    Nothing is sent to Priority here, in any mode. Sending is phase 3.

    A rule refusal is NOT an error. The app's action (signing, generating a report) must never fail
    because Priority reporting refused it; the refusal is recorded with its reason and returned. Only
    a broken call - unknown device row, empty EventKey, a StatusCode that is not exactly two
    characters - throws.

        Result columns: OutboxId, Doc, StatusCode, State, Reason, IsDuplicate

    THE RULES, in the order they are checked
    ----------------------------------------
    Mode       dbo.PriorityStatusWriteMode = 'Off' -> nothing recorded, State 'Off'.
    NoDoc      the device row has no Priority Doc yet -> not recorded (the outbox is keyed by Doc).
    duplicate  same (Doc, StatusCode, EventKey) already accepted -> that row is returned, IsDuplicate 1.
    NotAppCode a code not marked AppMayWrite in dbo.PriorityCalibrationStatusCodes: the codes Priority
               writes itself (AA received, TX sent, PI packed, CO collected, KM subcontractor), the
               ones the app does not produce (PR, UP, UX), and any code the seed has not described.
               Writing AA/TX/... from here would duplicate what Priority already records.
    Ownership  a calibration belongs to the program it was opened in. AC is refused
               ('OwnedByMABA2000') when Priority's log already shows any step for the Doc that is not
               one of Priority's own - MABA 2000 got there first. It FAILS CLOSED: a step whose code
               is unseeded ('Unknown') or missing from the codes table counts as MABA 2000's, so a
               skipped seed refuses openings instead of letting the app take over MABA 2000's work. Every other code needs an accepted AC from the app
               ('NotOpenedInApp'). So a Doc is reported by one program only, which is the release-note
               rule "one device, one program". The log mirror is refreshed hourly, so a MABA 2000 start
               inside the last hour is not seen here; phase 3 reconciles that before sending.
    ACAlreadyRecorded   one AC per Doc.
    LockedAfterTX       after Priority recorded TX (sent to customer) the report is locked: only
                        update-report codes (U*) may follow (the lab's status document), and the
                        signatures of an update report - H1, H2, HR while the latest report generated
                        is an update report (UG). An update report is signed like any other.
    CDAlreadyRecorded   CD marks the FIRST report only.
    H1WithoutReport     H1 needs a report: the last of GR/UG/H1/H2/HR must be GR or UG. After HR the
                        calibrator fixes the report, generates it again, and signs again.
    H2WithoutH1         H2 needs H1 as the last of GR/UG/H1/H2/HR.
    HRWithoutH1         a rejection is of a first-signed report.
    AlreadyOnHold / NotOnHold   DC/DM cannot follow DC/DM; FC must follow DC/DM. Same for UD/UM -> UF.
    UGWithoutUC         an update report is generated only after one was opened.

    Concurrency: calls are serialised per Doc with an application lock, so two signatures arriving
    together are checked one after the other against the same history. If the lock cannot be had
    within 10 seconds the call throws rather than carrying on unlocked.

    Times: @EventAt is LOCAL time, like the app's other dates and like Priority's; it defaults to the
    server's local now. RecordedAt (the outbox's own bookkeeping) is UTC, like FetchedAt elsewhere.
*/
/*
    QUOTED_IDENTIFIER / ANSI_NULLS must be ON: this procedure inserts into dbo.PriorityStatusOutbox, which has a filtered unique index. A
    procedure keeps the SET options it was created with, and one created under the OFF setting sqlcmd
    defaults to fails every INSERT with error 1934. See dbo.PriorityStatusOutbox.table.sql.
*/
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

CREATE OR ALTER PROCEDURE dbo.RecordPriorityStatusEvent
    @OrderDetailsItemId INT,
    @StatusCode         NVARCHAR(10),   /* wider than a code on purpose: 'GRX' must fail, not become 'GR' */
    @EventKey           NVARCHAR(100),
    @UserId             INT           = NULL,
    @EventAt            DATETIME2(0)  = NULL,
    @UpdateReportNumber NVARCHAR(16)  = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @RawCode NVARCHAR(10) = UPPER(LTRIM(RTRIM(@StatusCode))),
            @Key     NVARCHAR(100) = NULLIF(LTRIM(RTRIM(@EventKey)), N''),
            @Mode    VARCHAR(12)   = (SELECT Mode FROM dbo.PriorityStatusWriteMode WHERE Id = 1);

    IF @RawCode IS NULL OR LEN(@RawCode) <> 2
        THROW 51000, '@StatusCode must be exactly two characters, e.g. ''GR''.', 1;

    DECLARE @Code CHAR(2) = CAST(@RawCode AS CHAR(2));
    IF @Key IS NULL
        THROW 51000, '@EventKey is required: the app''s stable id for this action, the same on a retry.', 1;
    IF @Mode IS NULL
        THROW 51000, 'dbo.PriorityStatusWriteMode has no row; deploy dbo.PriorityStatusWriteMode.table.sql.', 1;

    IF @Mode = 'Off'
    BEGIN
        SELECT CAST(NULL AS INT) AS OutboxId, CAST(NULL AS INT) AS Doc, @Code AS StatusCode,
               'Off' AS State, 'WritingOff' AS Reason, CAST(0 AS BIT) AS IsDuplicate;
        RETURN;
    END

    DECLARE @Doc INT, @Mba NVARCHAR(100);
    SELECT @Doc = i.Doc, @Mba = i.MbaReportNumber
    FROM dbo.OrderDetailsItems AS i
    WHERE i.OrderDetailsItemId = @OrderDetailsItemId AND i.IsDeleted = 0;

    IF @@ROWCOUNT = 0
        THROW 51000, 'Unknown or deleted OrderDetailsItemId.', 1;

    IF @Doc IS NULL
    BEGIN
        SELECT CAST(NULL AS INT) AS OutboxId, CAST(NULL AS INT) AS Doc, @Code AS StatusCode,
               'Refused' AS State, 'NoDoc' AS Reason, CAST(0 AS BIT) AS IsDuplicate;
        RETURN;
    END

    DECLARE @Lock NVARCHAR(255) = N'PriorityStatusOutbox:' + CAST(@Doc AS NVARCHAR(12)),
            @Reason VARCHAR(40), @OutboxId INT;

    BEGIN TRAN;

    /* sp_getapplock reports a timeout (-1), cancel (-2) or deadlock (-3) by its return code, not by
       raising an error, so XACT_ABORT does not catch it. Carrying on unlocked would let two calls read
       the same history and both be accepted - two H2s on one H1 - which is what the lock is for. */
    DECLARE @rc INT;
    EXEC @rc = sys.sp_getapplock @Resource = @Lock, @LockMode = 'Exclusive', @LockOwner = 'Transaction',
                                 @LockTimeout = 10000;
    IF @rc < 0
        THROW 51000, 'Could not lock the calibration (Doc) for reporting; try again.', 1;

    /* Retry or double click: return what was recorded the first time. */
    SELECT @OutboxId = o.OutboxId
    FROM dbo.PriorityStatusOutbox AS o
    WHERE o.Doc = @Doc AND o.StatusCode = @Code AND o.EventKey = @Key AND o.State <> 'Refused';

    IF @OutboxId IS NOT NULL
    BEGIN
        COMMIT;
        SELECT OutboxId, Doc, StatusCode, State, Reason, CAST(1 AS BIT) AS IsDuplicate
        FROM dbo.PriorityStatusOutbox WHERE OutboxId = @OutboxId;
        RETURN;
    END

    /* The Doc's accepted history in the app, and what Priority's log says. */
    DECLARE @HasAC BIT = CASE WHEN EXISTS (SELECT 1 FROM dbo.PriorityStatusOutbox
                                           WHERE Doc = @Doc AND StatusCode = 'AC' AND State <> 'Refused')
                              THEN 1 ELSE 0 END;

    DECLARE @LastReport CHAR(2) = (SELECT TOP (1) StatusCode FROM dbo.PriorityStatusOutbox
                                   WHERE Doc = @Doc AND State <> 'Refused'
                                     AND StatusCode IN ('GR', 'UG', 'H1', 'H2', 'HR')
                                   ORDER BY OutboxId DESC),
            @LastGen    CHAR(2) = (SELECT TOP (1) StatusCode FROM dbo.PriorityStatusOutbox
                                   WHERE Doc = @Doc AND State <> 'Refused'
                                     AND StatusCode IN ('GR', 'UG')
                                   ORDER BY OutboxId DESC),
            @LastHold   CHAR(2) = (SELECT TOP (1) StatusCode FROM dbo.PriorityStatusOutbox
                                   WHERE Doc = @Doc AND State <> 'Refused'
                                     AND StatusCode IN ('DC', 'DM', 'FC')
                                   ORDER BY OutboxId DESC),
            @LastUHold  CHAR(2) = (SELECT TOP (1) StatusCode FROM dbo.PriorityStatusOutbox
                                   WHERE Doc = @Doc AND State <> 'Refused'
                                     AND StatusCode IN ('UD', 'UM', 'UF')
                                   ORDER BY OutboxId DESC);

    SET @Reason =
        CASE
            WHEN NOT EXISTS (SELECT 1 FROM dbo.PriorityCalibrationStatusCodes
                             WHERE StatusCode = @Code AND AppMayWrite = 1)
                THEN 'NotAppCode'
            WHEN @Code = 'AC' AND @HasAC = 1
                THEN 'ACAlreadyRecorded'
            /* Fails closed: any step that is not known to be Priority's own counts as MABA 2000's. */
            WHEN @Code = 'AC' AND EXISTS (SELECT 1
                                          FROM dbo.PriorityCalibrationStatusLog AS g
                                          WHERE g.Doc = @Doc
                                            AND NOT EXISTS (SELECT 1 FROM dbo.PriorityCalibrationStatusCodes AS c
                                                            WHERE c.StatusCode = g.StatusCode
                                                              AND c.WrittenBy = 'Priority'))
                THEN 'OwnedByMABA2000'
            WHEN @Code <> 'AC' AND @HasAC = 0
                THEN 'NotOpenedInApp'
            WHEN @Code NOT LIKE 'U%'
                 AND NOT (@Code IN ('H1', 'H2', 'HR') AND @LastGen = 'UG')   /* signing an update report */
                 AND EXISTS (SELECT 1 FROM dbo.PriorityCalibrationStatusLog
                             WHERE Doc = @Doc AND StatusCode = 'TX')
                THEN 'LockedAfterTX'
            WHEN @Code = 'CD' AND EXISTS (SELECT 1 FROM dbo.PriorityStatusOutbox
                                          WHERE Doc = @Doc AND StatusCode = 'CD' AND State <> 'Refused')
                THEN 'CDAlreadyRecorded'
            WHEN @Code = 'H1' AND ISNULL(@LastReport, '') NOT IN ('GR', 'UG')
                THEN 'H1WithoutReport'
            WHEN @Code = 'H2' AND ISNULL(@LastReport, '') <> 'H1'
                THEN 'H2WithoutH1'
            WHEN @Code = 'HR' AND ISNULL(@LastReport, '') <> 'H1'
                THEN 'HRWithoutH1'
            WHEN @Code IN ('DC', 'DM') AND @LastHold IN ('DC', 'DM')
                THEN 'AlreadyOnHold'
            WHEN @Code = 'FC' AND ISNULL(@LastHold, '') NOT IN ('DC', 'DM')
                THEN 'NotOnHold'
            WHEN @Code IN ('UD', 'UM') AND @LastUHold IN ('UD', 'UM')
                THEN 'AlreadyOnHold'
            WHEN @Code = 'UF' AND ISNULL(@LastUHold, '') NOT IN ('UD', 'UM')
                THEN 'NotOnHold'
            WHEN @Code = 'UG' AND NOT EXISTS (SELECT 1 FROM dbo.PriorityStatusOutbox
                                              WHERE Doc = @Doc AND StatusCode = 'UC' AND State <> 'Refused')
                THEN 'UGWithoutUC'
        END;

    INSERT INTO dbo.PriorityStatusOutbox
        (Doc, StatusCode, EventKey, State, Reason, OrderDetailsItemId, MbaReportNumber,
         UpdateReportNumber, UserId, EventAt)
    VALUES
        (@Doc, @Code, @Key,
         CASE WHEN @Reason IS NULL THEN 'ReportOnly' ELSE 'Refused' END,
         @Reason, @OrderDetailsItemId, @Mba,
         NULLIF(LTRIM(RTRIM(@UpdateReportNumber)), N''), @UserId,
         COALESCE(@EventAt, CAST(SYSDATETIME() AS DATETIME2(0))));

    SET @OutboxId = SCOPE_IDENTITY();

    COMMIT;

    SELECT OutboxId, Doc, StatusCode, State, Reason, CAST(0 AS BIT) AS IsDuplicate
    FROM dbo.PriorityStatusOutbox WHERE OutboxId = @OutboxId;
END
GO
