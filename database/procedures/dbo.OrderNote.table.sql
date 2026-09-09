/*
    dbo.OrderNote                                                                       MBA-907
    ---------------------------------------------------------------------------------------------
    Notes a coordinator or validator writes on an order.

    The הערות column on the coordinator and validator screens was read-only. What it showed came
    from Priority - wp.Notes, wp.CustomerComment, the CRM instructions - and there was nowhere for
    the person actually handling the order to add anything.

    Append-only, with the author and the moment kept. A note is evidence about a decision, and
    "who said that, and when" is the question that gets asked afterwards - an editable single field
    would lose exactly that. Editing is a new note; removing is a soft delete.

    Keyed to the ORDER, not the device: that is where the column sits and what the coordinator
    works from.

    dbo.OrderWorkPlans.Notes is left alone. It is empty on all 1,159 open work plans and belongs to
    the sync, so writing into it would put our text in the path of the next Priority refresh.
*/
IF OBJECT_ID('dbo.OrderNote', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.OrderNote
    (
        OrderNoteId     BIGINT IDENTITY(1,1) NOT NULL,
        OrderWorkPlanId INT            NOT NULL,
        NoteText        NVARCHAR(2000) NOT NULL,
        CreatedByUserId INT            NULL,
        CreatedByEmail  NVARCHAR(100)  NULL,
        CreatedDate     DATETIME2(3)   NOT NULL
            CONSTRAINT DF_OrderNote_CreatedDate DEFAULT (SYSUTCDATETIME()),
        IsDeleted       BIT            NOT NULL
            CONSTRAINT DF_OrderNote_IsDeleted DEFAULT (0),
        DeletedDate     DATETIME2(3)   NULL,
        DeletedByUserId INT            NULL,

        CONSTRAINT PK_OrderNote PRIMARY KEY CLUSTERED (OrderNoteId)
    );

    /* "the notes on this order, newest first" - the only question either screen asks */
    CREATE NONCLUSTERED INDEX IX_OrderNote_Order_Created
        ON dbo.OrderNote (OrderWorkPlanId, CreatedDate DESC)
        INCLUDE (NoteText, CreatedByEmail)
        WHERE IsDeleted = 0;
END
GO
