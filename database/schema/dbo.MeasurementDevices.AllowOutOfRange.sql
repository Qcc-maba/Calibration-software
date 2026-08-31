/*
    MeasurementDevices - AllowMinOutOfRange / AllowMaxOutOfRange                       MBA-475
    ---------------------------------------------------------------------------------------------
    Nofar asked which field says whether an instrument may go out of range at all. It existed only
    in the legacy registry, kyulan.dbo.tblInstr, as AllowMinOOR / AllowMaxOOR. Brought across here
    so the portal can read it.

    They are permissions, not thresholds - booleans, not degrees. Of 2,786 instruments in kyulan,
    2,248 permit an excursion at both ends, 507 at neither, 31 at the top only. So they do not
    conflict with the fixed 10-degree rule; they say who is allowed any excursion in the first
    place.

    Loaded onto 1,842 of our 3,453 devices, matched on MabaID. 328 of those permit neither end.
*/
IF COL_LENGTH('dbo.MeasurementDevices','AllowMinOutOfRange') IS NULL
    ALTER TABLE dbo.MeasurementDevices ADD AllowMinOutOfRange BIT NULL;
GO
IF COL_LENGTH('dbo.MeasurementDevices','AllowMaxOutOfRange') IS NULL
    ALTER TABLE dbo.MeasurementDevices ADD AllowMaxOutOfRange BIT NULL;
GO
DROP TABLE IF EXISTS #K;
SELECT * INTO #K FROM OPENQUERY([31.168.173.93], '
  SELECT MabaID, AllowMinOOR, AllowMaxOOR FROM kyulan.dbo.tblInstr WHERE MabaID IS NOT NULL
');
UPDATE d
SET d.AllowMinOutOfRange = CAST(k.AllowMinOOR AS BIT),
    d.AllowMaxOutOfRange = CAST(k.AllowMaxOOR AS BIT)
FROM dbo.MeasurementDevices d
JOIN #K k ON LTRIM(RTRIM(k.MabaID)) COLLATE DATABASE_DEFAULT
           = LTRIM(RTRIM(d.MabaID)) COLLATE DATABASE_DEFAULT;
GO
