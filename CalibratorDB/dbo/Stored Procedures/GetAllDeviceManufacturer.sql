-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 15/05/2025
-- Description:	Get device manufacturer
-- JiraLink: 
-- =============================================
CREATE    PROCEDURE [dbo].[GetAllDeviceManufacturer]
@DeviceManufacturer [nvarchar](100) = NULL
AS
SELECT 
 OrdersDeviceManufacturerDescription
FROM (
VALUES
(N'A.RAVONA'),
(N'AMATEK'),
(N'AUTONICS'),
(N'BTC'),
(N'CAL'),
(N'CHINO'),
(N'DATALOGIC'),
(N'DIXELL'),
(N'ELIWELL'),
(N'EUROTHERM'),
(N'EVERYCONTROL'),
(N'GEFRAN'),
(N'HANYOUNG'),
(N'HELIS'),
(N'HONEYWELL'),
(N'INCOE'),
(N'JUMO'),
(N'LAE'),
(N'OMRON'),
(N'SHIMADEN'),
(N'SHINKO')
) ds (OrdersDeviceManufacturerDescription)
WHERE (OrdersDeviceManufacturerDescription LIKE '%'+@DeviceManufacturer+'%' OR @DeviceManufacturer IS NULL)