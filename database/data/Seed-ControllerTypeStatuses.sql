/*
    Seed-ControllerTypeStatuses                                                            MBA-980
    ---------------------------------------------------------------------------------------------
    The Summary screen's Controller choice - Digital or Analog - as a status category, like the
    cycle types (CalibrationCycleName): one dbo.StatusesCategories row 'ControllerType' and two
    dbo.Statuses rows. dbo.CalibrationCycles.ControllerTypeStatusId points to one of them, and the
    app fills the dropdown with dbo.GetStatusByCategory @StatusDescriptionENG = N'ControllerType',
    which also gives it the Hebrew and English labels.

        Code      English   Hebrew
        Digital   Digital   דיגיטלי
        Analog    Analog    אנלוגי

    The ids are IDENTITY and are not the same on STAGE and PROD, so nothing may hard-code them;
    rows are matched by category name and Code.

    Run BEFORE database/constraints/FK_CalibrationCycles_ControllerTypeStatusId.sql is relied on,
    and before the app offers the dropdown. Idempotent: a second run inserts nothing.

    @Apply = 0 (default) reports; @Apply = 1 inserts.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @Apply BIT = 0;

DECLARE @Seed TABLE (Code NVARCHAR(255) NOT NULL, StatusDescriptionENG NVARCHAR(255) NOT NULL,
                     StatusDescriptionHEB NVARCHAR(255) NOT NULL, SortOrder INT NOT NULL);
INSERT @Seed VALUES (N'Digital', N'Digital', N'דיגיטלי', 1),
                    (N'Analog',  N'Analog',  N'אנלוגי', 2);

DECLARE @CategoryId INT = (SELECT StatusCategoryId FROM dbo.StatusesCategories
                           WHERE StatusDescriptionENG = N'ControllerType');

DECLARE @Plan TABLE (Action NVARCHAR(10), Code NVARCHAR(255), StatusDescriptionENG NVARCHAR(255),
                     StatusDescriptionHEB NVARCHAR(255), SortOrder INT);

INSERT @Plan
SELECT Action = CASE WHEN s.StatusId IS NULL THEN N'Insert'
                     WHEN s.StatusDescriptionENG = x.StatusDescriptionENG COLLATE Latin1_General_100_BIN2
                      AND s.StatusDescriptionHEB = x.StatusDescriptionHEB COLLATE Latin1_General_100_BIN2
                     THEN N'Same' ELSE N'Differs' END,
       x.Code, x.StatusDescriptionENG, x.StatusDescriptionHEB, x.SortOrder
FROM @Seed AS x
LEFT JOIN dbo.Statuses AS s ON s.StatusCategoryId = @CategoryId AND s.Code = x.Code;

IF @Apply = 1
BEGIN
    BEGIN TRANSACTION;

    IF @CategoryId IS NULL
    BEGIN
        INSERT dbo.StatusesCategories (StatusDescriptionENG, StatusDescriptionHEB)
        VALUES (N'ControllerType', N'סוג בקר');
        SET @CategoryId = SCOPE_IDENTITY();
    END;

    INSERT dbo.Statuses (StatusCategoryId, Code, StatusDescriptionENG, StatusDescriptionHEB)
    SELECT @CategoryId, Code, StatusDescriptionENG, StatusDescriptionHEB
    FROM @Plan
    WHERE Action = N'Insert'
    ORDER BY SortOrder;

    COMMIT TRANSACTION;
END;

SELECT Applied = @Apply,
       Category = CASE WHEN @CategoryId IS NULL THEN N'would be created' ELSE CONCAT(N'id ', @CategoryId) END,
       p.Action, p.Code, p.StatusDescriptionENG, p.StatusDescriptionHEB,
       StatusId = s.StatusId
FROM @Plan AS p
LEFT JOIN dbo.Statuses AS s ON s.StatusCategoryId = @CategoryId AND s.Code = p.Code
ORDER BY p.SortOrder;
GO
