/*
    Customers - IsInactiveInSource
    ---------------------------------------------------------------------------------------------
    Priority marks a customer record dead with CUSTOMERS.CUSTSTAT = -5 ("לא פעיל"), resolved through
    CUSTSTATS.INACTIVE = 'Y'. Nothing carried that flag across to this database, so 1,535 of the
    10,505 MABA customers sit here looking exactly as alive as the other 8,970.

    That is not cosmetic. The same company is often present twice - one live record and one dead one
    that Priority keeps for history - and both arrive with IsDeleted = 0. Worked example:

        CUST 1123  code 2025  ווסט פארמה סרוויסס איי אל   CUSTSTAT -2  active, 1,220 invoices
        CUST 7639  code 8556  ווסט פארמה סרוויסס איי אל   CUSTSTAT -5  dead since ~2020

    Both are here as CustomerId 1123 and 7553, both IsActive, both IsDeleted = 0, and 14 contacts
    hang off the dead one. Any screen that picks a customer by NAME can land on either. 226 name
    groups covering 465 rows are duplicated this way.

    IsDeleted already exists but means something else - it is this system's own soft delete, set by
    our users. This column is the *source system's* opinion and is owned by
    dbo.RefreshCustomerStatusFromPriority; do not set it by hand.

    Only SourceId = 1 (MABA) is fed from Priority. SEPHARM rows keep the 0 default, which is honest:
    we hold no status for them.

    NOT NULL DEFAULT 0 is deliberate - an unknown status must read as "active" so nothing disappears
    from a screen the moment this column lands and before the refresh has run.
*/
IF NOT EXISTS (
    SELECT 1 FROM sys.columns c
    JOIN sys.tables t ON t.object_id = c.object_id
    WHERE t.name = 'Customers' AND c.name = 'IsInactiveInSource')
BEGIN
    ALTER TABLE dbo.Customers
        ADD IsInactiveInSource BIT NOT NULL
            CONSTRAINT DF_Customers_IsInactiveInSource DEFAULT (0);
END
