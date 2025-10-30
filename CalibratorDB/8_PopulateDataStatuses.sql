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
		('CalibrationStatuses','','MeetTheStandard',N'עומד'),
		('CalibrationStatuses','','Didn''tMeetTheStandard',N'לא עומד'),
		('CalibrationStatuses','','Stopped',N'הופסק'),
		('CalibrationStatuses','','Can''tBeDetermined',N'לא ניתן לקבוע'),
		('CalibrationStatuses','','Adjusted',N'כויל'),
		('CalibratedUnitsStatus','','Functional',N'תקין'),
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
		('OrderStatus','','QAF','QAF'),
		('OrderStatus','','Packed',N'נארז'),
		('OrderStatus', '1', 'FictitiousOrder', N'הז. פיקטיבית'),
		('OrderStatus', '-12', 'FictitiousPurchaseOrder', N'הזמנה פיקטיב'),
		('OrderStatus', '-2', 'ApprovedForExecution', N'מאושרת לבצוע'),
		('OrderStatus', '-4', 'Executed', N'בוצעה'),
		('OrderStatus', '', 'WaitingForValidation', N'ממתין לולידציה'),
		('OrderStatus', '', 'WaitingForDelivery', N'ממתין למשלוח'),
		('OrderStatus', '', 'AcceptedByCustomer', N'התקבל על ידי הלקוח'),
		('OrderStatus', '', 'Declined', N'נדחה'),
		('OrderStatus', '', 'NotAsked', N'ממתין לאישור לקוח'),
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
		('ClientConfirmationStatus','','Rejected',N'נדחה')
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