/*
    CustomerContacts - IsActive
    ---------------------------------------------------------------------------------------------
    Priority marks a contact who has left, or who should no longer be written to, with
    PHONEBOOK.INACTIVE = 'Y'. 9,101 of its 53,424 contacts carry that flag. The sync never read the
    column, so the mirror holds 10,501 live contact rows for people Priority considers inactive -
    and the portal treats every one of them as a legitimate login identity.

    Nothing is deleted on either side: Priority keeps its history, the mirror keeps the row, and
    the flag travels with it. Everything that resolves a portal visitor to a customer now ignores
    an inactive contact, exactly as it would ignore one that was never imported.

    Default 1: a contact the sync has not re-touched yet is active, which is what every existing
    row is until the next load says otherwise.
*/
IF COL_LENGTH('dbo.CustomerContacts','IsActive') IS NULL
    ALTER TABLE dbo.CustomerContacts ADD IsActive BIT NOT NULL
        CONSTRAINT DF_CustomerContacts_IsActive DEFAULT(1);
GO
IF COL_LENGTH('stg.stg_CustomerContacts','IsActive') IS NULL
    ALTER TABLE stg.stg_CustomerContacts ADD IsActive BIT NULL;
GO
