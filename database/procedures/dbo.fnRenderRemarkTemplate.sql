/*
    dbo.fnRenderRemarkTemplate                                                             MBA-848
    ---------------------------------------------------------------------------------------------
    Fills a predefined remark's {1}, {2}, ... with values: the same values go into the Hebrew and the
    English template, which is how the English follows a Hebrew remark whose numbers were changed
    (dbo.PredefinedRemarks has the background).

    @Template  TextHEB or TextENG of a dbo.PredefinedRemarks row.
    @Values    JSON array of strings; element 0 fills {1}. NULL or [] leaves the template as it is.

    A placeholder with no value is left in place, so the caller can tell (dbo.SaveCalibrationRemarks
    refuses to save one).
*/
CREATE OR ALTER FUNCTION dbo.fnRenderRemarkTemplate
(
    @Template NVARCHAR(MAX),
    @Values   NVARCHAR(MAX)
)
RETURNS NVARCHAR(MAX)
AS
BEGIN
    DECLARE @Result NVARCHAR(MAX) = @Template;

    IF @Template IS NULL OR @Values IS NULL OR ISJSON(@Values) = 0
        RETURN @Result;

    /* one REPLACE per value, in a loop: SQL Server does not guarantee the order of a
       SELECT @v = REPLACE(@v, ...) over several rows */
    DECLARE @i INT = 0, @Count INT = (SELECT COUNT(*) FROM OPENJSON(@Values));

    WHILE @i < @Count
    BEGIN
        SET @Result = REPLACE(@Result, CONCAT(N'{', @i + 1, N'}'),
                              ISNULL(JSON_VALUE(@Values, CONCAT(N'$[', @i, N']')), N''));
        SET @i += 1;
    END;

    RETURN @Result;
END;
GO
