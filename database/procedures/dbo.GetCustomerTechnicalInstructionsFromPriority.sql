/*
    dbo.GetCustomerTechnicalInstructionsFromPriority
    ---------------------------------------------------------------------------------------------
    The customer's "הוראות טכניות" tab in Priority, which is where the coordinators actually keep
    the standing instructions for a customer - not dbo.CustomerRemarks, which is what the wizard
    showed.

    WHERE IT LIVES
    --------------
    amaba.dbo.MBA_CUSTOMERSTEXT, a MABA-specific table behind the customised Priority form. One row
    per line of rich text, ordered by TEXTLINE. West Pharma (CUSTNAME '2025', CUST 1123) has 461 of
    them.

    TWO THINGS ABOUT THE CONTENT
    ----------------------------
    1. Every line is stored REVERSED, the usual Priority visual-order problem: the first line reads
       'il,vid,p >elyts<', which is '<style> p,div,li' backwards. Reversing each line and joining
       them in TEXTLINE order reassembles a valid HTML document.
    2. It is HTML, not plain text - style blocks, font tags, alignment attributes. Stripping it is
       left to the caller, because doing it here would mean writing an HTML parser in T-SQL.

    So this procedure returns the lines as they are, in order. It does NOT un-reverse them:
    dbo.fnUnreverseVisualText is built for display text and peels trailing punctuation, which would
    corrupt markup. A plain character reversal is what this content needs, and the caller does it.

    WHY THE WHOLE STATEMENT IS INSIDE OPENQUERY
    -------------------------------------------
    The house rule, and it is not cosmetic: a join written with four-part names issues one remote
    call per row. 461 lines would be 461 round trips.
*/
CREATE OR ALTER PROCEDURE [dbo].[GetCustomerTechnicalInstructionsFromPriority]
    @CustomerId INT
AS
BEGIN
    SET NOCOUNT ON;

    /* The app's CustomerId is not Priority's key. Customers.CustomerIdFromSource is amaba CUST.
       TRY_CAST to INT rather than quoting a string into the remote statement: this value ends up
       concatenated into dynamic SQL that runs on another server, and CUST is an integer there. A
       non-numeric value is treated as unknown rather than passed through. */
    DECLARE @PriorityCustomer INT = (
        SELECT TOP 1 TRY_CAST(LTRIM(RTRIM(c.CustomerIdFromSource)) AS INT)
        FROM [dbo].[Customers] AS c
        WHERE c.CustomerId = @CustomerId
    );

    IF @PriorityCustomer IS NULL
    BEGIN
        /* An empty result set, not an error: a customer that Priority does not know is a normal
           state for a locally created record, and the screen shows no instructions. */
        SELECT CAST(NULL AS INT) AS TextLine, CAST(NULL AS NVARCHAR(MAX)) AS TextReversed
        WHERE 1 = 0;

        RETURN;
    END

    DECLARE @Sql NVARCHAR(MAX) = N'
        SELECT TextLine, TextReversed
        FROM OPENQUERY([31.168.173.93], ''
            SELECT t.TEXTLINE AS TextLine, t.TEXT AS TextReversed
            FROM amaba.dbo.MBA_CUSTOMERSTEXT t
            WHERE t.CUST = ' + CAST(@PriorityCustomer AS NVARCHAR(20)) + N'
        '')
        ORDER BY TextLine;';

    EXEC sp_executesql @Sql;
END
