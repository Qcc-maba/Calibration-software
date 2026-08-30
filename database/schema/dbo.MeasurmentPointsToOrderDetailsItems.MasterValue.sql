/*
    MeasurmentPointsToOrderDetailsItems.MasterValue - widening it                      MBA-811
    ---------------------------------------------------------------------------------------------
    The column was DECIMAL(10,8). Precision 10 with scale 8 leaves TWO digits before the decimal
    point, so the largest value it can hold is 99.99999999.

    Every sibling column on the table is DECIMAL(10,4); MasterValue alone had scale 8. Nothing
    suggests that was deliberate - it reads like a typo for (10,4).

    What it did. A calibrator entering a master reading of 100 or more got
    "Arithmetic overflow error converting numeric to data type numeric", the whole save was
    rejected, and NOTHING on screen said so: the typed value stayed in the box, the compensated
    column went on showing the arithmetic for the last reading that did save, and the row's
    UpdatedDate still moved. It looked like the compensation was broken. It was the save.

    This is not an edge case. 31-77's certificate runs to 349.98 degrees and other masters reach
    1104. Any calibration point at or above 100 was unsavable.

    Widened to DECIMAL(18,6), matching NominalValue - the value a master reading is compared
    against. No index, default or check constraint is bound to the column, and the largest value
    stored was 98.09, so no data was at risk. 192 points, all intact after the change.

    The OPENJSON declarations in AssignMeasurmentPointsToOrderDetailsItems and its V2 said
    DECIMAL(10,4) and are widened to match, so a reading is not silently truncated on the way in.
*/
IF EXISTS (SELECT 1 FROM sys.columns c
           JOIN sys.types t ON t.user_type_id = c.user_type_id
           WHERE c.object_id = OBJECT_ID('dbo.MeasurmentPointsToOrderDetailsItems')
             AND c.name = 'MasterValue' AND (c.precision <> 18 OR c.scale <> 6))
    ALTER TABLE dbo.MeasurmentPointsToOrderDetailsItems
    ALTER COLUMN MasterValue DECIMAL(18,6) NULL;
GO
