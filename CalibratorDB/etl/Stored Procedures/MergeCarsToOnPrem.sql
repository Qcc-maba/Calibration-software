CREATE PROCEDURE [etl].[MergeCarsToOnPrem]
AS
SELECT 1
/*
MERGE INTO [dbo].[Cars] AS dest
USING (
	SELECT 
	     c.[CarId]
		,c.[MabaNumber]
		,c.[Model]
		,c.[LicenseNumber]
		,c.[Seats]
		,c.[TreatmentPeriod]
		,c.[NextTreatmentDate]
		,c.[NextYearlyTestDate]
		,u.ID as [OwnerId]
		,c.[CarStatusId]
		,c.[CreateDate]
		,c.[UpdatedDate]
		,u1.ID as[AssignedCalibratorId]
		,0 as [UpdateUserID]
		,c.[IsDeleted]
	FROM [etl].[Cars] as c
	LEFT JOIN [dbo].[Users] as u ON c.[OwnerId] = u.AWSID
	LEFT JOIN [dbo].[Users] as u1 ON c.[AssignedCalibratorId] = u1.AWSID
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
*/