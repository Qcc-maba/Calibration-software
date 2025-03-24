CREATE FUNCTION [dbo].[SplitExpressionCols] (@expression NVARCHAR(MAX))
RETURNS TABLE
AS
   
RETURN (    
	WITH Tokenized AS
	(
		SELECT Token, TokenNumber
		FROM dbo.SplitExpression(@expression)
	)
	SELECT
		MAX(CASE WHEN TokenNumber = 1 THEN Token END) AS Token1,
		MAX(CASE WHEN TokenNumber = 2 THEN Token END) AS Token2,
		MAX(CASE WHEN TokenNumber = 3 THEN Token END) AS Token3,
		MAX(CASE WHEN TokenNumber = 4 THEN Token END) AS Token4,
		MAX(CASE WHEN TokenNumber = 5 THEN Token END) AS Token5
	FROM Tokenized
)
