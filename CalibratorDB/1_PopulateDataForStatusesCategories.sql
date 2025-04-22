MERGE INTO [dbo].[StatusesCategories] AS dest
USING (
SELECT
[StatusDescriptionENG],[StatusDescriptionHEB]
FROM (
	VALUES
	('ReportStatus',''),
	('EquipmentStatus',''),
	('CalibratedUnitsWorkStatus',''),
	('CalibratedUnitsStatus',''),
	('SpecialCare',''),
	('CarStatus',''),
	('CalibrationEquipmentStatus',''),
	('CalibratorsAvailabilityStatus',''),
	('MeasurementDeviceStatus',''),
	('OrderStatus',''),
	('EventTypes',''),
	('UserStatus','')
	) ds ([StatusDescriptionENG],[StatusDescriptionHEB])
	) AS source
	ON dest.[StatusDescriptionENG] = source.[StatusDescriptionENG]
WHEN MATCHED
	THEN
		UPDATE
		SET  
			dest.[StatusDescriptionHEB] = source.[StatusDescriptionHEB]
WHEN NOT MATCHED BY TARGET
	THEN
		INSERT (
			 [StatusDescriptionENG]
			,[StatusDescriptionHEB]
			)
		VALUES (
			 source.[StatusDescriptionENG]
			,source.[StatusDescriptionHEB]
			);
