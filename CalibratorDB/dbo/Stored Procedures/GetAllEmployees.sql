-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 17/03/2025
-- Description:	This SP should return a list of all company employees
-- JiraLink: https://calibration-maba.atlassian.net/browse/MABA-168
-- =============================================
CREATE   PROCEDURE [dbo].[GetAllEmployees]
    @PageNumber AS INT = 1,                  -- Resulting page for pagination, starting in 1
    @RowsOfPage AS INT = 5000,                 -- Result page size
    @OrderBy AS NVARCHAR(MAX) = 'Email',      -- OrderBy column
    @OrderByAsc AS BIT = 1,                  -- OrderBy direction (ASC/DESC)
    -- Filter parameters (all nullable)
	@FirstName NVARCHAR(255) = NULL,
    @LastName NVARCHAR(255) = NULL,
	@Phone NVARCHAR(20) =  NULL,
	@Address NVARCHAR(200) = NULL,
    @LocationArea NVARCHAR(200) = NULL,
	@Email NVARCHAR(50) = NULL,
    @UserRole NVARCHAR(50)  = NULL,
	@UserStatus NVARCHAR(50) = NULL,-- not ready
	@Department NVARCHAR(50) = NULL,
	@Certification NVARCHAR(MAX) = NULL
AS
BEGIN

	IF @OrderBy NOT IN 
	(N'FirstName', N'LastName', N'FirstNameEng', N'LastNameEng', N'Phone', N'Email', N'UserAddress', N'LocationArea', N'UserRoleENG', N'UserRoleHEB', N'DepartmentName', N'Certification')
	THROW 51000, 'Incorrect value for parameter @OrderBy. Available values FirstName|LastName|FirstNameEng|LastNameEng|Phone|Email|UserAddress|LocationArea|UserRoleENG|UserRoleHEB|DepartmentName|Certification', 1;


	IF @FirstName IS NOT NULL OR @LastName IS NOT NULL 
	BEGIN
	DROP TABLE IF EXISTS #UserFullName
	CREATE TABLE #UserFullName
	(
	UserId INT
	)
	INSERT #UserFullName(UserId)
	SELECT u.ID FROM [dbo].[Users] as u 
	WHERE u.IsActive = 1
		  AND (
			u.LastName LIKE '%'+@LastName+'%' 
			OR u.LastNameEng LIKE '%'+@LastName+'%'
	) and u.ID > 0
	UNION ALL
		SELECT u.ID FROM [dbo].[Users] as u 
	WHERE u.IsActive = 1
		  AND (
			u.FirstName LIKE '%'+@FirstName+'%'
			OR u.FirstNameEng LIKE '%'+@FirstName+'%'
	) and u.ID > 0
	END

DECLARE @sql NVARCHAR(MAX) =
CONCAT(
'
SELECT u.ID,
	   u.FirstName,
	   u.LastName,
	   u.FirstNameEng,
	   u.LastNameEng,
	   u.Phone,
	   u.Email,
	   u.UserAddress,
	   u.LocationArea,
	   ur.UserRoleENG,	
	   ur.UserRoleHEB,
	   d.DepartmentName,
	   cc.Certification,
	   NULL as UserStatus,
	   NULL as UserStatusIds,
	   u.DepartmentId,
	   ur.UserRoleIds,
	   cc.CertificationIds,
	   u.Stamp,
	   u.Password,
	   u.IsActive,
	   COUNT(1) OVER(PARTITION BY 1 ORDER BY u.ID ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING ) as ItemsCount
FROM [dbo].[Users] as u
'
,IIF(@FirstName IS NOT NULL OR @LastName IS NOT NULL,' JOIN #UserFullName  as f ON u.ID =  f.UserId',' '),
'
',IIF(@UserRole IS NULL,' LEFT ',' '),' JOIN
(
SELECT utr.UserId, 
       STRING_AGG(ur.UserRoleId,'','') as UserRoleIds,
	   STRING_AGG(LTRIM(RTRIM(ur.UserRoleDescriptionENG)),'', '') AS UserRoleENG,	
	   STRING_AGG(LTRIM(RTRIM(ur.UserRoleDescriptionHEB)),'', '') AS UserRoleHEB
FROM [dbo].[UsersToUserRoles] as utr 
JOIN [dbo].[UserRoles] as ur ON utr.UserRoleId = ur.UserRoleId
WHERE utr.IsDeleted = 0 ',IIF(@UserRole IS NULL,' ',CONCAT(' AND ur.UserRoleDescriptionENG LIKE N''%', @UserRole ,'%'' ')),'
GROUP BY utr.UserId
) AS ur ON u.ID = ur.UserId
LEFT JOIN [dbo].[Departments] as d ON u.DepartmentId = d.ID
',IIF(@Certification IS NULL,' LEFT ',' '),' JOIN
(
SELECT ctc.CalibratorId as UserId,
	   STRING_AGG(cc.ID,'','') as CertificationIds,
	   STRING_AGG(cc.Certificate,'','') as Certification
FROM [dbo].[CalibratorsToCertification] as ctc
JOIN [dbo].[CalibratorsCertifications] as cc ON ctc.CertificationId = cc.ID AND cc.IsDeleted = 0
WHERE ctc.IsDeleted = 0
'
,IIF(@Certification IS NULL,' ',CONCAT(' AND cc.Certificate LIKE N''%', @Certification ,'%'' ')),
'
GROUP BY ctc.CalibratorId
) as cc ON u.ID = cc.UserId
WHERE u.ID > 0 
'
,CASE WHEN @Phone IS NOT NULL THEN ' AND u.Phone LIKE N''%'+ @Phone +'%'' 'ELSE ' ' END
,CASE WHEN @Department IS NOT NULL THEN ' AND d.DepartmentName  LIKE N''%'+ @Department +'%'' 'ELSE ' ' END
,CASE WHEN @Address IS NOT NULL THEN ' AND u.UserAddress LIKE N''%'+ @Address +'%'' 'ELSE ' ' END
,CASE WHEN @LocationArea IS NOT NULL THEN ' AND u.LocationArea LIKE N''%'+ @LocationArea +'%'' 'ELSE ' ' END
,CASE WHEN @Email IS NOT NULL THEN ' AND u.Email LIKE N''%'+ @Email +'%'' 'ELSE ' ' END
,  'ORDER BY ' , QUOTENAME(@OrderBy) , CASE WHEN @OrderByAsc = 1 THEN ' ASC' ELSE ' DESC' END , '
OFFSET ',(@PageNumber -1) * @RowsOfPage,' ROWS FETCH NEXT ', @RowsOfPage ,'ROWS ONLY OPTION(RECOMPILE); ')
PRINT @sql
EXEC sp_executesql @sql


END