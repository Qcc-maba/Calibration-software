/*
    CustomerDevices.AddedInPortal                                                         MBA-996
    ---------------------------------------------------------------------------------------------
    1 = the customer added this device in the portal (dbo.AssignCustomerDevicesData); 0 = loaded
    from Priority's register by dbo.RefreshCustomerDevicesFromPriority.

    Why (review of PR #60, thread r4588791119): dbo.vwCustomerDevices shows a registered device only
    once it has a visit, and a typed one always. When MABA registers a typed device in Priority, the
    refresh claims the row (sets SERN) and it became "registered without a visit" - it vanished from
    the customer's list, detail and quotes until its first calibration. The view now also shows a
    registered row the customer added. The claim keeps the flag: it never writes this column.

    Written once, on insert, by dbo.AssignCustomerDevicesData. Existing rows get 0, except rows
    without a SERN: only the portal creates those, so they get 1 (the portal developer's test saves
    on STAGE, 2026-11-16). The table file dbo.CustomerDevices.table.sql has the column for a fresh
    create. Safe to re-run.
*/
IF COL_LENGTH('dbo.CustomerDevices', 'AddedInPortal') IS NULL
    ALTER TABLE dbo.CustomerDevices
        ADD AddedInPortal BIT NOT NULL CONSTRAINT DF_CustomerDevices_AddedInPortal DEFAULT (0);
GO

UPDATE dbo.CustomerDevices SET AddedInPortal = 1 WHERE SERN IS NULL AND AddedInPortal = 0;
GO
