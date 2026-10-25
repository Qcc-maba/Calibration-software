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

    2026-09-30 - MBA-903: the customer rule now does what the paragraph above says.
    ---------------------------------------------------------------------------------------------
    Two gaps, both on the customer path:
      - "Only while it is still New" was documented but not enforced: a customer could cancel a
        request MBA had already moved to InProgress. It now throws 52016.
      - Ownership was checked against any CustomerContacts row of the request's customer, without
        IsActive - so a contact Priority had marked INACTIVE could still withdraw requests. It is
        now "the request's customer is in dbo.GetPortalCustomerIds for this address", the same set
        dbo.GetCustomerPortalRequestList shows and dbo.CreateCustomerPortalRequest files under: a
        customer can cancel exactly the requests their list shows them.
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
        IF NOT EXISTS (SELECT 1 FROM dbo.GetPortalCustomerIds(@Email) AS mine
                       WHERE mine.CustomerId = @OwnerCustomerId)
            THROW 52014, 'This request does not belong to the caller.', 1;

        IF @Status <> N'Cancelled'
            THROW 52015, 'A customer may only cancel their own request.', 1;

        IF @CurrentStatus <> N'New'
            THROW 52016, 'MBA has already started on this request; it can no longer be cancelled.', 1;
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
