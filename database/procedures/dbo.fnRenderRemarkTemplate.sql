/*
    dbo.fnRenderRemarkTemplate                                                             MBA-848
    ---------------------------------------------------------------------------------------------
    Fills a predefined remark's {1}, {2}, ... with values: the same values go into the Hebrew and the
    English template, which is how the English follows a Hebrew remark whose numbers were changed
    (dbo.PredefinedRemarks has the background).

    @Template  TextHEB or TextENG of a dbo.PredefinedRemarks row.
    @Values    JSON array of strings; element 0 fills {1}. NULL or [] leaves the template as it is.

    A placeholder is left in place only when the array has no element for it. An element that is ""
    (the default for a value the calibrator must type) fills it with nothing, so a picker preview
    reads "Sensor No.  positioned..." - dbo.SaveCalibrationRemarks refuses to save an empty value.

    One pass, left to right: a value is never read again, so a value that itself contains "{2}" is
    printed as typed.
*/
CREATE OR ALTER FUNCTION dbo.fnRenderRemarkTemplate
(
    @Template NVARCHAR(MAX),
    @Values   NVARCHAR(MAX)
)
RETURNS NVARCHAR(MAX)
AS
BEGIN
    IF @Template IS NULL OR @Values IS NULL OR ISJSON(@Values) = 0
        RETURN @Template;

    DECLARE @Result NVARCHAR(MAX) = N'',
            @Count  INT = (SELECT COUNT(*) FROM OPENJSON(@Values)),
            @Pos    INT = 1,
            @Open   INT,
            @Close  INT,
            @Number NVARCHAR(10);

    WHILE 1 = 1
    BEGIN
        SET @Open = CHARINDEX(N'{', @Template, @Pos);
        IF @Open = 0 BREAK;

        SET @Close  = CHARINDEX(N'}', @Template, @Open);
        SET @Number = CASE WHEN @Close > @Open + 1 AND @Close - @Open <= 4
                           THEN SUBSTRING(@Template, @Open + 1, @Close - @Open - 1) END;

        /* TRY_CAST: the parts of an AND may run in any order, so a plain CAST could meet "{ab}" */
        IF @Number IS NOT NULL AND @Number NOT LIKE N'%[^0-9]%'
           AND TRY_CAST(@Number AS INT) BETWEEN 1 AND @Count
        BEGIN
            SET @Result += SUBSTRING(@Template, @Pos, @Open - @Pos)
                         + ISNULL(JSON_VALUE(@Values, CONCAT(N'$[', CAST(@Number AS INT) - 1, N']')), N'');
            SET @Pos = @Close + 1;
        END
        ELSE
        BEGIN
            /* not a placeholder we have a value for: keep the "{" and look further on */
            SET @Result += SUBSTRING(@Template, @Pos, @Open - @Pos + 1);
            SET @Pos = @Open + 1;
        END;
    END;

    RETURN @Result + SUBSTRING(@Template, @Pos, LEN(@Template + N'x') - @Pos + 1);
END;
GO
