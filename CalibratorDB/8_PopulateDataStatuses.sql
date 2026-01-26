MERGE INTO [dbo].[Statuses] AS dest
USING (
	SELECT 
	  sc.StatusCategoryId
	 ,ds.[Code]
	 ,ds.[StatusDescriptionENG]
	 ,LTRIM(RTRIM(ds.[StatusDescriptionHEB])) AS [StatusDescriptionHEB]
	FROM (
		VALUES
		('ReportStatus','AA','Received',N'נקלט'),
		('ReportStatus','AC','OpeningNewCalibration',N'פתיחת כיול חדש'),
		('ReportStatus','DC','StandbyModeCustomerReason',N'מצב המתנה (סיבת לקוח)'),
		('ReportStatus','DM','StandbyModeImporterReason',N'מצב המתנה (סיבת מבא)'),
		('ReportStatus','FC','ContinueCalibrationAfterStandby',N'המשך כיול לאחר המתנה'),
		('ReportStatus','GR','CreateCalibrationReport',N'יצירת דוח כיול'),
		('ReportStatus','CD','CreateCalibrationReportForFirstTime',N'יצירת דוח כיול פעם ראשונה'),
		('ReportStatus','H1','FirstSignature',N'חתימה ראשונה'),
		('ReportStatus','H2','SecondSignature',N'חתימה שניה'),
		('ReportStatus','HR','ReportRejectedByApprover',N'דוח נדחה על ידי מאשר'),
		('ReportStatus','TX','DeviceSentToCustomer',N'מכשיר נשלח ללקוח'),
		('ReportStatus','UC','OpenReportForUpdate',N'פתיחת דוח לעדכון'),
		('ReportStatus','UM','UpdatedReportStandbyModeImporterReason',N'דוח עדכון מצב המתנה (סיבת מבא)'),
		('ReportStatus','UD','UpdatedReportStandbyModeCustomerReason',N'דוח עדכון מצב המתנה (סיבת לקוח)'),
		('ReportStatus','UF','UpdatedReportContinueCalibrationAfterStandby',N'דוח עדכון המשך כיול לאחר המתנה'),
		('ReportStatus','UG','CreateUpdatedReport',N'יצירת דוח עדכון'),
		('ReportStatus','UP','CreatePdfOfUpdatedReport',N'יצירת PDF של דוח העדכון'),
		('ReportStatus','UX','UpdatedReportSentToCustomer',N'נשלח דוח העדכון ללקוח'),
		('CalibrationStatuses','','WaitingForCalibration',N'מחכה לכיול'),
		('CalibrationStatuses','','InCalibration',N'בכיול'),
		('CalibrationStatuses','','CalibrationFailed',N'כיול נכשל'),
		('CalibrationStatuses','','Packaged',N'אריזה'),
		('CalibrationStatuses','','CalibrationSuccess',N'כיול הצליח'),
		('CalibrationStatuses','','Delivered',N'נשלח'),
		('CalibrationStatuses','','Stopped',N'הופסק'),
		('CalibrationStatuses','','Adjusted',N'כויל'),
		('CalibrationStatuses','','ReadyForDelivery',N'ממתין לאיסוף'),
		('CalibrationStatuses','','WaitingForPacking',N'ממתין לאריזה'),
		('CalibrationStatuses','','ReadyForPacking',N'מוכן לאריזה'),
		('CalibratedUnitsStatus','','Functional',N'תקין'),
		('CalibrationStatuses','','TestedMetTheStandard',N'נבדק עומד'),
		('CalibrationStatuses','','TestedDidn''tMeetTheStandards',N'נבדק - לא עומד'),
		('CalibrationStatuses','','CannotBeDetermined',N'לא ניתן לקבוע'),
		('CalibrationStatuses','','AwaitingComments',N'ממתין להערות'),
		('CalibrationStatuses','','AwaitingSignature',N'ממתין לחתימה'),
		('CalibrationStatuses','','AwaitingCalibration',N'ממתין לכיול'),
		('CalibrationStatuses','','Calibration',N'כיול'),
		('CalibratedUnitsStatus','','DamagedDoor Seal',N'אטם דלת פגום'),
		('CalibratedUnitsStatus','','BrokenHandle',N'ידית שבורה'),
		('CalibratedUnitsStatus','','FaultyDoor',N'דלת לא תקינה'),
		('CalibratedUnitsStatus','','FaultyFan',N'מאוור לא תקין'),
		('CalibratedUnitsStatus','','CrackInTheGlass',N'סדק בזכוכית'),
		('SpecialCare','','Packing',N'אריזה'),
		('SpecialCare','','CustomerComplaint',N'תלונת לקוח'),
		('SpecialCare','','Shared',N'משותף'),
		('SpecialCare','','Urgent',N'דחוף '),
		('CarStatus','','Available',N'תקין'),
		('CarStatus','','Treatment',N'טיפול'),
		('CarStatus','','UnAvailable',N'לא זמין'),
		('CarStatus','','Sold',N'נמכר'),
		('CalibrationEquipmentStatus','','Available',N'זמין '),
		('CalibrationEquipmentStatus','','Treatment',N'טיפול'),
		('CalibrationEquipmentStatus','','Damage',N'תקול '),
		('UserAvailabilityStatus','','Available',N'זמין '),
		('UserAvailabilityStatus','','Sick',N'חולה'),
		('UserAvailabilityStatus','','Vacation',N'חופשה'),
		('UserAvailabilityStatus','','Maba',N'מ.ב.א'),
		('UserAvailabilityStatus','','InActive',N'לא פעיל'),
		('MeasurementDeviceStatus','','Available',N'זמין '),
		('MeasurementDeviceStatus','','NotCalibrated',N'לא מכויל'),
		('MeasurementDeviceStatus','','Damaged',N'תקול'),
		('MeasurementDeviceStatus','','Lost',N'אבד'),
		('MeasurementDeviceStatus','','SentForCalibration',N'נשלח לכיול'),
		('OrderStatus','','Received',N'נקלט'),
		('OrderStatus','','Sent',N'נשלח'),
		('OrderStatus','','ReportGenerated',N'הופק דו"ח'),
		('OrderStatus','','Packed',N'נארז'),
		('OrderStatus', '', 'WaitingForValidation', N'ממתין לולידציה'),
		('OrderStatus', '', 'WaitingForDelivery', N'ממתין למשלוח'),
		('OrderStatus', '', 'AcceptedByCustomer', N'התקבל על ידי הלקוח'),
		('OrderStatus', '', 'Rejected', N'נדחה'),
		('OrderStatus', '', 'AwaitingConfirmation', N'ממתין לאישור'),
		('OrderStatus','', 'AwaitingCollection', N'ממתין לאיסוף '),
		('OrderStatus','', 'Finished', N'הסתיים '),
		('OrderStatus','','WaitingForCalibration',N'מחכה לכיול'),
		('EventTypes','','CompanyEventMandatory',N'אירוע חברה - חובה'),
		('EventTypes','','CompanyEventOptional',N' אירוע חברה -רשות'),
		('EventTypes','','SickLeave',N'מחלה'),
		('EventTypes','','Vacation',N'חופש'),
		('UserStatus','','Active',N'פעיל'),
		('UserStatus','','NotActive',N'לא פעיל'),
		('Position','CT','Calibration Technician',N'כייל'),
		('Position','TL','TeamLeader',N'ראש צוות'),
		('Position','DH','DepartmentHead',N'ראש מדור'),
		('Position','ME','MetrologyEngineer',N'טכנולוג'),
		('Position','COO','ChiefOperationsOfficer',N'מנהל תפעול'),
		('Position','CTO','ChiefTechnologyOfficer',N'מנהל טכני'),
		('ClientConfirmationStatus','','Pending',N'בהמתנה'),
		('ClientConfirmationStatus','','Confirmed',N'מאושר'),
		('ClientConfirmationStatus','','Rejected',N'נדחה'),
		('CalibratorNotificationType','','NewOrderNotification',N'הזמנה חדשה'),
		('CalibratorNotificationType','','DelayOrderNotification',N'הזמנה נדחתה'),
		('CalibratorNotificationType','','CancelOrderNotification',N'הזמנה בוטלה'),
		('CalibratorNotificationType','','ValidatorCommentNotification',N'הערת ביקורת'),
		('CalibratorNotificationType','','SecondSignatureNotification',N'חתימה שניה'),
		('StickerType','','Big',N'גדולה'),
		('StickerType','','Small',N'קטנה'),
		('StickerType','','Both',N'גדול וקטן'),
		('CalibrationCycleName','',N'Temperature',N'טמפרטורה'),
		('CalibrationCycleName','',N'Set Temperature',N'טמפרטורה מכוונת'),
		('CalibrationCycleName','',N'Temperature before adjustment',N'טמפרטורה לפני כיוונון'),
		('CalibrationCycleName','',N'Temperature after adjustment',N'טמפרטורה לאחר כיוונון'),
		('CalibrationCycleName','',N'Humidity',N'לחות'),
		('CalibrationCycleName','',N'Relative humidity ',N'לחות יחסית'),
		('CalibrationCycleName','',N'Set Humidity',N'לחות מכוונת'),
		('CalibrationCycleName','',N'Humidity before adjustment',N'לחות לפני כיוונון'),
		('CalibrationCycleName','',N'Humidity after adjustment',N'לחות אחרי כיוונון'),
		('CalibrationCycleName','',N'%CO2',N'%CO2'),
		('CalibrationCycleName','',N'Set %CO2',N'%CO2 מכוון'),
		('CalibrationCycleName','',N'%CO2 after adjustment',N'%CO2 לאחר כיוון'),
		('CalibrationCycleName','',N'%CO2 before adjustment',N'%CO2 לפני כיוון'),
		('CalibrationCycleName','',N'Pressure',N'לחץ'),
		('CalibrationCycleName','',N'Recovery time after power off',N'זמן התאוששות לאחר ניתוק חשמל'),
		('CalibrationCycleName','',N'Recovery Time after * minutes Power-off',N'זמן התאוששות לאחר ניתוק חשמל למשך * דקות'),
		('CalibrationCycleName','',N'Recovery Time after door opening',N'זמן התאוששות לאחר פתיחת דלת'),
		('CalibrationCycleName','',N'Recovery Time after * minutes door opening ',N'זמן התאוששות לאחר פתיחת דלת למשך * דקות'),
		('CalibrationCycleName','',N'Cycle  No. * with load',N'מחזור מס'' * עם מטען'),
		('CalibrationCycleName','',N'Cycle  No. * without load',N'מחזור מס'' * ללא מטען'),
		('CalibrationCycleName','',N'Pressure - Cycle No. * without load',N'לחץ - מחזור מס'' * ללא מטען'),
		('CalibrationCycleName','',N'Pressure - Cycle No * with load',N'לחץ - מחזור מס'' * עם מטען'),
		('CalibrationCycleName','',N'Cycle No. * with load - F0 calculation',N'מחזור מס'' * עם מטען - חישוב F0'),
		('CalibrationCycleName','',N'Cycle No. * without load - F0 calculation',N'מחזור מס'' * ללא מטען - חישוב F0'),
		('CalibrationCycleName','',N'Cycle No. * - F0 calculation',N'מחזור מס'' *- חישוב F0'),
		('CalibrationCycleName','',N'Set Value',N'ערך נבדק'),
		('CalibrationCycleName','',N'Refrigeration Chamber',N'תא קירור'),
		('CalibrationCycleName','',N'Freezing Chamber',N'תא הקפאה')
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