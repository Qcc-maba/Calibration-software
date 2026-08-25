/*
    dbo.AddOrderNote                                                                    MBA-907
    ---------------------------------------------------------------------------------------------
    Adds one note to an order. Append-only: there is no edit, because a note is a record of what
    somebody thought at a moment and rewriting it destroys that. Correcting a note means writing
    another one; removing it means dbo.DeleteOrderNote, which soft-deletes.

    The order must exist and must not be cancelled - a note on a cancelled order would never be
    read by anyone.

    Blank text is refused rather than stored. An empty note is the kind of thing that fills a column
    with rows nobody can act on, and the screen already has to handle "no notes yet".

    Returns the new note as the list procedure would render it, so the caller can prepend it without
    a second round trip.
*/
CREATE OR ALTER PROCEDURE dbo.AddOrderNote
    @LoggedInUserEmail NVARCHAR(100),
    @OrderWorkPlanId   INT,
    @NoteText          NVARCHAR(2000)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Text NVARCHAR(2000) = NULLIF(LTRIM(RTRIM(@NoteText)), N'');

    IF @Text IS NULL
        THROW 53001, 'A note cannot be empty.', 1;

    IF NOT EXISTS (SELECT 1 FROM dbo.OrderWorkPlans
                   WHERE OrderWorkPlanId = @OrderWorkPlanId AND IsCancelled = 0)
        THROW 53002, 'No such order, or the order is cancelled.', 1;

    DECLARE @UserId INT;
    SELECT TOP (1) @UserId = u.ID FROM dbo.Users AS u
    WHERE LOWER(LTRIM(RTRIM(u.Email))) = LOWER(LTRIM(RTRIM(@LoggedInUserEmail)));

    INSERT INTO dbo.OrderNote (OrderWorkPlanId, NoteText, CreatedByUserId, CreatedByEmail)
    VALUES (@OrderWorkPlanId, @Text, @UserId, LOWER(LTRIM(RTRIM(@LoggedInUserEmail))));

    DECLARE @NoteId BIGINT = CAST(SCOPE_IDENTITY() AS BIGINT);

    SELECT n.OrderNoteId                                   AS id,
           n.OrderWorkPlanId                               AS orderId,
           n.NoteText                                      AS note,
           n.CreatedByEmail                                AS authorEmail,
           COALESCE(u.FirstName + N' ' + u.LastName, n.CreatedByEmail) AS authorName,
           CONVERT(VARCHAR(16), n.CreatedDate, 120)        AS createdAt
    FROM dbo.OrderNote AS n
    LEFT JOIN dbo.Users AS u ON u.ID = n.CreatedByUserId
    WHERE n.OrderNoteId = @NoteId;
END
