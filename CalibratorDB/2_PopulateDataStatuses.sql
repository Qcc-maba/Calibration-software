MERGE INTO [dbo].[Statuses] AS dest
USING (
	SELECT 
	  sc.StatusCategoryId
	 ,ds.[Code]
	 ,ds.[StatusDescriptionENG]
	 ,ds.[StatusDescriptionHEB]
	FROM (
		VALUES
		('EquipmentStatus','','Available',N'תקין'),
		('EquipmentStatus','','Treatment',N'בטיפול'),
		('EquipmentStatus','','Damaged',N'תקול'),
		('ReportStatus','AA','Received',N'נקלט'),
		('ReportStatus','AC','Opening a new calibration',N'פתיחת כיול חדש'),
		('CalibratedUnitsWorkStatus','','Waiting for calibration',N'מחכה לכיול'),
		('CalibratedUnitsWorkStatus','','In calibration',N'בכיול'),
		('CalibratedUnitsWorkStatus','','Calibration failed',N'כיול נכשל'),
		('CalibratedUnitsWorkStatus','','Packaged',N'אריזה'),
		('CalibratedUnitsWorkStatus','','Calibration success',N'כיול הצליח'),
		('CalibratedUnitsWorkStatus','','Delivered',N'נשלח'),
		('CalibratedUnitsStatus','','Functional',N'תקין'),
		('CalibratedUnitsStatus','','Damaged Door Seal',N'אטם דלת פגום'),
		('CalibratedUnitsStatus','','Broken Handle',N'ידית שבורה'),
		('CalibratedUnitsStatus','','Faulty Door',N'דלת לא תקינה'),
		('CalibratedUnitsStatus','','Faulty Fan',N'מאוור לא תקין'),
		('CalibratedUnitsStatus','','Crack in the Glass',N'סדק בזכוכית'),
		('SpecialCare','','Packing',N'אריזה'),
		('SpecialCare','','Customer complaint',N'תלונת לקוח'),
		('SpecialCare','','Shared',N'משותף'),
		('SpecialCare','','Urgent',N'דחוף '),
		('CarStatus','','Available',N'תקין'),
		('CarStatus','','Treatment',N'טיפול'),
		('CarStatus','','Damage',N'פגום'),
		('CalibrationEquipmentStatus','','Available',N'זמין '),
		('CalibrationEquipmentStatus','','Treatment',N'טיפול'),
		('CalibrationEquipmentStatus','','Damage',N'תקול '),
		('CalibratorsAvailabilityStatus','','Available',N'זמין '),
		('CalibratorsAvailabilityStatus','','Sick',N'חולה'),
		('CalibratorsAvailabilityStatus','','Vacation',N'חופשה'),
		('CalibratorsAvailabilityStatus','','Maba',N'מ.ב.א'),
		('CalibratorsAvailabilityStatus','','InActive',N'לא פעיל'),
		('MeasurementDeviceStatus','','Available',N'זמין '),
		('MeasurementDeviceStatus','','NotCalibrated',N'לא מכויל'),
		('MeasurementDeviceStatus','','Damaged',N'תקול'),
		('MeasurementDeviceStatus','','Lost',N'אבד'),
		('MeasurementDeviceStatus','','Sent for calibration',N'נשלח לכיול'),
		('OrderStatus','','Received',N'נקלט'),
		('OrderStatus','','Sent',N'נשלח'),
		('OrderStatus','','Report Generated',N'הופק דו"ח'),
		('OrderStatus','','QAF','QAF'),
		('OrderStatus','','Packed',N'נארז'),
		('EventTypes','','Company Event - Mandatory',N'אירוע חברה - חובה'),
		('EventTypes','','Company Event - Optional',N' אירוע חברה -רשות'),
		('EventTypes','','Holiday',N'חג'),
		('EventTypes','','Day Off',N'יום חופש'),
		('UserStatus','','Active',N'פעיל'),
		('UserStatus','','NotActive',N'לא פעיל')
		) ds ([StatusCategory],[Code],[StatusDescriptionENG],[StatusDescriptionHEB])
		JOIN [dbo].[StatusesCategories] as sc ON ds.StatusCategory = sc.StatusDescriptionENG
	) AS source
	ON dest.[StatusDescriptionENG] = source.[StatusDescriptionENG]
	   AND dest.[StatusCategoryId] = source.[StatusCategoryId]
WHEN MATCHED
	THEN
		UPDATE
		SET  dest.[Code] = source.[Code]
			,dest.[StatusDescriptionENG] = source.[StatusDescriptionENG]
			,dest.[StatusDescriptionHEB] = source.[StatusDescriptionHEB]
WHEN NOT MATCHED BY TARGET
	THEN
		INSERT (
             [StatusCategoryId]
			,[Code]
			,[StatusDescriptionENG]
			,[StatusDescriptionHEB]
			)
		VALUES (
			source.[StatusCategoryId]
			,source.[Code]
			,source.[StatusDescriptionENG]
			,source.[StatusDescriptionHEB]
			);