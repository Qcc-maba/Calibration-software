/* QUOTED_IDENTIFIER / ANSI_NULLS ON, whatever client deploys this (sqlcmd defaults QUOTED_IDENTIFIER
   to OFF): the filtered unique index on dbo.CalibrationCycleMarkers needs them, and so does every
   procedure that writes the table, which keeps the settings it was created with. */
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO
/*
    dbo.GetCalibrationCycleMarkers                                                         MBA-983
    ---------------------------------------------------------------------------------------------
    Every live marker on the live cycles of one order line, in cycle order and then line-1 order.
    Written by dbo.SaveCalibrationCycleMarkers; see dbo.CalibrationCycleMarkers for what is stored.

    The times come back as text, 'yyyy-mm-ddThh:mi:ss.mmm' with no time zone (style 126), on
    purpose: they are the station's wall-clock time, and a DATETIME2 handed to the app's driver is
    read as UTC and shifted by the browser's offset. The app parses the text as local time, the same
    instant the calibrator placed. CalibrationCycleStartDate is text for the same reason, so the
    app can match each marker to its cycle exactly.

    A marker of a deleted cycle is not returned. A line with no markers returns no rows.
*/
CREATE OR ALTER PROCEDURE dbo.GetCalibrationCycleMarkers
    @OrderDetailsItemId INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT m.CalibrationCycleMarkerId,
           m.OrderDetailsItemId,
           CalibrationCycleStartDate = CONVERT(VARCHAR(23), m.CalibrationCycleStartDate, 126),
           m.MarkerType,
           Time1 = CONVERT(VARCHAR(23), m.Time1, 126),
           Time2 = CONVERT(VARCHAR(23), m.Time2, 126),
           Time3 = CONVERT(VARCHAR(23), m.Time3, 126),
           m.PeakMode,
           m.MinValue,
           m.MaxValue,
           m.AverageValue,
           m.SecondaryMinValue,
           m.SecondaryMaxValue,
           m.SecondaryAverageValue
    FROM dbo.CalibrationCycleMarkers AS m
    JOIN dbo.CalibrationCycles AS c
      ON c.OrderDetailsItemId = m.OrderDetailsItemId
     AND c.CalibrationCycleStartDate = m.CalibrationCycleStartDate
    WHERE m.OrderDetailsItemId = @OrderDetailsItemId
      AND m.IsDeleted = 0
      AND c.IsDeleted = 0
    ORDER BY m.CalibrationCycleStartDate, m.Time1;
END;
GO
