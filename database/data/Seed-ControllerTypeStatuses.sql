/*
    Seed-ControllerTypeStatuses                                                            MBA-980
    ---------------------------------------------------------------------------------------------
    The Summary screen's Controller choice - Digital or Analog - as a status category, like the
    cycle types (CalibrationCycleName): one dbo.StatusesCategories row 'ControllerType' and two
    dbo.Statuses rows, Code 'Digital' and 'Analog', each with its English and Hebrew label (the
    Hebrew labels are the app's existing translations of "digital" and "analog").
    dbo.CalibrationCycles.ControllerTypeStatusId points to one of them, and the app fills the
    dropdown with dbo.GetStatusByCategory @StatusDescriptionENG = N'ControllerType'.

    The ids are IDENTITY and are not the same on STAGE and PROD, so nothing may hard-code them;
    rows are matched by category name and Code.

    ENCODING: this file holds Hebrew literals and must stay UTF-8 with BOM. Run it with a client
    that reads it as UTF-8 (Invoke-CalibratorStageSqlFile.ps1 does; sqlcmd needs -f 65001). After
    inserting, the script reads the labels back and fails if they are not exactly the expected text,
    so a mangled run cannot pass silently.

    Stops, changing nothing, when an existing row has a different label ('Differs'): fix that row by
    hand first, after finding out who changed it.

    Run BEFORE the app offers the dropdown. Idempotent: a second run inserts nothing.

    @Apply = 0 (default) reports; @Apply = 1 inserts.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @Apply BIT = 0;

DECLARE @Seed TABLE (Code NVARCHAR(255) NOT NULL, StatusDescriptionENG NVARCHAR(255) NOT NULL,
                     StatusDescriptionHEB NVARCHAR(255) NOT NULL, SortOrder INT NOT NULL);
INSERT @Seed VALUES (N'Digital', N'Digital', N'דיגיטלי', 1),
                    (N'Analog',  N'Analog',  N'אנלוגי', 2);
DECLARE @CategoryHEB NVARCHAR(255) = N'סוג בקר';

/* The Hebrew must arrive intact, or everything below compares against mangled text. The
   NCHAR codes are U+05D3 (dalet) and U+05D0 (alef), the first letters of the two labels. */
IF (SELECT LEFT(StatusDescriptionHEB, 1) FROM @Seed WHERE Code = N'Digital') <> NCHAR(0x05D3)
   OR (SELECT LEFT(StatusDescriptionHEB, 1) FROM @Seed WHERE Code = N'Analog') <> NCHAR(0x05D0)
    THROW 51000, 'Stopped, nothing changed: the Hebrew labels were not read as UTF-8 (run with -f 65001).', 1;

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

IF EXISTS (SELECT 1 FROM @Plan WHERE Action = N'Differs')
BEGIN
    DECLARE @Differs NVARCHAR(400) = (SELECT STRING_AGG(Code, N', ') FROM @Plan WHERE Action = N'Differs');
    DECLARE @Msg NVARCHAR(500) = CONCAT(N'Stopped, nothing changed: existing ControllerType status with a different label: ', @Differs);
    THROW 51000, @Msg, 1;
END;

IF @Apply = 1
BEGIN
    BEGIN TRANSACTION;

    IF @CategoryId IS NULL
    BEGIN
        INSERT dbo.StatusesCategories (StatusDescriptionENG, StatusDescriptionHEB)
        VALUES (N'ControllerType', @CategoryHEB);
        SET @CategoryId = SCOPE_IDENTITY();
    END;

    INSERT dbo.Statuses (StatusCategoryId, Code, StatusDescriptionENG, StatusDescriptionHEB)
    SELECT @CategoryId, Code, StatusDescriptionENG, StatusDescriptionHEB
    FROM @Plan
    WHERE Action = N'Insert'
    ORDER BY SortOrder;

    /* Read back: every seed row must now be stored with exactly the expected labels. */
    IF (SELECT COUNT(*) FROM @Seed AS x
        JOIN dbo.Statuses AS s ON s.StatusCategoryId = @CategoryId AND s.Code = x.Code
        WHERE s.StatusDescriptionENG = x.StatusDescriptionENG COLLATE Latin1_General_100_BIN2
          AND s.StatusDescriptionHEB = x.StatusDescriptionHEB COLLATE Latin1_General_100_BIN2) <> (SELECT COUNT(*) FROM @Seed)
        THROW 51000, 'Rolled back: the stored ControllerType labels are not the expected text.', 1;

    COMMIT TRANSACTION;
END;

SELECT Applied = @Apply,
       Category = CASE WHEN @CategoryId IS NULL THEN N'would be created' ELSE CONCAT(N'id ', @CategoryId) END,
       p.Action, p.Code, p.StatusDescriptionENG, p.StatusDescriptionHEB,
       StatusId = s.StatusId,
       StoredHEB = s.StatusDescriptionHEB
FROM @Plan AS p
LEFT JOIN dbo.Statuses AS s ON s.StatusCategoryId = @CategoryId AND s.Code = p.Code
ORDER BY p.SortOrder;
GO
