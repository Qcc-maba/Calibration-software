CREATE FUNCTION dbo.ParseCSVToTable
(
    @CSVString NVARCHAR(MAX)=N''
)
RETURNS @ParsedTable TABLE (Value NVARCHAR(MAX))
AS
BEGIN
    DECLARE @Pos INT, @NextPos INT, @Value NVARCHAR(MAX)
    SET @CSVString = LTRIM(RTRIM(@CSVString)) + ',' -- Ensure trailing comma
    SET @Pos = 1
    
    WHILE CHARINDEX(',', @CSVString, @Pos) > 0
    BEGIN
        SET @NextPos = CHARINDEX(',', @CSVString, @Pos)
        SET @Value = LTRIM(RTRIM(SUBSTRING(@CSVString, @Pos, @NextPos - @Pos)))
        
        INSERT INTO @ParsedTable (Value) VALUES (@Value)
        
        SET @Pos = @NextPos + 1
    END
    
    RETURN
END
