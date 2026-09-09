/*
    ClientConfirmationStatus — add the 'New' (חדש) status.

    The category (StatusesCategories.StatusDescriptionENG = 'ClientConfirmationStatus') held three
    statuses: Pending / Confirmed / Rejected. 'New' is the state an order is in before anyone asked
    the customer anything:

        New (חדש)  --coordinator sends the coordination e-mail-->  Pending (ממתין)
                                       customer clicks אישור  -->  Confirmed (מאושר)
                                       customer clicks דחייה  -->  Rejected (נדחה)

    Idempotent: re-running does nothing. StatusId is IDENTITY, so the new id is assigned by the
    server — never hard-code it. The ids already differ between environments (STAGE has
    Pending/Confirmed/Rejected as 89/90/91, PROD as 88/89/90), which is exactly why application
    code must resolve them through dbo.GetStatusByCategory.

    ENCODING: this file must be saved as UTF-8 with BOM. It was previously stored in a codepage
    that mangled every Hebrew string ("׳—׳“׳©" instead of "חדש"); running that version would have
    inserted mojibake into a column users read.

    Run this BEFORE pointing GetWorkPlanData's fallback status at 'New'.
*/
DECLARE @CategoryId INT =
(
    SELECT StatusCategoryId
    FROM dbo.StatusesCategories
    WHERE StatusDescriptionENG = N'ClientConfirmationStatus'
);

IF @CategoryId IS NULL
    THROW 51000, 'StatusesCategories row for ''ClientConfirmationStatus'' is missing.', 1;

IF NOT EXISTS (SELECT 1
               FROM dbo.Statuses
               WHERE StatusCategoryId = @CategoryId
                 AND StatusDescriptionENG = N'New')
BEGIN
    INSERT dbo.Statuses (StatusCategoryId, Code, StatusDescriptionENG, StatusDescriptionHEB)
    VALUES (@CategoryId, N'', N'New', N'חדש');
END
GO