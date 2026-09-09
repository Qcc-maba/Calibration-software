/*
    dbo.DeleteOrderNote                                                                 MBA-907
    ---------------------------------------------------------------------------------------------
    Soft-deletes one note. Only its author may remove it - a coordinator cannot erase somebody
    else's account of what happened.

    Nothing is removed from the table, so a note that mattered can still be recovered.
*/
CREATE OR ALTER PROCEDURE dbo.DeleteOrderNote
    @LoggedInUserEmail NVARCHAR(100),
    @OrderNoteId       BIGINT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Email NVARCHAR(100) = LOWER(LTRIM(RTRIM(@LoggedInUserEmail)));

    IF NOT EXISTS (SELECT 1 FROM dbo.OrderNote
                   WHERE OrderNoteId = @OrderNoteId AND IsDeleted = 0)
        THROW 53011, 'No such note.', 1;

    IF NOT EXISTS (SELECT 1 FROM dbo.OrderNote
                   WHERE OrderNoteId = @OrderNoteId AND CreatedByEmail = @Email)
        THROW 53012, 'Only the author of a note may remove it.', 1;

    UPDATE dbo.OrderNote
    SET IsDeleted = 1,
        DeletedDate = SYSUTCDATETIME(),
        DeletedByUserId = (SELECT TOP (1) u.ID FROM dbo.Users u
                           WHERE LOWER(LTRIM(RTRIM(u.Email))) = @Email)
    WHERE OrderNoteId = @OrderNoteId;

    SELECT @OrderNoteId AS id;
END
