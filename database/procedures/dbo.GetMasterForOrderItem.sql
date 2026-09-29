/*
    dbo.GetMasterForOrderItem                                                          MBA-816
    ---------------------------------------------------------------------------------------------
    Should this order item get a "Save to DB" button, and if so, which lab master is it?

    One row when the item is exactly one live master AND belongs to an allowed customer; no rows
    otherwise. The screen shows the button when it gets a row, and needs no rule of its own:

      - QCC only for now (Nofar, 24/09). QCC is Priority customer 1 (Nofar, 29/09).
        @CustomerCodes is the list of Priority customer codes allowed, comma-separated,
        default '1'. The save procedures apply the same rule with the same default, so an item the
        button is not shown for cannot be saved by calling them directly either.
      - Masters only. Belonging to QCC is not enough: of QCC's 4,615 registered serial numbers,
        2,378 are other internal equipment that is no master (see dbo.fnMasterForOrderItem).
      - Unambiguous only. A MabaID held by two live devices returns nothing rather than a guess.

    How the item's serial number becomes a MabaID - the '1-' prefix, the stray trailing dots - is
    dbo.fnMasterForOrderItem's job, shared with the two save procedures so all three agree.
*/
CREATE OR ALTER PROCEDURE dbo.GetMasterForOrderItem
    @OrderDetailsItemId INT,
    @CustomerCodes      NVARCHAR(200) = N'1'
AS
BEGIN
    SET NOCOUNT ON;

    /* the customer rule is applied inside the function, the same way the save procedures get it */
    SELECT m.OrderDetailsItemId, m.SerialNumber, m.CustomerCode, m.MabaID, m.MeasurementDevicesId
    FROM dbo.fnMasterForOrderItem(@OrderDetailsItemId, @CustomerCodes) AS m
    WHERE m.Matches = 1;
END;
