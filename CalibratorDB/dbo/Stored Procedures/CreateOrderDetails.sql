-- =============================================
-- Author:		Eduard Kudlaiev
-- Create date: 27/02/2026
-- Description:	Procedure to add new order detail
-- JiraLink: 
-- =============================================

CREATE   PROCEDURE dbo.CreateOrderDetails
(
      @OrderWorkPlanId          INT
    , @KLINE                    INT 
    , @PART                     INT 
	, @LoggedInUserEmail        NVARCHAR(100) 
    -- Data fields
    , @SpecialCareTypeId        INT = NULL
    , @IsInHouse                INT 
    , @PartName                 NVARCHAR(22) = NULL
    , @VPRICE                   DECIMAL(18,2) = NULL
    , @PRICE                    DECIMAL(18,2) = NULL
    , @OrderLineCnt             INT = NULL
    , @IsDeleted                BIT = NULL
    , @IsCancelled              BIT = NULL
    , @OrdersProductTypeId      INT = NULL
    , @ActualCalibrationDate    DATE = NULL
    , @MainCategoryId           INT = NULL
    , @SecondaryCategoryId      INT = NULL
    , @CalibratorId             INT = NULL
    , @CustomerPackingExists    BIT = NULL
    , @CustomerSiteId           INT = NULL
    , @PackageLocation          NVARCHAR(20) = NULL
)
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE @LoggedInUserId INT 
	DECLARE @SourceId TINYINT

	SELECT 
	 @LoggedInUserId  = d.UserId 
	,@SourceId = d.SourceId
	FROM dbo.GetSourceFilterByEmail(@LoggedInUserEmail) as d


        IF EXISTS
        (
            SELECT 1
            FROM dbo.OrderDetails od WITH (UPDLOCK, HOLDLOCK)
            WHERE od.OrderWorkPlanId = @OrderWorkPlanId
              AND od.KLINE = @KLINE
              AND od.PART  = @PART
        )
               UPDATE od
               SET od.SpecialCareTypeId     = COALESCE(@SpecialCareTypeId, od.SpecialCareTypeId)
                 , od.IsInHouse             = COALESCE(@IsInHouse, od.IsInHouse)
                 , od.PartName              = COALESCE(@PartName, od.PartName)
                 , od.KLINE                 = COALESCE(@KLINE, od.KLINE) -- key column, remains same in this pattern
                 , od.VPRICE                = COALESCE(@VPRICE, od.VPRICE)
                 , od.PRICE                 = COALESCE(@PRICE, od.PRICE)
                 , od.OrderLineCnt          = COALESCE(@OrderLineCnt, od.OrderLineCnt)
                 , od.UpdatedDate           = SYSDATETIME()
                 , od.UpdateUserID          = COALESCE(@LoggedInUserId, od.UpdateUserID)
                 , od.IsDeleted             = COALESCE(@IsDeleted, od.IsDeleted)
                 , od.IsCancelled           = COALESCE(@IsCancelled, od.IsCancelled)
                 , od.OrdersProductTypeId   = COALESCE(@OrdersProductTypeId, od.OrdersProductTypeId)
                 , od.PART                  = COALESCE(@PART, od.PART)   -- key column, remains same in this pattern
                 , od.ActualCalibrationDate = COALESCE(@ActualCalibrationDate, od.ActualCalibrationDate)
                 , od.MainCategoryId        = COALESCE(@MainCategoryId, od.MainCategoryId)
                 , od.SecondaryCategoryId   = COALESCE(@SecondaryCategoryId, od.SecondaryCategoryId)
                 , od.CalibratorId          = COALESCE(@CalibratorId, od.CalibratorId)
                 , od.CustomerPackingExists = COALESCE(@CustomerPackingExists, od.CustomerPackingExists)
                 , od.CustomerSiteId        = COALESCE(@CustomerSiteId, od.CustomerSiteId)
                 , od.PackageLocation       = COALESCE(@PackageLocation, od.PackageLocation)
             FROM dbo.OrderDetails od
            WHERE od.OrderWorkPlanId = @OrderWorkPlanId
              AND od.KLINE = @KLINE
              AND od.PART  = @PART;

        ELSE 
        INSERT INTO dbo.OrderDetails
        (
              OrderWorkPlanId
            , SpecialCareTypeId
            , IsInHouse
            , PartName
            , KLINE
            , VPRICE
            , PRICE
            , OrderLineCnt
            , CreatedDate
            , UpdatedDate
            , CreatedByUserId
            , IsDeleted
            , IsCancelled
            , OrdersProductTypeId
            , PART
            , ActualCalibrationDate
            , MainCategoryId
            , SecondaryCategoryId
            , CalibratorId
            , CustomerPackingExists
            , CustomerSiteId
            , PackageLocation
        )
        VALUES
        (
              @OrderWorkPlanId
            , @SpecialCareTypeId
            , @IsInHouse
            , @PartName
            , @KLINE
            , @VPRICE
            , @PRICE
            , @OrderLineCnt
            , GETDATE()
            , NULL
            , @LoggedInUserId
            , 0
            , @IsCancelled
            , @OrdersProductTypeId
            , @PART
            , @ActualCalibrationDate
            , @MainCategoryId
            , @SecondaryCategoryId
            , @CalibratorId
            , @CustomerPackingExists
            , @CustomerSiteId
            , @PackageLocation
        );

        SELECT OrderWorkPlanId,OrderDetailId
        FROM dbo.OrderDetails
        WHERE OrderWorkPlanId = @OrderWorkPlanId
          AND KLINE = @KLINE AND PART = @PART 

END