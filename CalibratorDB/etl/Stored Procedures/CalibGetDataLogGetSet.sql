CREATE  PROCEDURE [etl].[CalibGetDataLogGetSet]
@TableName [NVARCHAR](255),
@LastExecutionDate DATETIME2(0) = NULL
AS
SET NOCOUNT ON;
IF NOT EXISTS (SELECT 1 FROM [etl].[CalibGetDataLog] WHERE [TableName] = @TableName)
INSERT [etl].[CalibGetDataLog]([TableName],LastExecutionDate)
VALUES(@TableName,'1900-01-01')

IF EXISTS (SELECT 1 FROM [etl].[CalibGetDataLog] WHERE [TableName] = @TableName) and @LastExecutionDate IS NOT NULL
UPDATE [etl].[CalibGetDataLog]
SET LastExecutionDate = @LastExecutionDate
WHERE [TableName] = @TableName

SELECT LastExecutionDate
FROM [etl].[CalibGetDataLog]
WHERE [TableName] = @TableName