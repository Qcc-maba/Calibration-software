/*
    dbo.fnUnreverseVisualText
    ---------------------------------------------------------------------------------------------
    Priority stores text in VISUAL order. The Hebrew reads correctly, but every run of digits or
    Latin inside it is reversed: a 150 mm caliper is stored "זחון אלקטרוני עד 051", and a 100 kg
    scale as "מאזניים עד 001 ק'ג".

    This walks the string and reverses each non-Hebrew run in place, leaving the Hebrew alone.
    Brackets come out right on their own - ")3-1M(" reverses to "(M1-3)" - so they are NOT mirrored
    separately; doing both would flip them back.

    What it cannot recover, and callers must not assume it does:
      - the case of Latin letters. "MN 622-0" becomes "NM 0-226"; the instrument is 0-226 Nm.
      - the order of several runs separated by Hebrew or spaces.
    dbo.CrmDeviceDescription.NeedsReview marks both cases.
*/
CREATE OR ALTER FUNCTION dbo.fnUnreverseVisualText(@s NVARCHAR(400))
RETURNS NVARCHAR(400)
AS
BEGIN
    IF @s IS NULL RETURN NULL;

    DECLARE @out NVARCHAR(400) = N'',
            @run NVARCHAR(400) = N'',
            @i   INT = 1,
            @n   INT = LEN(@s),
            @c   NCHAR(1);

    WHILE @i <= @n
    BEGIN
        SET @c = SUBSTRING(@s, @i, 1);
        IF (UNICODE(@c) BETWEEN 1424 AND 1535) OR @c = N' '   -- 0x0590..0x05FF is Hebrew
        BEGIN
            SET @out = @out + REVERSE(@run) + @c;
            SET @run = N'';
        END
        ELSE
            SET @run = @run + @c;
        SET @i += 1;
    END

    RETURN @out + REVERSE(@run);
END
