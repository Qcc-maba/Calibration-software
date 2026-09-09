/*
    dbo.GetOrderNotes                                                                   MBA-907
    ---------------------------------------------------------------------------------------------
    The notes written on an order, newest first, for the הערות popup on the coordinator and
    validator screens.

    Author name falls back to the e-mail: a note written by somebody who has since left, or by an
    address that never matched a Users row, still has to say who wrote it.

    camelCase output, the convention the other screen procedures use.
*/
CREATE OR ALTER PROCEDURE dbo.GetOrderNotes
    @OrderWorkPlanId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT n.OrderNoteId                                   AS id,
           n.OrderWorkPlanId                               AS orderId,
           n.NoteText                                      AS note,
           n.CreatedByEmail                                AS authorEmail,
           COALESCE(u.FirstName + N' ' + u.LastName, n.CreatedByEmail) AS authorName,
           CONVERT(VARCHAR(16), n.CreatedDate, 120)        AS createdAt
    FROM dbo.OrderNote AS n
    LEFT JOIN dbo.Users AS u ON u.ID = n.CreatedByUserId
    WHERE n.OrderWorkPlanId = @OrderWorkPlanId
      AND n.IsDeleted = 0
    ORDER BY n.CreatedDate DESC, n.OrderNoteId DESC;
END
