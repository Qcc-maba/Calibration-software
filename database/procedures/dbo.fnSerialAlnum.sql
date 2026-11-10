/*
    dbo.fnSerialAlnum                                                                    MBA-996
    ---------------------------------------------------------------------------------------------
    A serial number reduced to its upper-case Latin letters and digits: 'mpl-244 ' -> 'MPL244'.
    The SQL twin of normalizeSerial() in customer-analysis/server/pricing/services/serialIndex.ts,
    WITHOUT its customer-prefix strip: here the caller removes the exact "<CustomerCode>-" prefix it
    knows, because a regex for "digits then a dash" also eats a customer's own serial such as
    '1497-22/2'.

    Used only to compare ONE component of a compound serial with what a customer typed
    (dbo.RefreshCustomerDevicesFromPriority, claiming a typed device). Never compare two whole
    serials with it: '1497-22/2' and '1497-222' both reduce to '1497222', and they are two devices
    of one customer on PROD.

    A loop, not a set operation, so call it on small sets: the refresh calls it only for the
    customers that have typed devices waiting to be claimed.
*/
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

CREATE OR ALTER FUNCTION dbo.fnSerialAlnum (@s NVARCHAR(200))
RETURNS NVARCHAR(200)
WITH SCHEMABINDING, RETURNS NULL ON NULL INPUT
AS
BEGIN
    DECLARE @r NVARCHAR(200) = UPPER(@s) COLLATE Latin1_General_100_BIN2;
    DECLARE @p INT = PATINDEX(N'%[^A-Z0-9]%', @r);

    WHILE @p > 0
    BEGIN
        SET @r = STUFF(@r, @p, 1, N'');
        SET @p = PATINDEX(N'%[^A-Z0-9]%', @r);
    END

    RETURN @r;
END
GO
