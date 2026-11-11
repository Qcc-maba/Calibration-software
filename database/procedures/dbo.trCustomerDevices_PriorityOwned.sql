/*
    dbo.trCustomerDevices_PriorityOwned                                                 MBA-996
    ---------------------------------------------------------------------------------------------
    The backstop for the rule "a registered device's Priority-owned fields change only in
    Priority" (decided 2026-11-10, DBA/schema-updates.md section 2, point 2). The portal procedure
    dbo.AssignCustomerDevicesData refuses such an edit first, with a message the customer sees;
    this trigger catches every other writer - a future procedure, a data fix, a bug.

    WHO MAY WRITE THEM
    ------------------
    Only dbo.RefreshCustomerDevicesFromPriority. Around its writes it sets
        EXEC sys.sp_set_session_context N'CustomerDevices.Writer', N'PriorityRefresh';
    and clears it again afterwards, on error too. Deliberately NOT @read_only = 1: a read-only key
    can never be cleared, so after one manual run in an SSMS window every later edit in that
    window would pass this trigger. This guards against our own mistakes, not against someone who
    can already run arbitrary SQL - such a session could set the flag too. The portal's login is db_owner today, so it could also
    disable this trigger; narrowing that login is SEC-5, and an ORIGINAL_LOGIN() test here would
    not replace it (decided 2026-11-11, DBA/schema-updates.md section 2, point 2).

    WHAT IS REFUSED (error 54208, the same number the portal procedure uses)
    -----------------------------------------------------------------------
    On any row, unless the refresh is writing:
      - setting or changing SERN (claiming a typed device is the refresh's job);
      - DevicePart, DeviceTypeName, DeviceDescription, IsInactiveInSource, SourceUpdatedAt,
        RefreshedAt - copies of Priority, nobody else has a value for them.
    On a registered row (SERN IS NOT NULL), unless the refresh is writing:
      - CustomerId, SerialNumber, Model, OrdersDeviceManufacturer, CalibrationIntervalMonths,
        OrdersProductTypeId, NextCalibrationDate.
    Always, the refresh included:
      - DELETE. Rows are never deleted (session1 decision 17); the customer hides a device with
        IsDeleted = 1, Priority's cancellation arrives as IsInactiveInSource = 1.

    Everything else - site, contact, location, categories, specification, IsDeleted, NeedsReview -
    stays writable for the portal procedure and for staff.
*/
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

CREATE OR ALTER TRIGGER dbo.trCustomerDevices_PriorityOwned
ON dbo.CustomerDevices
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM inserted) AND NOT EXISTS (SELECT 1 FROM deleted)
        RETURN;

    /* DELETE: no rows in inserted. */
    IF NOT EXISTS (SELECT 1 FROM inserted)
        THROW 54208, 'Rows of dbo.CustomerDevices are never deleted. Set IsDeleted = 1 to hide a device.', 1;

    DECLARE @IsRefresh BIT =
        CASE WHEN CAST(SESSION_CONTEXT(N'CustomerDevices.Writer') AS NVARCHAR(40)) = N'PriorityRefresh'
             THEN 1 ELSE 0 END;

    IF @IsRefresh = 1
        RETURN;

    /* INSERT (no deleted rows): a new row may not arrive registered or with Priority copies. */
    IF NOT EXISTS (SELECT 1 FROM deleted)
    BEGIN
        IF EXISTS (SELECT 1 FROM inserted
                   WHERE SERN IS NOT NULL OR DevicePart IS NOT NULL OR DeviceTypeName IS NOT NULL
                      OR DeviceDescription IS NOT NULL OR IsInactiveInSource = 1
                      OR SourceUpdatedAt IS NOT NULL OR RefreshedAt IS NOT NULL)
            THROW 54208, 'Only the Priority refresh adds registered devices or Priority-owned values to dbo.CustomerDevices.', 1;
        RETURN;
    END

    /* UPDATE. EXCEPT compares NULLs as equal, so each test is "did any of these columns change". */
    IF EXISTS (SELECT 1
               FROM inserted AS i
               JOIN deleted  AS d ON d.CustomerDeviceID = i.CustomerDeviceID
               WHERE EXISTS (SELECT i.SERN, i.DevicePart, i.DeviceTypeName, i.DeviceDescription,
                                    i.IsInactiveInSource, i.SourceUpdatedAt, i.RefreshedAt
                             EXCEPT
                             SELECT d.SERN, d.DevicePart, d.DeviceTypeName, d.DeviceDescription,
                                    d.IsInactiveInSource, d.SourceUpdatedAt, d.RefreshedAt))
        THROW 54208, 'SERN and the Priority copies on dbo.CustomerDevices are written only by dbo.RefreshCustomerDevicesFromPriority.', 1;

    IF EXISTS (SELECT 1
               FROM inserted AS i
               JOIN deleted  AS d ON d.CustomerDeviceID = i.CustomerDeviceID
               WHERE d.SERN IS NOT NULL
                 AND EXISTS (SELECT i.CustomerId, i.SerialNumber, i.Model, i.OrdersDeviceManufacturer,
                                    i.CalibrationIntervalMonths, i.OrdersProductTypeId, i.NextCalibrationDate
                             EXCEPT
                             SELECT d.CustomerId, d.SerialNumber, d.Model, d.OrdersDeviceManufacturer,
                                    d.CalibrationIntervalMonths, d.OrdersProductTypeId, d.NextCalibrationDate))
        THROW 54208, 'This field is managed by MABA: a registered device changes only in Priority.', 1;
END
GO
