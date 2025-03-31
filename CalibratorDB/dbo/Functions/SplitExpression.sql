CREATE FUNCTION [dbo].[SplitExpression] (@expression NVARCHAR(MAX))
RETURNS @Tokens TABLE (Token NVARCHAR(MAX), TokenNumber INT)
AS
BEGIN
    DECLARE @i INT = 1;
    DECLARE @token NVARCHAR(MAX) = '';
    DECLARE @currentChar NCHAR(1);
    DECLARE @insideParenthesis BIT = 0; -- flag to track if we are inside parentheses
    DECLARE @tokenNumber INT = 1;

    WHILE @i <= LEN(@expression)
    BEGIN
        SET @currentChar = SUBSTRING(@expression, @i, 1);

        -- Start of parentheses
        IF @currentChar = '('
        BEGIN
            IF @token <> '' AND @insideParenthesis = 0
            BEGIN
                INSERT INTO @Tokens (Token, TokenNumber) VALUES (@token, @tokenNumber);
                SET @tokenNumber = @tokenNumber + 1;
                SET @token = '';
            END
            SET @insideParenthesis = 1;
            SET @token = @token + @currentChar;
        END
        -- End of parentheses
        ELSE IF @currentChar = ')'
        BEGIN
            SET @token = @token + @currentChar;
            SET @insideParenthesis = 0;
            INSERT INTO @Tokens (Token, TokenNumber) VALUES (@token, @tokenNumber);
            SET @tokenNumber = @tokenNumber + 1;
            SET @token = '';
        END
        -- Operators (handled when not inside parentheses)
        ELSE IF @currentChar IN ('+', '-', '*', '/', '(', ')') AND @insideParenthesis = 0
        BEGIN
            IF @token <> ''
            BEGIN
                INSERT INTO @Tokens (Token, TokenNumber) VALUES (@token, @tokenNumber);
                SET @tokenNumber = @tokenNumber + 1;
                SET @token = '';
            END
            INSERT INTO @Tokens (Token, TokenNumber) VALUES (@currentChar, @tokenNumber);
            SET @tokenNumber = @tokenNumber + 1;
        END
        -- Accumulate characters (either inside or outside parentheses)
        ELSE
        BEGIN
            SET @token = @token + @currentChar;
        END

        SET @i = @i + 1;
    END

    -- Insert the last token if any
    IF @token <> '' 
        INSERT INTO @Tokens (Token, TokenNumber) VALUES (@token, @tokenNumber);

    RETURN;
END;
