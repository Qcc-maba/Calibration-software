# CalibratorDB — Entity Relationship Diagram

```mermaid
erDiagram

    %% ─────────────────────────────────────────
    %% REFERENCE / LOOKUP
    %% ─────────────────────────────────────────
    StatusesCategories {
        int StatusCategoryId PK
        nvarchar Name
    }
    Statuses {
        int StatusId PK
        int StatusCategoryId FK
        nvarchar StatusName_EN
        nvarchar StatusName_HE
    }
    UserRoles {
        int UserRoleId PK
        nvarchar RoleName
    }
    Source {
        int SourceId PK
        nvarchar SourceName
    }
    OrdersProductTypes {
        int OrdersProductTypeId PK
        nvarchar ProductTypeName
    }

    StatusesCategories ||--o{ Statuses : "categorises"

    %% ─────────────────────────────────────────
    %% USERS & DEPARTMENTS
    %% ─────────────────────────────────────────
    Users {
        int ID PK
        int UserRoleId FK
        int PositionId FK
        int SourceId FK
        nvarchar Email
        nvarchar FullName
        bit IsActive
    }
    MainCategories {
        int ID PK
        nvarchar CategoryName
    }
    SecondaryCategories {
        int ID PK
        int MainCategoryId FK
        nvarchar CategoryName
    }
    UsersToDepartments {
        int UserId PK_FK
        int MainCategoryId PK_FK
        datetime2 CreatedDate PK
    }
    MainToSecondaryCategories {
        int MainCategoryId PK_FK
        int SecondaryCategoryId PK_FK
    }

    UserRoles     ||--o{ Users                   : "role"
    Statuses      ||--o{ Users                   : "position"
    Source        ||--o{ Users                   : "source"
    Users         ||--o{ UsersToDepartments      : "belongs to"
    MainCategories||--o{ UsersToDepartments      : "department"
    MainCategories||--o{ SecondaryCategories     : "parent"
    MainCategories||--o{ MainToSecondaryCategories : "maps"
    SecondaryCategories||--o{ MainToSecondaryCategories : "maps"

    %% ─────────────────────────────────────────
    %% CUSTOMERS
    %% ─────────────────────────────────────────
    Customers {
        int CustomerId PK
        int SourceId FK
        int CustomerSupportContactId FK
        nvarchar CustomerName
    }
    CustomerContacts {
        int CustomerId PK_FK
        int CustomerContactId PK
        int SourceId FK
        nvarchar ContactName
    }
    CustomerSites {
        int CustomerSiteId PK
        int CustomerId PK_FK
        int SourceId FK
        nvarchar SiteName
    }
    CustomerRemarks {
        int CustomerId PK_FK
        int SourceId FK
        nvarchar Remarks
    }

    Source    ||--o{ Customers        : "source"
    Users     ||--o{ Customers        : "support contact"
    Customers ||--o{ CustomerContacts : "has"
    Customers ||--o{ CustomerSites    : "has"
    Customers ||--|{ CustomerRemarks  : "has"

    %% ─────────────────────────────────────────
    %% MEASUREMENT DEVICES (EQUIPMENT)
    %% ─────────────────────────────────────────
    MeasurementDevicesMainClasses {
        int Id PK
        nvarchar ClassName
    }
    MeasurementDevicesSubClass {
        int ID PK
        nvarchar SubClassName
    }
    MeasurementDeviceUnits {
        int MeasurementDeviceUnitId PK
        int MainCategoryId FK
        nvarchar UnitName
    }
    Measurements {
        int ID PK
        int MainCategoryId FK
        nvarchar MeasurementName
    }
    MeasurementsToMeasurmentUnits {
        int MeasurementId PK_FK
        int MeasurementDeviceUnitId PK_FK
    }
    MeasurementDevices {
        int ID PK
        int MainCategoryId FK
        int SecondaryCategoryId FK
        int MainClassId FK
        int SubClassId FK
        int MeasurementId FK
        int UnitId FK
        int CalibratorId FK
        int SourceId FK
        int MeasurementDeviceStatusId FK
        nvarchar SerialNumber
        nvarchar Model
    }
    MeasurementDevicesCorrections {
        int ID PK
        int MeasurementDevicesId FK
        int MeasurementId FK
        int MainCategoryId FK
        int UnitID FK
    }
    SensorToLoggerRelation {
        int LoggerMeasurementDeviceId PK_FK
        int SensorMeasurementDeviceId PK_FK
        datetime2 CreateDate PK
    }
    MeasurementsSpecifications {
        int ID PK
        int MainCategoryId FK
        nvarchar SpecName
    }
    MeasurementsSpecificationsToSecondCategory {
        int MeasurementsSpecificationId PK_FK
        int SecondaryCategoryId PK_FK
        datetime2 CreateDate PK
    }
    SpecificationReference {
        int ID PK
        int SecondaryCategoryId FK
        nvarchar RefName
    }

    MainCategories             ||--o{ MeasurementDeviceUnits                      : "unit category"
    MainCategories             ||--o{ Measurements                                : "category"
    MainCategories             ||--o{ MeasurementDevices                          : "category"
    SecondaryCategories        ||--o{ MeasurementDevices                          : "subcategory"
    MeasurementDevicesMainClasses ||--o{ MeasurementDevices                       : "class"
    MeasurementDevicesSubClass ||--o{ MeasurementDevices                          : "subclass"
    Measurements               ||--o{ MeasurementDevices                          : "measurement type"
    MeasurementDeviceUnits     ||--o{ MeasurementDevices                          : "unit"
    Statuses                   ||--o{ MeasurementDevices                          : "status"
    Source                     ||--o{ MeasurementDevices                          : "source"
    Users                      ||--o{ MeasurementDevices                          : "assigned calibrator"
    MeasurementDevices         ||--o{ MeasurementDevicesCorrections               : "corrections"
    MeasurementDevices         ||--o{ SensorToLoggerRelation                      : "as logger"
    MeasurementDevices         ||--o{ SensorToLoggerRelation                      : "as sensor"
    Measurements               ||--o{ MeasurementsToMeasurmentUnits              : ""
    MeasurementDeviceUnits     ||--o{ MeasurementsToMeasurmentUnits              : ""
    MainCategories             ||--o{ MeasurementsSpecifications                  : "category"
    MeasurementsSpecifications ||--o{ MeasurementsSpecificationsToSecondCategory  : ""
    SecondaryCategories        ||--o{ MeasurementsSpecificationsToSecondCategory  : ""
    SecondaryCategories        ||--o{ SpecificationReference                      : "has"

    %% ─────────────────────────────────────────
    %% FLEET (CARS)
    %% ─────────────────────────────────────────
    Cars {
        int CarId PK
        int CarStatusId FK
        int AssignedCalibratorId FK
        int OwnerId FK
        int SourceId FK
        nvarchar LicensePlate
    }
    CarDowntimePeriodHistory {
        int CarId PK_FK
        datetime2 DateOfChange PK
        int StatusId FK
    }
    CarsToEquipment {
        int MeasurementDeviceId PK_FK
        int CarId PK_FK
        datetime2 CreatedDate PK
    }

    Statuses           ||--o{ Cars                   : "status"
    Source             ||--o{ Cars                   : "source"
    Users              ||--o{ Cars                   : "assigned calibrator"
    Cars               ||--o{ CarDowntimePeriodHistory : "history"
    Cars               ||--o{ CarsToEquipment        : "carries"
    MeasurementDevices ||--o{ CarsToEquipment        : "loaded on"

    %% ─────────────────────────────────────────
    %% ORDER WORKFLOW (CORE)
    %% ─────────────────────────────────────────
    OrderWorkPlans {
        int OrderWorkPlanId PK
        int CustomerId FK
        int OrderStatusId FK
        int OrderOverallStatusId FK
        int ClientConfirmationStatusId FK
        int SourceId FK
        nvarchar OrderNumber
        date PlannedDate
    }
    OrderDetails {
        int OrderWorkPlanId PK_FK
        int OrderDetailId PK
        int MainCategoryId FK
        int SecondaryCategoryId FK
        int OrdersProductTypeId FK
        int CalibratorId FK
        int SpecialCareTypeId FK
        bit IsDeleted
        bit IsCancelled
    }
    OrderDetailsItems {
        int OrderDetailId PK_FK
        int OrderDetailsItemId PK
        int CalibrationStatusId FK
        int CalibrationReportStatusId FK
        int StickerTypeId FK
        int MainCalibratorId FK
        int SecondCalibratorId FK
        int MeasurementUnitId FK
        int CalibrationSpecificationId FK
        int SpecificationReferenceId FK
        nvarchar SerialNumber
    }
    OrderItemsStatusesHistory {
        int OrderDetailsItemId PK_FK
        datetime2 CreatedDate PK
        int StatusId FK
        int StatusCategoryId FK
    }

    Customers          ||--o{ OrderWorkPlans          : "orders"
    Source             ||--o{ OrderWorkPlans          : "source"
    Statuses           ||--o{ OrderWorkPlans          : "order status"
    OrderWorkPlans     ||--o{ OrderDetails            : "contains"
    MainCategories     ||--o{ OrderDetails            : "category"
    SecondaryCategories||--o{ OrderDetails            : "subcategory"
    OrdersProductTypes ||--o{ OrderDetails            : "product type"
    Statuses           ||--o{ OrderDetails            : "special care"
    Users              ||--o{ OrderDetails            : "calibrator"
    OrderDetails       ||--o{ OrderDetailsItems       : "items"
    Statuses           ||--o{ OrderDetailsItems       : "calib status"
    MeasurementDeviceUnits ||--o{ OrderDetailsItems   : "unit"
    MeasurementsSpecifications ||--o{ OrderDetailsItems : "spec"
    SpecificationReference     ||--o{ OrderDetailsItems : "spec ref"
    Users              ||--o{ OrderDetailsItems       : "main calibrator"
    OrderDetailsItems  ||--o{ OrderItemsStatusesHistory : "status trail"
    Statuses           ||--o{ OrderItemsStatusesHistory : "status"
    StatusesCategories ||--o{ OrderItemsStatusesHistory : "category"

    %% ─────────────────────────────────────────
    %% ORDER ASSIGNMENTS
    %% ─────────────────────────────────────────
    CalibratorsToWorkPlan {
        int OrderWorkPlanId PK_FK
        int CalibratorId PK_FK
        int CalibratorsToWorkPlanId PK
        int CarId FK
        date AssignedDate
    }
    CarsToOrder {
        datetime2 AssignDate PK
        int OrderWorkPlanId PK_FK
        int CarId PK_FK
        datetime2 CreatedDate PK
    }
    MeasurementDevicesToOrderHeaders {
        int OrderWorkPlanId PK_FK
        int MeasurementDeviceId PK_FK
        int MeasurementDevicesToOrderHeadersId PK
        int CarId FK
    }

    OrderWorkPlans     ||--o{ CalibratorsToWorkPlan          : "calibrators"
    Users              ||--o{ CalibratorsToWorkPlan          : "calibrator"
    Cars               ||--o{ CalibratorsToWorkPlan          : "car"
    OrderWorkPlans     ||--o{ CarsToOrder                    : "cars"
    Cars               ||--o{ CarsToOrder                    : "car"
    OrderWorkPlans     ||--o{ MeasurementDevicesToOrderHeaders : "equipment"
    MeasurementDevices ||--o{ MeasurementDevicesToOrderHeaders : "device"
    Cars               ||--o{ MeasurementDevicesToOrderHeaders : "car"

    %% ─────────────────────────────────────────
    %% CALIBRATION PROCESS
    %% ─────────────────────────────────────────
    CalibrationCycles {
        int OrderDetailsItemId PK_FK
        datetime2 CalibrationCycleStartDate PK
        int CalibrationCycleStatusId FK
        int UnitId FK
    }
    CalibrationEnvironmentalConditions {
        int OrderDetailsItemId PK_FK
        int MeasurementDeviceUnitId PK_FK
        decimal Temperature
        decimal Humidity
    }
    CalibrationProcessComments {
        int OrderDetailsItemId PK_FK
        int CalibrationProcessCommentId PK
        varbinary CommentData
    }
    MeasurmentDeviceToOrderDetailsItems {
        int OrderDetailsItemId PK_FK
        int LoggerMeasurementDeviceId PK_FK
        int SensorMeasurementDeviceId PK_FK
        int MeasurmentDeviceToOrderDetailsItemId PK
        int PrimaryMeasurmentUnitId FK
        int SecondaryMeasurmentUnitId FK
    }
    MeasurmentPointsToOrderDetailsItems {
        int OrderDetailsItemId PK_FK
        int SensorMeasurementDeviceId PK_FK
        int ChannelNumber PK
        int MeasurmentPointsToOrderDetailsItemId PK
        int MasterValueUnitId FK
        int AdditionalValueUnitId FK
    }
    AdditionalEquipmentForOrderDetailsItems {
        int OrderDetailsItemId PK_FK
        int AdditionalEquipmentForOrderDetailsItemsId PK
    }

    OrderDetailsItems ||--o{ CalibrationCycles                     : "cycles"
    Statuses          ||--o{ CalibrationCycles                     : "cycle status"
    MeasurementDeviceUnits ||--o{ CalibrationCycles                : "unit"
    OrderDetailsItems ||--o{ CalibrationEnvironmentalConditions    : "conditions"
    MeasurementDeviceUnits ||--o{ CalibrationEnvironmentalConditions : "unit"
    OrderDetailsItems ||--o{ CalibrationProcessComments            : "comments"
    OrderDetailsItems ||--o{ MeasurmentDeviceToOrderDetailsItems   : "devices used"
    MeasurementDevices||--o{ MeasurmentDeviceToOrderDetailsItems   : "logger"
    MeasurementDevices||--o{ MeasurmentDeviceToOrderDetailsItems   : "sensor"
    MeasurementDeviceUnits ||--o{ MeasurmentDeviceToOrderDetailsItems : "primary unit"
    OrderDetailsItems ||--o{ MeasurmentPointsToOrderDetailsItems   : "meas points"
    MeasurementDevices||--o{ MeasurmentPointsToOrderDetailsItems   : "sensor"
    MeasurementDeviceUnits ||--o{ MeasurmentPointsToOrderDetailsItems : "unit"
    OrderDetailsItems ||--o{ AdditionalEquipmentForOrderDetailsItems : "extra equip"

    %% ─────────────────────────────────────────
    %% PACKING / SHIPPING
    %% ─────────────────────────────────────────
    PackingBox {
        int PackingBoxId PK
        nvarchar BoxLabel
    }
    PackingBoxToOrderDetailsItems {
        int OrderDetailsItemId PK_FK
        int PackingBoxId PK_FK
        datetime2 CreateDate PK
    }

    PackingBox        ||--o{ PackingBoxToOrderDetailsItems : "contains"
    OrderDetailsItems ||--o{ PackingBoxToOrderDetailsItems : "packed in"

    %% ─────────────────────────────────────────
    %% CALIBRATOR MANAGEMENT
    %% ─────────────────────────────────────────
    CalibratorsAvailability {
        int UserId PK_FK
        date AvailbilityDateFrom PK
        date AvailbilityDateTo
        int AvailabilityStatusId FK
    }
    CalibratorCertificationAuthorities {
        int ID PK
        int MainCategoryId FK
        nvarchar AuthorityName
    }
    CalibratorsToCertificationAuthoritiesAuthorities {
        int CalibratorCertificationAuthorityId PK_FK
        int CalibratorId PK_FK
        datetime2 CreatedDate PK
    }
    CalibratorNotifications {
        int NotificationId PK
        int CalibratorId FK
        int CreateUserId FK
        int NotificationTypeId FK
        int OrderWorkPlanId FK
    }
    CalibratorWorkstationSettings {
        int CalibratorWorkstationSettingId PK
        int CalibratorId FK
    }
    COMPortSettings {
        int CalibratorWorkstationSettingId PK_FK
        int COMPortSettingId PK
    }

    Users              ||--o{ CalibratorsAvailability                           : "availability"
    Statuses           ||--o{ CalibratorsAvailability                           : "status"
    MainCategories     ||--o{ CalibratorCertificationAuthorities                : "category"
    CalibratorCertificationAuthorities ||--o{ CalibratorsToCertificationAuthoritiesAuthorities : "certifies"
    Users              ||--o{ CalibratorsToCertificationAuthoritiesAuthorities  : "calibrator"
    OrderWorkPlans     ||--o{ CalibratorNotifications                           : "triggers"
    Users              ||--o{ CalibratorNotifications                           : "recipient"
    Statuses           ||--o{ CalibratorNotifications                           : "type"
    Users              ||--o{ CalibratorWorkstationSettings                     : "workstation"
    CalibratorWorkstationSettings ||--o{ COMPortSettings                        : "ports"

    %% ─────────────────────────────────────────
    %% CALENDAR
    %% ─────────────────────────────────────────
    CalendarEvents {
        int CalendarEventId PK
        int EventTypeId FK
        datetime2 EventDate
        nvarchar Title
    }
    CalendarEventsToParticipants {
        int CalendarEventId PK_FK
        int UserId PK_FK
        datetime2 CreatedDate PK
    }

    Statuses      ||--o{ CalendarEvents                 : "event type"
    CalendarEvents||--o{ CalendarEventsToParticipants   : "participants"
```
