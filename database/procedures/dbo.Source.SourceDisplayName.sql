/*
    dbo.Source - separating the integration key from the display name
    ---------------------------------------------------------------------------------------------
    "SEPHARM" is how the subsidiary's name reaches us, and it should read "SEPharma" on screen.

    SourceName cannot simply be updated. It is the join key for the entire Priority sync:

        stg.MergeOrdersData            JOIN dbo.Source s ON o.SourceSystem  = s.SourceName
        stg.MergeCustomersData         JOIN dbo.Source ss ON c.SourceSystem = ss.SourceName
        stg.MergeCustomersContactsData, stg.MergeCustomerRemarks,
        stg.MergeMabaComments, stg.MergeClientAccessoryOrderDetailsItems - the same

    Priority sends the literal 'SEPHARM' and 779 staging rows carry it right now (735 customers,
    36 orders, 5 contacts, 3 remarks). The collation is CI_AI, but 'SEPHARM' and 'SEPharma' differ
    by a trailing character, so case-insensitivity does not rescue the join - every SE PHARMA
    customer, contact, remark and order would stop syncing, silently.

    So the key stays and the display name moves to its own column. The five procedures that put
    this on screen return SourceDisplayName aliased as SourceName, which leaves the result set
    identical for the front end.
*/
IF COL_LENGTH('dbo.Source','SourceDisplayName') IS NULL
    ALTER TABLE dbo.Source ADD SourceDisplayName NVARCHAR(100) NULL;
GO
UPDATE dbo.Source SET SourceDisplayName = N'MABA'     WHERE SourceId = 1;
UPDATE dbo.Source SET SourceDisplayName = N'SEPharma' WHERE SourceId = 2;
UPDATE dbo.Source SET SourceDisplayName = N'גפן'      WHERE SourceId = 3;
UPDATE dbo.Source SET SourceDisplayName = SourceName  WHERE SourceDisplayName IS NULL;
GO
