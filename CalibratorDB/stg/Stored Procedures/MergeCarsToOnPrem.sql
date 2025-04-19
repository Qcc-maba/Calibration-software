CREATE PROCEDURE stg.MergeCarsToOnPrem
AS
MERGE INTO [dbo].[Cars] AS dest
USING (
	SELECT [CarId]
		,[MabaNumber]
		,[Model]
		,[LicenseNumber]
		,[Seats]
		,[TreatmentPeriod]
		,[NextTreatmentDate]
		,[NextYearlyTestDate]
		,[OwnerId]
		,[CarStatusId]
		,[CreateDate]
		,[UpdatedDate]
		,[AssignedCalibratorId]
		,[UpdateUserID]
		,[IsDeleted]
	FROM [stg].[Cars]
	) AS source
	ON dest.AWSCarId = source.CarId
WHEN MATCHED
	THEN
		UPDATE
		SET dest.[MabaNumber] = source.[MabaNumber]
			,dest.[Model] = source.[Model]
			,dest.[LicenseNumber] = source.[LicenseNumber]
			,dest.[Seats] = source.[Seats]
			,dest.[TreatmentPeriod] = source.[TreatmentPeriod]
			,dest.[NextTreatmentDate] = source.[NextTreatmentDate]
			,dest.[NextYearlyTestDate] = source.[NextYearlyTestDate]
			,dest.[OwnerId] = source.[OwnerId]
			,dest.[CarStatusId] = source.[CarStatusId]
			,dest.[CreateDate] = source.[CreateDate]
			,dest.[UpdatedDate] = source.[UpdatedDate]
			,dest.[AssignedCalibratorId] = source.[AssignedCalibratorId]
			,dest.[UpdateUserID] = source.[UpdateUserID]
			,dest.[IsDeleted] = source.[IsDeleted]
WHEN NOT MATCHED BY TARGET
	THEN
		INSERT (
			 [MabaNumber]
			,[Model]
			,[LicenseNumber]
			,[Seats]
			,[TreatmentPeriod]
			,[NextTreatmentDate]
			,[NextYearlyTestDate]
			,[OwnerId]
			,[CarStatusId]
			,[CreateDate]
			,[UpdatedDate]
			,[AssignedCalibratorId]
			,[UpdateUserID]
			,[IsDeleted]
			,[AWSCarId]
			)
		VALUES (
             source.[MabaNumber]
			,source.[Model]
			,source.[LicenseNumber]
			,source.[Seats]
			,source.[TreatmentPeriod]
			,source.[NextTreatmentDate]
			,source.[NextYearlyTestDate]
			,source.[OwnerId]
			,source.[CarStatusId]
			,source.[CreateDate]
			,source.[UpdatedDate]
			,source.[AssignedCalibratorId]
			,source.[UpdateUserID]
			,source.[IsDeleted]
			,source.[CarId]
			);