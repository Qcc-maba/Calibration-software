/*
    FK_CalibrationCycles_ControllerTypeStatusId                                            MBA-980
    ---------------------------------------------------------------------------------------------
    dbo.CalibrationCycles.ControllerTypeStatusId -> dbo.Statuses.StatusId, like the table's other
    status columns. A foreign key cannot say which category the status must belong to;
    dbo.SaveCalibrationCycleSettings refuses any status that is not of category 'ControllerType'.

    WITH CHECK: the column is new and every row is NULL.
    Run after database/schema/dbo.CalibrationCycles.SummarySettings.sql.
*/
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_CalibrationCycles_ControllerTypeStatusId')
    ALTER TABLE dbo.CalibrationCycles WITH CHECK
        ADD CONSTRAINT FK_CalibrationCycles_ControllerTypeStatusId
            FOREIGN KEY (ControllerTypeStatusId) REFERENCES dbo.Statuses (StatusId);
GO

SELECT ForeignKey = f.name, IsNotTrusted = f.is_not_trusted
FROM sys.foreign_keys AS f
WHERE f.name = 'FK_CalibrationCycles_ControllerTypeStatusId';
GO
