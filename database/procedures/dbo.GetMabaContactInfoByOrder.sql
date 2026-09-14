/*
    dbo.GetMabaContactInfoByOrder
    ---------------------------------------------------------------------------------------------
    The contacts the coordinator can call about an order.

    WHAT CHANGED, AND WHAT DID NOT
    ------------------------------
    The OrderDetails join is gone. Nothing was ever selected from it, so it contributed no columns
    and no rows to the answer - it multiplied the intermediate set by the number of lines on the
    order and SELECT DISTINCT then threw the duplicates away again. LA26102923 has 11 detail lines
    and 188 contacts: 2,068 rows scanned to return 188. Without the join the DISTINCT is not needed
    either, so both are gone.

    The row count is NOT a bug and has not changed. 86 rows for LA26102918 and 188 for LA26102923
    are the real number of contacts on those customers - the join was wasted work, not duplication.

    WHAT IS STILL TRUE OF THIS PROCEDURE
    ------------------------------------
    It returns every contact on the CUSTOMER; there is nothing tying a contact to an order. The
    caller picks one, and until this returned a stable order it was picking whichever row SQL
    Server happened to hand back first - frequently a placeholder like '..' with no phone and no
    e-mail, which is why an order with 188 contacts reported having none.

    So the ordering below is part of the contract: reachable contacts first, named ones next. The
    caller still scores the rows, but it no longer depends on chance to see a usable one at all.
*/
CREATE OR ALTER PROCEDURE [dbo].[GetMabaContactInfoByOrder]
    @OrderID NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        wp.OrderNumber,
        cc.CustomerContactName                  AS ContactPersonName,
        cc.CustomerContactPersonRole            AS ContactPersonRole,
        cc.CustomerContactPhone                 AS PhoneNumber,
        cc.CustomerContactAdditionalPhoneNumber AS AdditionalPhoneNumber,
        cc.CustomerContactEmail                 AS Email
    FROM [dbo].[OrderWorkPlans] AS wp
    JOIN [dbo].[CustomerContacts] AS cc ON cc.CustomerId = wp.CustomerId
    WHERE wp.OrderNumber = @OrderID
      AND wp.IsCancelled = 0
    ORDER BY
        /* Someone you can actually reach comes first. '0' sits in these phone columns as a
           placeholder and is not a number anyone can dial. */
        CASE
            WHEN NULLIF(LTRIM(RTRIM(ISNULL(cc.CustomerContactEmail, ''))), '') IS NOT NULL THEN 0
            WHEN NULLIF(LTRIM(RTRIM(ISNULL(cc.CustomerContactPhone, ''))), '') NOT IN ('', '0') THEN 0
            WHEN NULLIF(LTRIM(RTRIM(ISNULL(cc.CustomerContactAdditionalPhoneNumber, ''))), '') NOT IN ('', '0') THEN 0
            ELSE 1
        END,
        /* Then anything with a real name, so the placeholder rows sink to the bottom. */
        CASE WHEN NULLIF(LTRIM(RTRIM(ISNULL(cc.CustomerContactName, ''))), '') IS NULL THEN 1 ELSE 0 END,
        cc.CustomerContactName;
END
