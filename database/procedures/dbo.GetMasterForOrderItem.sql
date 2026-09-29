/*
    dbo.GetMasterForOrderItem                                                          MBA-816
    ---------------------------------------------------------------------------------------------
    Should this order item get a "Save to DB" button, and if so, which lab master is it?

    One row when the item is exactly one live master AND belongs to an allowed customer; no rows
    otherwise. The screen shows the button when it gets a row, and needs no rule of its own:

      - QCC only for now (Nofar, 24/09). QCC is Priority customer 1 (Nofar, 29/09).
        @CustomerCodes is the list of Priority customer codes allowed, comma-separated,
        default '1'. NULL allows every customer - the day saving is opened to customer devices,
        that is the whole change.
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

    SELECT m.OrderDetailsItemId, m.SerialNumber, m.CustomerCode, m.MabaID, m.MeasurementDevicesId
    FROM dbo.fnMasterForOrderItem(@OrderDetailsItemId) AS m
    WHERE m.Matches = 1
      AND (@CustomerCodes IS NULL
           OR m.CustomerCode COLLATE DATABASE_DEFAULT IN
              (SELECT LTRIM(RTRIM(value)) COLLATE DATABASE_DEFAULT FROM STRING_SPLIT(@CustomerCodes, N',')));
END;
