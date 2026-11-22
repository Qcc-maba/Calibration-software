/*
    FK_OrderDetailsItems_SecondaryMeasurementUnitId                                         MBA-800
    The second measured value's unit is a dbo.MeasurementDeviceUnits row, like MeasurementUnitId.
    The column is new and NULL everywhere, so nothing can violate the key when it is added.
*/
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys
               WHERE name = 'FK_OrderDetailsItems_SecondaryMeasurementUnitId'
                 AND parent_object_id = OBJECT_ID('dbo.OrderDetailsItems'))
    ALTER TABLE dbo.OrderDetailsItems
        ADD CONSTRAINT FK_OrderDetailsItems_SecondaryMeasurementUnitId
            FOREIGN KEY (SecondaryMeasurementUnitId)
            REFERENCES dbo.MeasurementDeviceUnits (MeasurementDeviceUnitId);
GO
