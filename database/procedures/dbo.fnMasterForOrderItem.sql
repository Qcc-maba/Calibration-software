/*
    dbo.fnMasterForOrderItem                                                           MBA-816
    ---------------------------------------------------------------------------------------------
    Which lab master an order item is - worked out from the item's serial number, so the "Save to
    DB" screen can pass the item it is on and nothing else.

    The serial number is the MabaID, but not as-is
    ----------------------------------------------
    OrderDetailsItems.SerialNumber is Priority's SERNUMBERS.SERNUM, copied unchanged (300 of 300
    recent PROD items compared, 29/09). QCC registers its own devices under its customer code, so
    master 21-214 is '1-21-214' - customer 1, a dash, then the MabaID. All 4,615 of QCC's serial
    numbers have that shape. Other customers' do not: 0 of 8,962 PROD items of other customers start
    with their own customer code (29/09).

    Taking the prefix off is not always enough. Some records carry a stray trailing dot - 21-214 has
    both '1-21-214' and '1-21-214.' in Priority, and either can be on an order. Of QCC's 4,615:

        2,021  match a live master's MabaID once '1-' is removed
          216  match only once a trailing dot or space is also removed
        2,378  match no master - QCC registers other internal equipment too (#001, 0130-4, ...)

    So: remove "<the order's customer code>-", then any trailing dots and spaces, then look the
    result up. A serial number without that prefix matches nothing.

    Only the lab's own devices can be lab masters
    ---------------------------------------------
    dbo.MeasurementDevices holds the LAB's masters. For another customer's item, the part after its
    customer code would be that customer's own asset number, and matching it against the lab's
    MabaIDs would attach a customer's calibration to a lab master. A device is a lab master because
    it belongs to QCC (Nofar, 08/09), so the customer is checked here, in the one place every caller
    goes through: @CustomerCodes is the list of allowed Priority customer codes, comma-separated.
    Every caller passes N'1' (QCC); NULL allows any customer. (No such false match exists in PROD
    today - see above - so this closes a door rather than fixing a live case.)

    Returns one row per live master that carries the resulting MabaID: none when the item is not a
    master or not an allowed customer's, two or more when a MabaID is shared (STAGE has three such,
    all test records). Callers decide what to do with more than one - the save procedures refuse,
    dbo.GetMasterForOrderItem returns nothing.
*/
CREATE OR ALTER FUNCTION dbo.fnMasterForOrderItem
(
    @OrderDetailsItemId INT,
    @CustomerCodes      NVARCHAR(200)   /* allowed Priority customer codes, e.g. N'1'; NULL = any */
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
          AND (@CustomerCodes IS NULL
               OR CAST(c.CustomerIdFromSource AS NVARCHAR(20)) COLLATE DATABASE_DEFAULT IN
                  (SELECT LTRIM(RTRIM(value)) COLLATE DATABASE_DEFAULT FROM STRING_SPLIT(@CustomerCodes, N',')))
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
