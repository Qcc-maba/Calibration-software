/*
    dbo.fnMasterForOrderItem                                                           MBA-816
    ---------------------------------------------------------------------------------------------
    Which lab master an order item is - worked out from the item's serial number, so the "Save to
    DB" screen can pass the item it is on and nothing else.

    The serial number is the MabaID, but not as-is
    ----------------------------------------------
    OrderDetailsItems.SerialNumber is Priority's SERNUMBERS.SERNUM, copied unchanged (300 of 300
    recent PROD items compared, 29/09). Priority registers every device under its customer's code,
    so QCC's master 21-214 is '1-21-214' - customer 1, a dash, then the MabaID. All 4,615 of QCC's
    serial numbers have that shape.

    Taking the prefix off is not always enough. Some records carry a stray trailing dot - 21-214 has
    both '1-21-214' and '1-21-214.' in Priority, and either can be on an order. Of QCC's 4,615:

        2,021  match a live master's MabaID once '1-' is removed
          216  match only once a trailing dot or space is also removed
        2,378  match no master - QCC registers other internal equipment too (#001, 0130-4, ...)

    So: remove "<the order's customer code>-", then any trailing dots and spaces, then look the
    result up. The prefix is the ORDER'S customer code, not a fixed '1-', so the day saving is
    opened to customer devices (Nofar, 24/09) this keeps working. A serial number without its
    customer's prefix matches nothing - it is not a registered device.

    Returns one row per live master that carries the resulting MabaID: none when the item is not a
    master, two or more when a MabaID is shared (STAGE has three such, all test records). Callers
    decide what to do with more than one - the save procedures refuse, dbo.GetMasterForOrderItem
    returns nothing.

    Deliberately customer-agnostic. Which customers the button is shown for is
    dbo.GetMasterForOrderItem's rule, not this function's.
*/
CREATE OR ALTER FUNCTION dbo.fnMasterForOrderItem
(
    @OrderDetailsItemId INT
)
RETURNS TABLE
AS
RETURN
(
    WITH Item AS
    (
        SELECT i.OrderDetailsItemId,
               SerialNumber = LTRIM(RTRIM(i.SerialNumber)),
               /* CustomerIdFromSource is an INT (Priority's CUST) - made text to compare with the serial */
               CustomerCode = CAST(c.CustomerIdFromSource AS NVARCHAR(20))
        FROM dbo.OrderDetailsItems AS i
        JOIN dbo.OrderDetails      AS od ON od.OrderDetailId  = i.OrderDetailId
        JOIN dbo.OrderWorkPlans    AS wp ON wp.OrderWorkPlanId = od.OrderWorkPlanId
        JOIN dbo.Customers         AS c  ON c.CustomerId       = wp.CustomerId
        WHERE i.OrderDetailsItemId = @OrderDetailsItemId
    ),
    Stripped AS
    (
        /* the part after "<customer code>-", or NULL when the serial does not start with it */
        SELECT it.OrderDetailsItemId, it.SerialNumber, it.CustomerCode,
               Rest = CASE WHEN LEFT(it.SerialNumber, LEN(it.CustomerCode) + 1) COLLATE DATABASE_DEFAULT
                                = (it.CustomerCode + N'-') COLLATE DATABASE_DEFAULT
                           THEN SUBSTRING(it.SerialNumber, LEN(it.CustomerCode) + 2, 200) END
        FROM Item AS it
        WHERE NULLIF(it.CustomerCode, N'') IS NOT NULL
    ),
    Candidate AS
    (
        /* then drop trailing dots and spaces: how many there are is where the first other
           character sits in the reversed string. The length is LEN(x + 'x') - 1 because LEN
           alone ignores trailing spaces, and DATALENGTH depends on the column's type. */
        SELECT s.OrderDetailsItemId, s.SerialNumber, s.CustomerCode,
               MabaID = CASE WHEN PATINDEX(N'%[^. ]%', REVERSE(s.Rest)) = 0 THEN NULL
                             ELSE LEFT(s.Rest, LEN(s.Rest + N'x') - 1
                                               - PATINDEX(N'%[^. ]%', REVERSE(s.Rest)) + 1) END
        FROM Stripped AS s
        WHERE s.Rest IS NOT NULL
    )
    SELECT ca.OrderDetailsItemId, ca.SerialNumber, ca.CustomerCode, ca.MabaID,
           MeasurementDevicesId = md.ID,
           Matches = COUNT(*) OVER ()
    FROM Candidate AS ca
    JOIN dbo.MeasurementDevices AS md
      ON LTRIM(RTRIM(md.MabaID)) COLLATE DATABASE_DEFAULT = ca.MabaID COLLATE DATABASE_DEFAULT
     AND md.IsDeleted = 0
);
