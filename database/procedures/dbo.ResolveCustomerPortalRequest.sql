/*
    dbo.ResolveCustomerPortalRequest                                                    MBA-903
    ---------------------------------------------------------------------------------------------
    Moves a portal request along - MBA answers it, or the customer withdraws it.

    Two callers, one procedure, and the difference matters:

      MBA staff (@LoggedInUserEmail matches dbo.Users) may set any status.
      The customer who filed it may only set Cancelled, and only while it is still New. Once MBA
      has started work, withdrawing it silently would leave somebody holding a device with no
      record of why.

    Anyone else is refused. The request id alone is not authority to change it - a customer cannot
    resolve another customer's request by guessing a number.

    Approved / Rejected / Done are terminal and stamp ResolvedDate. Re-resolving an already
    terminal request is refused rather than quietly overwriting who answered it and when.
*/
CREATE OR ALTER PROCEDURE dbo.ResolveCustomerPortalRequest
    @LoggedInUserEmail       NVARCHAR(100),
    @CustomerPortalRequestId BIGINT,
    @Status                  NVARCHAR(20),
    @ResolutionNotes         NVARCHAR(1000) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @Status NOT IN (N'New', N'InProgress', N'Approved', N'Rejected', N'Cancelled', N'Done')
        THROW 52011, 'Unknown Status.', 1;

    DECLARE @Email NVARCHAR(100) = LOWER(LTRIM(RTRIM(@LoggedInUserEmail)));

    DECLARE @CurrentStatus NVARCHAR(20), @OwnerCustomerId INT;
    SELECT @CurrentStatus = r.Status, @OwnerCustomerId = r.CustomerId
    FROM dbo.CustomerPortalRequest AS r
    WHERE r.CustomerPortalRequestId = @CustomerPortalRequestId
      AND r.IsDeleted = 0;

    IF @CurrentStatus IS NULL
        THROW 52012, 'No such request.', 1;

    IF @CurrentStatus IN (N'Approved', N'Rejected', N'Cancelled', N'Done')
        THROW 52013, 'This request has already been resolved.', 1;

    DECLARE @MbaUserId INT;
    SELECT TOP (1) @MbaUserId = u.ID FROM dbo.Users AS u
    WHERE LOWER(LTRIM(RTRIM(u.Email))) = @Email;

    IF @MbaUserId IS NULL
    BEGIN
        /* Not MBA staff - then it must be the customer who filed it, cancelling it. */
        IF NOT EXISTS (SELECT 1 FROM dbo.CustomerContacts AS cc
                       WHERE cc.IsDeleted = 0
                         AND cc.CustomerId = @OwnerCustomerId
                         AND LOWER(LTRIM(RTRIM(cc.CustomerContactEmail))) = @Email)
            THROW 52014, 'This request does not belong to the caller.', 1;

        IF @Status <> N'Cancelled'
            THROW 52015, 'A customer may only cancel their own request.', 1;
    END

    UPDATE dbo.CustomerPortalRequest
    SET Status           = @Status,
        ResolutionNotes  = COALESCE(@ResolutionNotes, ResolutionNotes),
        ResolvedByUserId = @MbaUserId,
        ResolvedDate     = IIF(@Status IN (N'Approved', N'Rejected', N'Cancelled', N'Done'),
                               SYSUTCDATETIME(), NULL)
    WHERE CustomerPortalRequestId = @CustomerPortalRequestId;

    SELECT @CustomerPortalRequestId AS customerPortalRequestId, @Status AS status;
END
