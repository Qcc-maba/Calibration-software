/*
    dbo.BackfillMeasurementPointNames                                                   MBA-902
    ---------------------------------------------------------------------------------------------
    Names the measurement points that were saved without one.

    220 of the 366 saved points carry MeasurmentPointName = ''. The column is NOT NULL, so a blank
    name was stored rather than refused, and the chamber diagram draws each of them as a circle with
    nothing in it - which is what "why am I seeing an empty circle" is.

    AssignMeasurmentPointsToOrderDetailsItems now fills a blank name in as the next free T number,
    so no new ones appear. This names the ones already stored.

    Numbering follows the convention the named points already use, T1..T11, and continues from the
    highest T number that order item already holds, so an item with T1..T3 named and two blanks gets
    T4 and T5 rather than a collision. Within an item, blanks are numbered by channel and then by
    position, so the numbering is stable and repeatable rather than dependent on row order.

    Touches only rows whose name is blank. Idempotent - the second run finds nothing.

    Run with @Apply = 0 first: it reports what would be named and touches nothing.
*/
CREATE OR ALTER PROCEDURE dbo.BackfillMeasurementPointNames
    @Apply BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SELECT mp.OrderDetailsItemId,
           ISNULL(MAX(TRY_CAST(SUBSTRING(mp.MeasurmentPointName, 2, 10) AS INT)), 0) AS MaxUsed
    INTO #Base
    FROM dbo.MeasurmentPointsToOrderDetailsItems AS mp
    WHERE mp.IsDeleted = 0 AND mp.MeasurmentPointName LIKE 'T[0-9]%'
    GROUP BY mp.OrderDetailsItemId;

    SELECT mp.MeasurmentPointsToOrderDetailsItemId AS PointId,
           mp.OrderDetailsItemId,
           mp.ChannelNumber,
           'T' + CAST(ISNULL(b.MaxUsed, 0)
                      + ROW_NUMBER() OVER (PARTITION BY mp.OrderDetailsItemId
                                           ORDER BY mp.ChannelNumber,
                                                    mp.MeasurmentPointCoordX,
                                                    mp.MeasurmentPointCoordY)
                      AS NVARCHAR(10)) AS NewName
    INTO #Apply
    FROM dbo.MeasurmentPointsToOrderDetailsItems AS mp
    LEFT JOIN #Base AS b ON b.OrderDetailsItemId = mp.OrderDetailsItemId
    WHERE mp.IsDeleted = 0
      AND LTRIM(RTRIM(ISNULL(mp.MeasurmentPointName, N''))) = N'';

    SELECT COUNT(*)                                  AS WouldName,
           COUNT(DISTINCT OrderDetailsItemId)        AS AcrossOrderItems
    FROM #Apply;

    IF @Apply = 1
    BEGIN
        UPDATE mp
        SET MeasurmentPointName = a.NewName,
            UpdatedDate         = GETDATE()
        FROM dbo.MeasurmentPointsToOrderDetailsItems AS mp
        INNER JOIN #Apply AS a ON a.PointId = mp.MeasurmentPointsToOrderDetailsItemId;

        SELECT @@ROWCOUNT AS RowsNamed;
    END
    ELSE
        SELECT TOP (50) OrderDetailsItemId, ChannelNumber, NewName
        FROM #Apply ORDER BY OrderDetailsItemId, NewName;
END
