/*
    CustomerContacts - IsPrimary and DoNotMail                                         MBA-922
    ---------------------------------------------------------------------------------------------
    The contacts column was empty on 46% of orders. Not a display fault and not a query fault: the
    sync took only the one Priority contact carrying ORDFLAG = 'Y', and for 288 of the 306 customers
    behind those orders nobody had ever been flagged. Priority already knew who to call - 5,749
    people we were not importing.

    Option 1 from the ticket: take the whole phonebook and mark the ORDFLAG row as primary, so the
    screen can still show a designated contact while the rest are reachable.

    DoNotMail carries Priority's MBA_NOTMAIL through. 672 people are marked that way and the flag
    has to survive the import, or the portal will end up e-mailing people who asked it not to.
*/
IF COL_LENGTH('dbo.CustomerContacts','IsPrimary') IS NULL
    ALTER TABLE dbo.CustomerContacts ADD IsPrimary BIT NOT NULL
        CONSTRAINT DF_CustomerContacts_IsPrimary DEFAULT(0);
GO
IF COL_LENGTH('dbo.CustomerContacts','DoNotMail') IS NULL
    ALTER TABLE dbo.CustomerContacts ADD DoNotMail BIT NOT NULL
        CONSTRAINT DF_CustomerContacts_DoNotMail DEFAULT(0);
GO
IF COL_LENGTH('stg.stg_CustomerContacts','IsPrimary') IS NULL
    ALTER TABLE stg.stg_CustomerContacts ADD IsPrimary BIT NULL;
GO
IF COL_LENGTH('stg.stg_CustomerContacts','DoNotMail') IS NULL
    ALTER TABLE stg.stg_CustomerContacts ADD DoNotMail BIT NULL;
GO
