-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 24/03/2025
-- Description:	This SP should add MeasurementDevicesCorrections
-- JiraLink: 
-- =============================================
CREATE   PROCEDURE dbo.CreateMeasurementDevicesCorrectionsRecord
	@Value1 [decimal](25, 15),
	@Value2 [decimal](25, 15) = NULL,
	@Deviation [decimal](35, 15) = NULL,
	@Note [varchar](300) = NULL,
	@MeasurementDeviceId [int],
	@MeasurementId [int],
	@UnitID [int],
	@DateAdded [datetime] = NULL,
	@CorVersion [int],
	@DepartmentId [int] = NULL,
	@Equation [varchar](300)

/*
EXEC [dbo].[CreateMeasurementDevicesCorrectionsRecord] 
   @Value1 = 10.044444444
  ,@Value2 = 1
  ,@Deviation = 0.3333333333333
  ,@Note =N'Test'
  ,@MeasurementDeviceId = 1
  ,@MeasurementId = 1
  ,@UnitID = 1
  ,@DateAdded = '2025-03-24 10:47:01.317'
  ,@CorVersion = 0
  ,@DepartmentId = 4
  ,@Equation = 'x * (0.0)  + 0.0'
*/

AS
BEGIN

SET NOCOUNT ON;


IF NOT EXISTS(
SELECT 1 FROM [dbo].MeasurementDevices WHERE ID = @MeasurementDeviceId
)
THROW 51000, 'Incorrect MeasurementDeviceId value provided.', 1;


IF NOT EXISTS(
SELECT 1 FROM [dbo].Measurements WHERE ID = @MeasurementId
)
THROW 51000, 'Incorrect Measurement value provided.', 1;

IF NOT EXISTS(
SELECT 1 FROM [dbo].Units WHERE ID = @UnitID
)
THROW 51000, 'Incorrect UnitID value provided.', 1;

IF NOT EXISTS(
SELECT 1 FROM dbo.Departments WHERE ID = @DepartmentId
)
THROW 51000, 'Incorrect DepartmentId value provided.', 1;


INSERT INTO [dbo].[MeasurementDevicesCorrections]
           ([Value1]
           ,[Value2]
           ,[Deviation]
           ,[Note]
           ,[MeasurementDevicesId]
           ,[MeasurementId]
           ,[UnitID]
           ,[DateAdded]
           ,[CorVersion]
           ,[DepartmentId]
           ,[Equation])
     VALUES
           (@Value1
           ,@Value2
           ,@Deviation
           ,@Note
           ,@MeasurementDeviceId
           ,@MeasurementId
           ,@UnitID
           ,@DateAdded
           ,@CorVersion
           ,@DepartmentId
           ,@Equation
		   )
END

