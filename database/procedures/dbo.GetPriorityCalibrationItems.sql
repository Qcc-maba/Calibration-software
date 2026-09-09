/*
    dbo.GetPriorityCalibrationItems                                                    MBA-666
    -------------------------------------------------------------------------------------------
    The Calibration Item list, taken from the device definition in Priority rather than from a
    hard-coded list, so the calibrator sees the same description the logistics system holds.

    Priority models this as PART -> FAMILY: every catalogue part belongs to a family, and the
    family is the device description ("תיאור מכשיר") - Chamber, מד לחות, and so on. The list is
    therefore the set of families that actually have parts; families with none are catalogue
    scaffolding and would only clutter the dropdown.

    Pass @Part to also mark which family that specific part belongs to, so the screen can preselect
    the device's own item instead of making the calibrator find it.

    Why OPENQUERY: a four-part-name join makes SQL Server drag the whole remote table across and
    filter locally. Pushing the work to the remote server is the difference between seconds and
    milliseconds - the same reason dbo.GetPriorityContactsByEmail is written this way. RPC OUT is
    disabled on the linked server, so parameters cannot be passed with EXEC ... AT and @Part is
    embedded in the query text; it is an integer, and validated as one before use.

    ---------------------------------------------------------------------------------------------
    KNOWN TRAP - reversed text. Priority stores some text columns character-reversed: FAMILYDES for
    part family RICELAKE reads "EKALECIR". The same quirk bites ORDERSTEXT (see
    dbo.GetOrderInstructionsByOrder, which rebuilds those with REVERSE).

    This procedure returns BOTH the raw value and a reversed one rather than guessing, because it
    is not yet confirmed whether the reversal applies to every row or only some. Decide from real
    data which column the UI should bind to, then simplify this procedure to just that one.
    ---------------------------------------------------------------------------------------------

    Result set, one row per family that has parts:
        FamilyId, FamilyName, Description, DescriptionReversed, PartCount, IsDeviceFamily
*/
CREATE OR ALTER PROCEDURE dbo.GetPriorityCalibrationItems
    @Part INT = NULL   /* optional: the device's catalogue part, to flag its own family */
AS
BEGIN
    SET NOCOUNT ON;

    CREATE TABLE #Families
    (
        FamilyId    INT,
        FamilyName  NVARCHAR(100),
        Description NVARCHAR(200),
        PartCount   INT
    );

    DECLARE @Quote CHAR(1) = CHAR(39);

    /* statement as the remote server sees it */
    DECLARE @RemoteQuery NVARCHAR(MAX) = N'
        SELECT f.FAMILY, f.FAMILYNAME, f.FAMILYDES, COUNT(p.PART) AS PartCount
        FROM amaba.dbo.FAMILY f
        INNER JOIN amaba.dbo.PART p ON p.FAMILY = f.FAMILY
        GROUP BY f.FAMILY, f.FAMILYNAME, f.FAMILYDES';

    /* ... wrapped as a string literal inside OPENQUERY, so every quote doubles */
    DECLARE @Sql NVARCHAR(MAX) =
        N'SELECT FAMILY, FAMILYNAME, FAMILYDES, PartCount FROM OPENQUERY([31.168.173.93], '
        + @Quote + REPLACE(@RemoteQuery, @Quote, @Quote + @Quote) + @Quote + N')';

    BEGIN TRY
        INSERT INTO #Families (FamilyId, FamilyName, Description, PartCount)
        EXEC sp_executesql @Sql;
    END TRY
    BEGIN CATCH
        /* Linked server unreachable. An empty list is a better failure than a broken screen, and
           the caller can tell the two apart by the row count. */
        DELETE FROM #Families;
    END CATCH

    /* Which family the device itself belongs to, so the screen can preselect it. */
    DECLARE @DeviceFamilyId INT = NULL;

    IF @Part IS NOT NULL
    BEGIN
        DECLARE @PartSql NVARCHAR(MAX) =
            N'SELECT TOP (1) @Found = FAMILY FROM OPENQUERY([31.168.173.93], '
            + @Quote
            + REPLACE(N'SELECT FAMILY FROM amaba.dbo.PART WHERE PART = ' + CAST(@Part AS NVARCHAR(20)),
                      @Quote, @Quote + @Quote)
            + @Quote + N') AS p';

        BEGIN TRY
            EXEC sp_executesql @PartSql, N'@Found INT OUTPUT', @Found = @DeviceFamilyId OUTPUT;
        END TRY
        BEGIN CATCH
            SET @DeviceFamilyId = NULL;
        END CATCH
    END

    SELECT
        f.FamilyId,
        LTRIM(RTRIM(f.FamilyName))                AS FamilyName,
        LTRIM(RTRIM(f.Description))               AS Description,
        REVERSE(LTRIM(RTRIM(f.Description)))      AS DescriptionReversed,
        f.PartCount,
        CAST(CASE WHEN f.FamilyId = @DeviceFamilyId THEN 1 ELSE 0 END AS BIT) AS IsDeviceFamily
    FROM #Families AS f
    ORDER BY f.PartCount DESC, f.FamilyName;

    DROP TABLE #Families;
END
GO
