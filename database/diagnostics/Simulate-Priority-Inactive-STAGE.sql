/*  STAGE only: what Priority's INACTIVE flag will do, one step early.

    WHY
      eliran_ha@mba.co.il should be a portal identity for Philips alone. Priority still lists the
      address on two מ.ב.א contacts - PHONE 52397 (CUST 1) and 53544 (CUST 2) - and marks neither
      inactive, so the sync keeps importing them as active and the portal keeps resolving the login
      to מ.ב.א. On STAGE nobody in that set owns devices, so the tie-break falls to the lowest
      contact id, which is one of those two.

      This sets IsActive = 0 on exactly those two rows for exactly this address, which is what the
      contact sync will do by itself once PHONE 52397 and 53544 carry INACTIVE = 'Y' in Priority.

    IT IS NOT PERMANENT
      The next run of stg.LoadCustomerContactsFromPriority + stg.MergeCustomersContactsData reads
      Priority's flag and sets these rows back to active until Priority says otherwise. Do the
      Priority side and this file stops being needed.

    WHERE TO RUN
      SSMS -> 51.17.121.203\QCC -> database **Calibrator** (STAGE). Not on PROD: there the device
      rule already picks Philips once the identity script has run, so nothing has to be forced.
*/

SET NOCOUNT ON;

DECLARE @Email NVARCHAR(100) = N'eliran_ha@mba.co.il';

UPDATE dbo.CustomerContacts
SET    IsActive    = 0,
       UpdatedDate = SYSUTCDATETIME()
WHERE  LOWER(LTRIM(RTRIM(CustomerContactEmail))) = @Email
  AND  ISNULL(IsDeleted, 0) = 0
  AND  ISNULL(IsActive, 1) = 1
  AND  CustomerContactIdFromSource IN (52397, 53544);   /* the two מ.ב.א contacts; Philips is 56102 */

PRINT CONCAT('Marked inactive: ', @@ROWCOUNT);

/* Expect one row: Philips. */
SELECT * FROM dbo.GetPortalCustomerIds(@Email);

/* Every row this address has, and its flag. */
SELECT cc.CustomerContactId,
       c.CustomerName,
       cc.CustomerContactIdFromSource,
       cc.IsActive
FROM   dbo.CustomerContacts AS cc
LEFT JOIN dbo.Customers AS c ON c.CustomerId = cc.CustomerId
WHERE  LOWER(LTRIM(RTRIM(cc.CustomerContactEmail))) = @Email
  AND  ISNULL(cc.IsDeleted, 0) = 0
ORDER BY cc.IsActive DESC, cc.CustomerContactId;

/* Undo:
UPDATE dbo.CustomerContacts SET IsActive = 1
WHERE LOWER(LTRIM(RTRIM(CustomerContactEmail))) = N'eliran_ha@mba.co.il'
  AND CustomerContactIdFromSource IN (52397, 53544);
*/
