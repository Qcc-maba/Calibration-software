/*
    dbo.LogCalibrationReportSend                                                       MBA-337
    ---------------------------------------------------------------------------------------------
    Records one attempt to e-mail a calibration report.

    Call it for BOTH outcomes. A failed send is the row you most want to find later, when a customer
    says the report never arrived — logging only successes would leave exactly that case invisible.

    Recording must never be what breaks sending: if the caller passes something unusable the
    procedure raises, but the caller should treat a logging failure as a warning, not as a reason to
    tell the calibrator the mail did not go out. It did.

    Returns the id of the row written, so the caller can correlate it with its own logs.
*/
CREATE OR ALTER PROCEDURE dbo.LogCalibrationReportSend
    @OrderDetailsItemId INT,
    @SentToEmail        NVARCHAR(100),
    @Status             NVARCHAR(20),          /* 'Sent' | 'Failed' */
    @LoggedInUserEmail  NVARCHAR(100) = NULL,  /* the calibrator who pressed Send */
    @DocumentPath       NVARCHAR(400) = NULL,
    @IsDraft            BIT           = 0,
    @FailureReason      NVARCHAR(1000) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @Status NOT IN (N'Sent', N'Failed')
        THROW 50001, 'Status must be either Sent or Failed.', 1;

    DECLARE @NormalizedRecipient NVARCHAR(100) = LOWER(LTRIM(RTRIM(@SentToEmail)));

    IF @NormalizedRecipient IS NULL OR @NormalizedRecipient = ''
        THROW 50002, 'A recipient address is required.', 1;

    /* Denormalised on purpose: the report number and the contact can both change afterwards, and
       the log has to keep saying what was true at the moment of sending. */
    DECLARE @MbaReportNumber   NVARCHAR(100),
            @CustomerContactId INT,
            @SentByUserId      INT;

    SELECT @MbaReportNumber = itm.MbaReportNumber
    FROM dbo.OrderDetailsItems AS itm
    WHERE itm.OrderDetailsItemId = @OrderDetailsItemId;

    SELECT TOP (1) @CustomerContactId = cc.CustomerContactId
    FROM dbo.CustomerContacts AS cc
    WHERE cc.IsDeleted = 0
      AND LOWER(LTRIM(RTRIM(cc.CustomerContactEmail))) = @NormalizedRecipient
    ORDER BY cc.CustomerContactId ASC;

    IF @LoggedInUserEmail IS NOT NULL
        SELECT TOP (1) @SentByUserId = u.ID
        FROM dbo.Users AS u
        WHERE LOWER(LTRIM(RTRIM(u.Email))) = LOWER(LTRIM(RTRIM(@LoggedInUserEmail)));

    INSERT INTO dbo.CalibrationReportSendLog
        (OrderDetailsItemId, MbaReportNumber, DocumentPath, IsDraft,
         SentToEmail, CustomerContactId, SentByUserId, SentByEmail,
         Status, FailureReason, SentAt)
    VALUES
        (@OrderDetailsItemId, @MbaReportNumber, @DocumentPath, ISNULL(@IsDraft, 0),
         @NormalizedRecipient, @CustomerContactId, @SentByUserId, LOWER(LTRIM(RTRIM(@LoggedInUserEmail))),
         @Status, @FailureReason, SYSUTCDATETIME());

    SELECT CAST(SCOPE_IDENTITY() AS BIGINT) AS CalibrationReportSendLogId;
END
GO
