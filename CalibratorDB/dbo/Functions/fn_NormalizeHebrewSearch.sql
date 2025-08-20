CREATE   FUNCTION [dbo].[fn_NormalizeHebrewSearch]
(
    @txt NVARCHAR(4000)
)
RETURNS NVARCHAR(4000)
AS
BEGIN
    DECLARE @result NVARCHAR(4000);

    -- If string contains ONLY Hebrew block chars (U+0590–U+05FF) → reverse
    IF @txt NOT LIKE N'%[^א-ת\u0590-\u05FF]%'
        SET @result = REVERSE(@txt);
    ELSE
        SET @result = @txt;

    RETURN @result;
END;