-- =============================================
-- Func:        dbo.fnStripHtml
-- Jira:        MBA-792 / MBA-806
-- Description: Turns the CRM's Word-exported HTML into readable single-line plain text, so a
--              coordinator sees "כיול מבוצע ע\"י לרית / לרית צריכים להגיע עם 1000 ק\"ג" in a table
--              cell instead of "<P dir=rtl><SPAN lang=HE style='FONT-SIZE...".
--
-- Deliberately used at CACHE-FILL time (dbo.RefreshCrmTextCache), not inside a list query: this is
-- a scalar UDF with a WHILE loop, so it is fine over ~1,000 rows once and a bad idea per request.
--
-- Order matters: the <style> block goes first (it is CSS, not content), then block-level tags
-- become separators so two sentences do not weld into one, then all remaining tags are stripped,
-- then entities are decoded, then whitespace is collapsed.
-- =============================================
CREATE OR ALTER FUNCTION dbo.fnStripHtml (@html NVARCHAR(MAX))
RETURNS NVARCHAR(MAX)
WITH SCHEMABINDING
AS
BEGIN
    IF @html IS NULL RETURN NULL;

    DECLARE @s NVARCHAR(MAX) = @html;
    DECLARE @i INT, @j INT;

    -- 1. drop the CSS block entirely
    SET @i = CHARINDEX('<style', @s);
    WHILE @i > 0
    BEGIN
        SET @j = CHARINDEX('</style>', @s, @i);
        IF @j = 0 BREAK;
        SET @s = STUFF(@s, @i, @j + 8 - @i, N'');
        SET @i = CHARINDEX('<style', @s);
    END

    -- 2. block-level tags become separators, so lines stay distinguishable
    SET @s = REPLACE(@s, N'<BR>',  N' | ');
    SET @s = REPLACE(@s, N'<br>',  N' | ');
    SET @s = REPLACE(@s, N'<BR/>', N' | ');
    SET @s = REPLACE(@s, N'</P>',  N' | ');
    SET @s = REPLACE(@s, N'</p>',  N' | ');
    SET @s = REPLACE(@s, N'</DIV>', N' | ');
    SET @s = REPLACE(@s, N'</div>', N' | ');
    SET @s = REPLACE(@s, N'</LI>', N' | ');
    SET @s = REPLACE(@s, N'</TR>', N' | ');
    SET @s = REPLACE(@s, N'</tr>', N' | ');

    -- 3. strip every remaining tag, leaving a SPACE behind rather than nothing.
    --    Priority breaks its text mid-sentence across TEXTLINE rows, and the reconstruction joins
    --    them with no delimiter, so removing a tag outright welds words together
    --    ("חייב להיות עד27/08/26"). The space is collapsed again in step 5.
    SET @i = CHARINDEX('<', @s);
    WHILE @i > 0
    BEGIN
        SET @j = CHARINDEX('>', @s, @i);
        IF @j = 0 BREAK;                      -- a stray '<' with no closing '>' — leave it alone
        SET @s = STUFF(@s, @i, @j - @i + 1, N' ');
        SET @i = CHARINDEX('<', @s);
    END

    -- 4. entities
    SET @s = REPLACE(@s, N'&nbsp;', N' ');
    SET @s = REPLACE(@s, N'&amp;',  N'&');
    SET @s = REPLACE(@s, N'&quot;', N'"');
    SET @s = REPLACE(@s, N'&#39;',  N'''');
    SET @s = REPLACE(@s, N'&lt;',   N'<');
    SET @s = REPLACE(@s, N'&gt;',   N'>');

    -- 5. collapse whitespace and tidy the separators
    SET @s = REPLACE(REPLACE(REPLACE(@s, CHAR(13), N' '), CHAR(10), N' '), CHAR(9), N' ');
    WHILE CHARINDEX(N'  ', @s) > 0 SET @s = REPLACE(@s, N'  ', N' ');
    WHILE CHARINDEX(N'| |', @s) > 0 SET @s = REPLACE(@s, N'| |', N'|');
    SET @s = LTRIM(RTRIM(@s));
    WHILE LEN(@s) > 0 AND RIGHT(@s, 1) IN (N'|', N' ') SET @s = LTRIM(RTRIM(LEFT(@s, LEN(@s) - 1)));
    WHILE LEN(@s) > 0 AND LEFT(@s, 1) IN (N'|', N' ') SET @s = LTRIM(RTRIM(RIGHT(@s, LEN(@s) - 1)));

    RETURN NULLIF(@s, N'');
END
GO
