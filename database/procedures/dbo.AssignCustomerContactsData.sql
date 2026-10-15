/*
    dbo.AssignCustomerContactsData                                                      MBA-627
    ---------------------------------------------------------------------------------------------
    Saves the portal caller's OWN contact details from the profile screen. Nothing else.

    2026-10-15 - MBA-627: rewritten before its first caller. The previous definition (identical on
    STAGE and PROD, kept in database/_rollback/BOTH.dbo.AssignCustomerContactsData.before-MBA-627.sql)
    had no caller anywhere - no app code, no other SQL module - and three faults that would have gone
    live with the profile screen:

      1. The remove path soft-deleted every id in @CustomerContactsIdsToRemove with no customer
         filter, and ran even when the e-mail resolved to nobody. Any caller could delete any
         customer's contacts by id. (SECURITY.md SEC-11.)
      2. The caller was resolved through dbo.GetSourceFilterByEmail, which reads dbo.Users. A portal
         customer is a dbo.CustomerContacts row and has no Users row - on PROD 0 of 28,573 contacts
         have a Users row for the same customer - so @CustomerId was NULL: an update silently did
         nothing (the portal would have shown "saved") and an insert failed on the NOT NULL column.
         GetCustomerContacts and GetCustomerSites had the same defect and were fixed on 2026-08-30.
      3. Had the lookup worked, the scope was the whole customer: any @CustomerContactsId of the
         caller's company could be edited, and @CustomerSiteId was never checked at all.

    The rule now (agreed on MBA-627): a portal user edits only their own profile, saved straight
    away with no MABA approval step. So:

      - No row id comes from the client. The rows edited are found from @LoggedInUserEmail alone,
        so there is nothing to guess and nothing to forge.
      - No insert and no remove. @CustomerContactsId, @CustomerContactsIdsToRemove and
        @RevertDeletion are gone; a caller still passing them fails with "too many arguments"
        rather than being half-honoured. Contacts are Priority's (PHONEBOOK) - a contact added
        here would never reach Priority, and nothing is removed because of the portal either.
      - Portal callers only. The staff path through dbo.GetSourceFilterByEmail is gone: the staff
        app has no server-side session (SEC-3), so an e-mail it sends proves nothing.

    WHICH ROWS ARE "OWN"
    --------------------
    Every live, active contact row carrying the caller's address - the same rows the `mine` step of
    dbo.GetPortalCustomerIds starts from. 3,844 addresses on PROD are a contact of more than one
    customer (one Iscar manager is a contact of 22). They are one person, and the address is their
    login, so a change applies to all of their rows. Updating only one would split the identity:
    a new e-mail would sign in to that one customer, the old one to the rest.

    The device filter of GetPortalCustomerIds is deliberately not applied here: it decides what a
    caller may SEE, not who they are. It is still used to refuse an address that is not a portal
    caller at all.

    PARAMETERS
    ----------
    NULL keeps the current value. An empty string clears the optional fields (role, both phones);
    the name cannot be cleared.

    THE E-MAIL CANNOT BE CHANGED YET (MBA-627, decided 2026-10-15). @CustomerContactEmail is accepted
    so the form can send every field, but only the caller's current address (any case) passes;
    anything else is refused with 54006 and nothing is written. The address is the login, so a
    change must be verified first: a code sent to the new address and entered in the form, checked
    here, then a new session for the new address and a notice to the old one. That waits for the
    sync gap below - the sync would put the old address back and lock the customer out again.
    54003 and 54004 are kept free for that flow (malformed address; address of another contact).

    Refusals, all before anything is written:
      54001  the address is not a portal contact
      54002  name sent empty
      54005  @CustomerSiteId is not a live site of a customer the caller is a contact of. The site is
             written only on the caller's row for that customer.
      54006  @CustomerContactEmail differs from the caller's address - see above

    KNOWN GAP - not solved here: stg.MergeCustomersContactsData overwrites name, role, phones and
    e-mail from Priority whenever they differ, so an edit lasts only until the next contact sync
    unless the same change reaches Priority. Tracked on MBA-627.

    UpdateUserID is NULL on a portal edit: the caller has no dbo.Users row. The sync writes 0.

    Returns the caller's rows as saved, one per customer.
*/
CREATE OR ALTER PROCEDURE [dbo].[AssignCustomerContactsData]
    @LoggedInUserEmail                    NVARCHAR(100),
    @CustomerContactName                  NVARCHAR(50) = NULL,
    @CustomerContactPersonRole            NVARCHAR(50) = NULL,
    @CustomerContactPhone                 NVARCHAR(50) = NULL,
    @CustomerContactAdditionalPhoneNumber NVARCHAR(50) = NULL,
    @CustomerContactEmail                 NVARCHAR(50) = NULL,
    @CustomerSiteId                       INT          = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Email NVARCHAR(100) = LOWER(LTRIM(RTRIM(@LoggedInUserEmail)));

    IF NOT EXISTS (SELECT 1 FROM dbo.GetPortalCustomerIds(@Email))
        THROW 54001, 'The address does not belong to any customer contact.', 1;

    /* The caller's own rows - see the header. */
    SELECT cc.CustomerContactId, cc.CustomerId
    INTO #Own
    FROM dbo.CustomerContacts AS cc
    WHERE ISNULL(cc.IsDeleted, 0) = 0
      AND ISNULL(cc.IsActive, 1) = 1
      AND LOWER(LTRIM(RTRIM(cc.CustomerContactEmail))) = @Email;

    DECLARE @Name NVARCHAR(50) = LTRIM(RTRIM(@CustomerContactName));

    IF @Name = N''
        THROW 54002, 'The name cannot be cleared.', 1;

    /* MBA-627: no e-mail change until it can be verified - see the header. */
    IF @CustomerContactEmail IS NOT NULL
       AND LOWER(LTRIM(RTRIM(@CustomerContactEmail))) <> @Email
        THROW 54006, 'Changing the e-mail is not available yet (MBA-627).', 1;

    DECLARE @SiteCustomerId INT = NULL;
    IF @CustomerSiteId IS NOT NULL
    BEGIN
        SELECT @SiteCustomerId = cs.CustomerId
        FROM dbo.CustomerSites AS cs
        INNER JOIN #Own AS o ON o.CustomerId = cs.CustomerId
        WHERE cs.CustomerSiteId = @CustomerSiteId
          AND cs.IsDeleted = 0;

        IF @SiteCustomerId IS NULL
            THROW 54005, 'The site does not belong to the caller.', 1;
    END

    BEGIN TRAN;

        UPDATE cc
        SET  cc.CustomerContactName                  = COALESCE(@Name, cc.CustomerContactName)
            ,cc.CustomerContactPersonRole            = IIF(@CustomerContactPersonRole IS NULL, cc.CustomerContactPersonRole,
                                                           NULLIF(LTRIM(RTRIM(@CustomerContactPersonRole)), N''))
            ,cc.CustomerContactPhone                 = IIF(@CustomerContactPhone IS NULL, cc.CustomerContactPhone,
                                                           NULLIF(LTRIM(RTRIM(@CustomerContactPhone)), N''))
            ,cc.CustomerContactAdditionalPhoneNumber = IIF(@CustomerContactAdditionalPhoneNumber IS NULL, cc.CustomerContactAdditionalPhoneNumber,
                                                           NULLIF(LTRIM(RTRIM(@CustomerContactAdditionalPhoneNumber)), N''))
            ,cc.CustomerSiteId                       = IIF(cc.CustomerId = @SiteCustomerId, @CustomerSiteId, cc.CustomerSiteId)
            ,cc.UpdatedDate                          = GETDATE()
            ,cc.UpdateUserID                         = NULL
        FROM dbo.CustomerContacts AS cc
        INNER JOIN #Own AS o ON o.CustomerContactId = cc.CustomerContactId;

    COMMIT;

    SELECT cc.CustomerContactId                    AS customerContactId,
           cc.CustomerId                           AS customerId,
           c.CustomerName                          AS customerName,
           cc.CustomerContactName                  AS name,
           cc.CustomerContactPersonRole            AS role,
           cc.CustomerContactPhone                 AS phone,
           cc.CustomerContactAdditionalPhoneNumber AS additionalPhone,
           cc.CustomerContactEmail                 AS email,
           cc.CustomerSiteId                       AS customerSiteId
    FROM #Own AS o
    INNER JOIN dbo.CustomerContacts AS cc ON cc.CustomerContactId = o.CustomerContactId
    LEFT JOIN dbo.Customers AS c ON c.CustomerId = cc.CustomerId
    ORDER BY cc.CustomerId;
END
GO
