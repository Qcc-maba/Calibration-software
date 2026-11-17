/*
    dbo.GetPriorityLinkedServer                                                        MBA-1028
    ---------------------------------------------------------------------------------------------
    The linked server this database reads Priority through, already QUOTENAME'd for splicing into
    dynamic SQL:

        DECLARE @Link NVARCHAR(258);
        EXEC dbo.GetPriorityLinkedServer @QuotedName = @Link OUTPUT;
        SET @Sql = N'SELECT ... FROM OPENQUERY(' + @Link + N', ''...'')';

    Throws instead of guessing. 51020: dbo.PriorityLinkedServer has no row. 51021: the row names a
    server this database must not use, or one that does not exist (dbo.fnPriorityLinkRefusal).
    Either way nothing reaches Priority, which is the point: a STAGE that cannot read Priority is a
    visible error, a STAGE that reads production is not.

    Called before every OPENQUERY. Cost: one single-row read and one sys.servers lookup.
*/
CREATE OR ALTER PROCEDURE dbo.GetPriorityLinkedServer
    @QuotedName NVARCHAR(258) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Name SYSNAME = (SELECT LinkedServer FROM dbo.PriorityLinkedServer WHERE Id = 1);

    IF @Name IS NULL
        THROW 51020, N'dbo.PriorityLinkedServer has no row: run dbo.SetPriorityLinkedServer on this database first (MBA-1028).', 1;

    DECLARE @Refusal NVARCHAR(400) = dbo.fnPriorityLinkRefusal(@Name);
    IF @Refusal IS NOT NULL
        THROW 51021, @Refusal, 1;

    SET @QuotedName = QUOTENAME(@Name);
END
GO
