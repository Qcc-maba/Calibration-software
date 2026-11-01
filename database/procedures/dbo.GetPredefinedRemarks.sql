/*
    dbo.GetPredefinedRemarks                                                               MBA-848
    ---------------------------------------------------------------------------------------------
    The ready-made remarks for one picker: the order line's sub-domain (SecondaryCategoryId) and
    the picker's Scope - 'Report' for the report screen, 'Cycle' for a chamber cycle's dialog.
    Active rows only, in DisplayOrder. A sub-domain with no list (לחות, ללא מגע, ...) returns no rows.

    TextHEB / TextENG still carry their {1}, {2}, ... placeholders and DefaultValues their defaults
    (JSON array, "" = the calibrator must fill it); PlaceholderCount is the number of values a save
    needs. ExampleHEB / ExampleENG are the texts with the defaults filled in, for the picker to show.
*/
CREATE OR ALTER PROCEDURE dbo.GetPredefinedRemarks
    @SecondaryCategoryId INT,
    @Scope               NVARCHAR(10) = N'Report'
AS
BEGIN
    SET NOCOUNT ON;

    IF @Scope NOT IN (N'Report', N'Cycle')
        THROW 51000, 'Scope must be Report or Cycle.', 1;

    SELECT p.PredefinedRemarkId,
           p.SecondaryCategoryId,
           p.Scope,
           p.DisplayOrder,
           p.TextHEB,
           p.TextENG,
           p.DefaultValues,
           PlaceholderCount = ISNULL((SELECT COUNT(*) FROM OPENJSON(p.DefaultValues)), 0),
           ExampleHEB       = dbo.fnRenderRemarkTemplate(p.TextHEB, p.DefaultValues),
           ExampleENG       = dbo.fnRenderRemarkTemplate(p.TextENG, p.DefaultValues)
    FROM dbo.PredefinedRemarks AS p
    WHERE p.SecondaryCategoryId = @SecondaryCategoryId
      AND p.Scope = @Scope
      AND p.IsActive = 1
    ORDER BY p.DisplayOrder, p.PredefinedRemarkId;
END;
GO
