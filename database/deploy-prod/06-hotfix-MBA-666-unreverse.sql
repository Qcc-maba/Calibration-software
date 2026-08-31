/*
    dbo.fnUnreverseVisualText
    ---------------------------------------------------------------------------------------------
    Priority stores text in VISUAL order. The Hebrew reads correctly, but every run of digits or
    Latin inside it is reversed: a 150 mm caliper is stored "זחון אלקטרוני עד 051", and a 100 kg
    scale as "מאזניים עד 001 ק'ג".

    This walks the string and reverses each LTR span in place, leaving the Hebrew alone. Brackets
    come out right on their own - ")3-1M(" reverses to "(M1-3)" - so they are NOT mirrored
    separately; doing both would flip them back.

    A SPACE BETWEEN TWO LTR RUNS IS INSIDE THE SPAN                             (fixed 31/08/2026)
    -----------------------------------------------------------------------------------------
    The first version treated a space exactly like a Hebrew character: it ended the run. So each
    word was reversed on its own and the WORD ORDER was left inverted. An English device name came
    out backwards and nobody could see it was wrong from any single word:

        stored   ALUMIS EGRAHCSID CITATSORTCELE
        was      SIMULA DISCHARGE ELECTROSTATIC
        now      ELECTROSTATIC DISCHARGE SIMULA

        stored   מפתח פיתול מתכוון MN 622-0
        was      מפתח פיתול מתכוון NM 0-226
        now      מפתח פיתול מתכוון 0-226 NM        <- the instrument is 0-226 Nm

    920 of the 2,995 device descriptions on STAGE change, 176 of them wholly-English names whose
    words were simply in reverse order. A space now ends the run only when what follows it is
    Hebrew or the end of the string.

    A RUN OF PURE PUNCTUATION IS A NEUTRAL, NOT AN LTR SPAN                     (fixed 31/08/2026)
    ---------------------------------------------------------------------------------------
    "בקר טמפ'+רגש" has no Latin and no digits at all, yet the apostrophe-plus between two Hebrew
    words was being treated as a run and reversed, giving "בקר טמפ+'רגש". 50 descriptions were
    damaged this way. A span that never gains a letter or a digit is now emitted untouched.

    A neutral between HEBREW and a NUMBER stays where it is. That is the Unicode bidi rule - a
    neutral between an RTL character and a European number takes the paragraph direction, which is
    RTL here - and the order-attachment cache proves it on real data:

        stored   רכש פריטים נלווים - 528691   ->   רכש פריטים נלווים - 196825

    An earlier version of this fix asked only whether EITHER side of the space carried a letter or
    a digit, which pulled that dash into the number and produced "רכש פריטים נלווים 196825 -" on
    447 attachment rows. The join test therefore requires BOTH sides to be strong.

    The cost of that strictness is "חוגן -/+ 200.0 2.0", where the "-/+" arguably belongs with the
    numbers. It is left alone - and it is 3 rows against 447, with no property of the stored text
    that separates the two cases. NeedsReview carries them.

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
    is the sentence punctuation, so nothing is peeled and the whole-run reversal stands. Better an
    unchanged oddity than a confidently wrong repair.

    What it still cannot recover, and callers must not assume it does:
      - the CASE of Latin letters. "MN 622-0" becomes "0-226 NM"; the instrument is 0-226 Nm.
        The reversal preserves characters, so whatever case Priority holds is what comes back.
      - the order of two LTR spans separated by HEBREW. Those are genuinely separate spans and
        their relative order is not recoverable from the stored text.
    dbo.CrmDeviceDescription.NeedsReview marks both cases.

    LEN() IS NOT USED TO MEASURE A RUN. LEN ignores trailing spaces, and a run may now END in one
    while it is being built. DATALENGTH/2 is the length that counts characters.
*/
CREATE OR ALTER FUNCTION dbo.fnUnreverseVisualText(@s NVARCHAR(400))
RETURNS NVARCHAR(400)
AS
BEGIN
    IF @s IS NULL RETURN NULL;

    DECLARE @out  NVARCHAR(400) = N'',
            @run  NVARCHAR(400) = N'',
            @tail NVARCHAR(400) = N'',
            @nxt  NVARCHAR(400) = N'',
            @gap  NVARCHAR(400) = N'',
            @i    INT = 1,
            @j    INT,
            @k    INT,
            @n    INT = DATALENGTH(@s) / 2,
            @c    NCHAR(1);

    /* Neutrals that trail an LTR run in logical order and are left in place by Priority.
       Deliberately excludes '.' ',' and brackets - see the header. */
    DECLARE @trailing NVARCHAR(10) = N':;!?';

    WHILE @i <= @n
    BEGIN
        SET @c = SUBSTRING(@s, @i, 1);

        IF UNICODE(@c) BETWEEN 1424 AND 1535        -- 0x0590..0x05FF is Hebrew
        BEGIN
            /* ---- flush ---- */
            SET @tail = N'';
            IF PATINDEX(N'%[A-Za-z0-9]%', @run COLLATE Latin1_General_BIN2) > 0
            BEGIN
                IF DATALENGTH(@run) > 0 AND CHARINDEX(LEFT(@run, 1), @trailing) = 0
                    WHILE DATALENGTH(@run) > 0 AND CHARINDEX(RIGHT(@run, 1), @trailing) > 0
                    BEGIN
                        SET @tail = RIGHT(@run, 1) + @tail;
                        SET @run  = LEFT(@run, DATALENGTH(@run) / 2 - 1);
                    END
                SET @run = REVERSE(@run);
            END
            SET @out = @out + @run + @tail + @c;
            SET @run = N'';
            SET @i += 1;
        END
        ELSE IF @c = N' '
        BEGIN
            /* how far the spaces go, and what the next run looks like */
            SET @j = @i;
            WHILE @j <= @n AND SUBSTRING(@s, @j, 1) = N' ' SET @j += 1;
            SET @k = @j;
            WHILE @k <= @n
              AND SUBSTRING(@s, @k, 1) <> N' '
              AND NOT (UNICODE(SUBSTRING(@s, @k, 1)) BETWEEN 1424 AND 1535) SET @k += 1;
            SET @gap = SUBSTRING(@s, @i, @j - @i);
            SET @nxt = SUBSTRING(@s, @j, @k - @j);

            /*  The space is INSIDE the span only when the runs on BOTH sides carry a letter or a
                digit. Accepting either side drags a Hebrew-context dash into the number beside it
                - see the header; it damaged 447 attachment rows. */
            IF PATINDEX(N'%[A-Za-z0-9]%', @run COLLATE Latin1_General_BIN2) > 0
               AND PATINDEX(N'%[A-Za-z0-9]%', @nxt COLLATE Latin1_General_BIN2) > 0
            BEGIN
                SET @run = @run + @gap;
            END
            ELSE
            BEGIN
                /* ---- flush ---- */
                SET @tail = N'';
                IF PATINDEX(N'%[A-Za-z0-9]%', @run COLLATE Latin1_General_BIN2) > 0
                BEGIN
                    IF DATALENGTH(@run) > 0 AND CHARINDEX(LEFT(@run, 1), @trailing) = 0
                        WHILE DATALENGTH(@run) > 0 AND CHARINDEX(RIGHT(@run, 1), @trailing) > 0
                        BEGIN
                            SET @tail = RIGHT(@run, 1) + @tail;
                            SET @run  = LEFT(@run, DATALENGTH(@run) / 2 - 1);
                        END
                    SET @run = REVERSE(@run);
                END
                SET @out = @out + @run + @tail + @gap;
                SET @run = N'';
            END
            SET @i = @j;
        END
        ELSE
        BEGIN
            SET @run = @run + @c;
            SET @i += 1;
        END
    END

    /* ---- flush whatever ends the string ---- */
    SET @tail = N'';
    IF PATINDEX(N'%[A-Za-z0-9]%', @run COLLATE Latin1_General_BIN2) > 0
    BEGIN
        IF DATALENGTH(@run) > 0 AND CHARINDEX(LEFT(@run, 1), @trailing) = 0
            WHILE DATALENGTH(@run) > 0 AND CHARINDEX(RIGHT(@run, 1), @trailing) > 0
            BEGIN
                SET @tail = RIGHT(@run, 1) + @tail;
                SET @run  = LEFT(@run, DATALENGTH(@run) / 2 - 1);
            END
        SET @run = REVERSE(@run);
    END

    RETURN @out + @run + @tail;
END
