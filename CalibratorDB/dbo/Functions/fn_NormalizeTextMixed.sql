CREATE FUNCTION dbo.fn_NormalizeTextMixed (@txt NVARCHAR(MAX))
RETURNS NVARCHAR(MAX)
AS
BEGIN
    DECLARE @result NVARCHAR(MAX) = N'';
    DECLARE @token NVARCHAR(4000);
    DECLARE @pos INT = 1;
    DECLARE @len INT = LEN(@txt);
    DECLARE @ch NCHAR(1);
    DECLARE @buffer NVARCHAR(4000) = N'';
    DECLARE @isLatin BIT = 0;

    WHILE @pos <= @len
    BEGIN
        SET @ch = SUBSTRING(@txt, @pos, 1);

        -- Detect if character is Latin (A-Z / a-z / digits / punctuation)
        IF UNICODE(@ch) BETWEEN 32 AND 126
        BEGIN
            IF @isLatin = 0
            BEGIN
                -- Flush Hebrew buffer
                SET @result += @buffer;
                SET @buffer = N'';
                SET @isLatin = 1;
            END
            SET @buffer += @ch;
        END
        ELSE
        BEGIN
            IF @isLatin = 1
            BEGIN
                -- Flush Latin buffer reversed
                SET @result += REVERSE(@buffer);
                SET @buffer = N'';
                SET @isLatin = 0;
            END
            SET @buffer += @ch;
        END

        SET @pos += 1;
    END

    -- Flush last buffer
    IF @isLatin = 1
        SET @result += REVERSE(@buffer);
    ELSE
        SET @result += @buffer;

    RETURN LTRIM(RTRIM(@result));
END