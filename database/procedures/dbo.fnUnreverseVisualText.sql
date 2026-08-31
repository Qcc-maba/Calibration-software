/*
    dbo.fnUnreverseVisualText
    ---------------------------------------------------------------------------------------------
    Priority stores text in VISUAL order. The Hebrew reads correctly, but every run of digits or
    Latin inside it is reversed: a 150 mm caliper is stored "זחון אלקטרוני עד 051", and a 100 kg
    scale as "מאזניים עד 001 ק'ג".

    This walks the string and reverses each non-Hebrew run in place, leaving the Hebrew alone.
    Brackets come out right on their own - ")3-1M(" reverses to "(M1-3)" - so they are NOT mirrored
    separately; doing both would flip them back.

    TRAILING SENTENCE PUNCTUATION IS NOT PART OF THE RUN                        (fixed 31/08/2026)
    ------------------------------------------------------------------------------------------
    Priority reverses only the strong LTR characters and leaves a neutral like ':' where it is.
    Verified by code point, not by looking at a terminal - a terminal re-orders bidi text and will
    lie to you about what is stored. The subject "RE: הצעת מחיר A26004904" is stored as:

        E(69) R(82) :(58) space  ה צ ע ת  space  מ ח י ר  space  4 0 9 4 0 0 6 2 A

    so the letters are reversed, "RE" -> "ER", while the colon stays at the end. Reversing the
    whole run produced ":RE". The run is now split: a tail of :;!? is peeled off, the core is
    reversed, and the tail is put back unchanged.

    THREE characters are deliberately NOT in that set, each for its own reason:

      '.' and ','  are numeric separators here far more often than sentence punctuation. 24 device
                   descriptions store a leading decimal fraction such as ".0005" as "'5000." -
                   the period has to travel with the reversal to land back in front. Peeling it
                   produced "0005'." Measured on STAGE before shipping; this is why the set is
                   narrow.

      brackets     a mirrored pair has to travel with the reversal. Reversing ")3-1M(" is what
                   turns it back into "(M1-3)"; peeling would break what already worked.

    A ':' inside a run - a time like "10:30" - is untouched, because only a TRAILING run of these
    characters is peeled.

    AMBIGUOUS RUNS ARE LEFT ALONE. Priority does not place the neutral consistently: "RE:" is
    stored "ER:" with the colon last, but "FW:" is stored ":WF" with it first, because the bidi
    algorithm resolves a neutral from whatever surrounds it. When a run carries one of these
    characters at BOTH ends - ":dwF:" from a forwarded chain - there is no way to tell which end
    is the sentence punctuation, so nothing is peeled and the previous whole-run reversal stands.
    Better an unchanged oddity than a confidently wrong repair.

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

    DECLARE @out  NVARCHAR(400) = N'',
            @run  NVARCHAR(400) = N'',
            @tail NVARCHAR(400) = N'',
            @i    INT = 1,
            @n    INT = LEN(@s),
            @c    NCHAR(1);

    /* Neutrals that trail an LTR run in logical order and are left in place by Priority.
       Deliberately excludes '.' ',' and brackets - see the header. */
    DECLARE @trailing NVARCHAR(10) = N':;!?';

    WHILE @i <= @n
    BEGIN
        SET @c = SUBSTRING(@s, @i, 1);
        IF (UNICODE(@c) BETWEEN 1424 AND 1535) OR @c = N' '   -- 0x0590..0x05FF is Hebrew
        BEGIN
            SET @tail = N'';
            /* Only peel when the run does not ALSO start with one of these - see the header. */
            IF LEN(@run) > 0 AND CHARINDEX(LEFT(@run, 1), @trailing) = 0
                WHILE LEN(@run) > 0 AND CHARINDEX(RIGHT(@run, 1), @trailing) > 0
                BEGIN
                    SET @tail = RIGHT(@run, 1) + @tail;
                    SET @run  = LEFT(@run, LEN(@run) - 1);
                END

            SET @out = @out + REVERSE(@run) + @tail + @c;
            SET @run = N'';
        END
        ELSE
            SET @run = @run + @c;
        SET @i += 1;
    END

    /* Same peel for a run that ends the string. */
    SET @tail = N'';
    IF LEN(@run) > 0 AND CHARINDEX(LEFT(@run, 1), @trailing) = 0
        WHILE LEN(@run) > 0 AND CHARINDEX(RIGHT(@run, 1), @trailing) > 0
        BEGIN
            SET @tail = RIGHT(@run, 1) + @tail;
            SET @run  = LEFT(@run, LEN(@run) - 1);
        END

    RETURN @out + REVERSE(@run) + @tail;
END
