MERGE INTO [dbo].[StatusesCategories] AS dest
USING (
SELECT
[StatusDescriptionENG],[StatusDescriptionHEB]
FROM (
	VALUES
	(N'ReportStatus',''),
	(N'CalibrationStatuses',''),
	(N'CalibratedUnitsStatus',''),
	(N'SpecialCare',''),
	(N'CarStatus',''),
	(N'CalibrationEquipmentStatus',''),
	(N'UserAvailabilityStatus',''),
	(N'MeasurementDeviceStatus',''),
	(N'OrderStatus',''),
	(N'EventTypes',''),
	(N'UserStatus',''),
	(N'Position',''),
	(N'ClientConfirmationStatus',''),
	(N'CalibratorNotificationType',''),
	(N'StickerType',''),
	(N'CalibrationCycleName','')
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
