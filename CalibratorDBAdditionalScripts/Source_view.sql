
CREATE OR ALTER  VIEW [dbo].[vwGetOrders_WorkPlan_Full_new]
AS

WITH CalibStatuses
AS
(
  SELECT 
  l.DOC,
  s.STATCODE,
  IIF(l.CDATE > 0,DATEADD(n, l.CDATE, CAST('01/01/1988' AS datetime2)),NULL) as StatusDate,
  ROW_NUMBER() OVER (PARTITION BY l.DOC ORDER BY l.CDATE DESC) AS CurrentStatus,
  ROW_NUMBER() OVER (PARTITION BY l.DOC ORDER BY IIF(s.STATCODE = N'CO',l.CDATE,NULL) DESC) AS ReceivedStatus
  FROM dbo.MBA_CALIBSTATSLOG as l
  JOIN dbo.MBA_CALIBSTATUSES AS s ON l.CALIBSTATUSES = s.CALIBSTATUSES 
  JOIN dbo.DOCUMENTS as d ON l.DOC = d.DOC
  WHERE d.CURDATE > (DATEDIFF(n, '1988-01-01', GETDATE())-36000) 
),
orderdata
as
(
SELECT 
	o.ORD AS SourceOrderId,
	oi.ORDI AS OrderDetailId,
	IIF(o.CURDATE > 0,DATEADD(n, o.CURDATE, '1988-01-01'),NULL) as OpenDate,
	o.ORDSTATUS,
	o.ORDNAME,
	o.CUST,
	oi.VPRICE,
	oi.PRICE,
	COALESCE(oi.TQUANT,0)/1000 as OrderLineCnt,
	o.SHIPTYPE as ShipType,
	system.dbo.tabula_hebconvert(COALESCE(spt.STDES,'')) as ShipTypeDesc,
	pt.PART,
	pt.PARTNAME AS PartName,
	system.dbo.tabula_hebconvert(COALESCE(pt.PARTDES,'')) AS DeviceType
FROM dbo.ORDERITEMS as oi
JOIN dbo.ORDERS as o ON oi.ORD = o.ORD 
JOIN dbo.SHIPTYPES as spt ON o.SHIPTYPE = spt.SHIPTYPE
LEFT JOIN dbo.PART as pt ON oi.PART = pt.PART
--WHERE o.ORDNAME = 'LA25105884'--'LA25105871'
WHERE o.CURDATE > (DATEDIFF(n, '1988-01-01', GETDATE())-24000) 
AND o.ORDSTATUS IN (-2,1)--filter requested by Eliran 20/01/2025
),
descrdata
as
(
SELECT
    svc.SERN,
    mbastc.KLINE,
    pt.PARTTYPE,
	doc.DOC,
	DATEADD(n, tro.CURDATE, '1988-01-01') as OpenDate,
	tro.TQUANT/1000 as OrderLineCnt,
    IIF(svc.AENDDATE > 1,DATEADD(n, svc.AENDDATE, '01/01/1988'),NULL) AS CalibDate,
    cc.CUST AS CustomerSourceId,
	sn.SERNUM as SerialNumber,
    sn.FREE1 as AdditionalDeviceNumber,
	sn.FREE2 as ManufacturerNumber,
	system.dbo.tabula_hebconvert(COALESCE(mbasn.MODEL,'')) as Devicemodel,
	system.dbo.tabula_hebconvert(COALESCE(dp.DEPTDES,'')) as MainCategorySourceId,
	system.dbo.tabula_hebconvert(COALESCE(mbasn.SERNDES,'')) as SecondCategorySourceId,
	pt.PART,
	pt.PARTNAME AS PartName,
	system.dbo.tabula_hebconvert(COALESCE(pt.PARTDES,'')) AS DeviceType,
	mbad.MBANUM AS MbaReportNumber,
	system.dbo.tabula_hebconvert(COALESCE(mnf.MNFDES,'')) as OrdersDeviceManufacturer,
	tro.VPRICE as VPRICE,
	tro.PRICE as PRICE,
	IIF(LEN(TRIM(LTRIM(sn.LOCATION))) =0,NULL,TRIM(LTRIM(system.dbo.tabula_hebconvert(COALESCE(sn.LOCATION,''))))) as ProductLocation,
    IIF(doc.MBA_CUSTPACK = N'Y',1,0) as CustomerPackingExists,
    IIF(doc.MBA_LTDATA > 0, DATEADD(minute,doc.MBA_LTDATA, '1988-01-01'),NULL) AS ActualReturnDate,
    IIF(doc.MBA_CALRETDATE > 0, DATEADD(minute,doc.MBA_CALRETDATE, '1988-01-01'),NULL) AS ExpectedReturnDate,
    IIF(LEN(l.LORRYDES) > 0,l.LORRYDES,NULL) as PackageLocation,
    IIF(doc.MBA_NEXTCALIBDATE > 0,dateadd(n,doc.MBA_NEXTCALIBDATE, '1988-01-01'),NULL) as NextCalibrationDate,
    Docs2.DOCNO as ShippingDoc,
    CONCAT(
    system.dbo.tabula_hebconvert(COALESCE(dst.ADDRESS,'')),' ',	
    system.dbo.tabula_hebconvert(COALESCE(dst.STATE,'')),' ',
    system.dbo.tabula_hebconvert(COALESCE(dst.ZIP,''))) as ShippingAddress,
    mbad.DOC_N,
    IIF(doc.DESTCODE = 0 , NULL, doc.DESTCODE) as DESTCODE,
	tro.ORDI as OrderDetailId
FROM dbo.MBA_SERNTRANSCALL as mbastc
JOIN amaba.dbo.SERNTRANS as srtr ON  mbastc.SERN = srtr.SERN 
								and mbastc.KLINE = srtr.KLINE  
								and mbastc.TYPE = srtr.TYPE AND mbastc.TYPE = 'N'
								and mbastc.DOC = srtr.DOC 
JOIN dbo.DOCUMENTS as doc  on  doc.DOC = mbastc.CALL AND doc.TYPE = 'Q'
JOIN dbo.MBA_DOCUMENTS as mbadoc on  mbadoc.DOC = doc.DOC 
JOIN dbo.SERVCALLS as svc ON doc.DOC = svc.DOC
JOIN dbo.CUSTOMERS as cc ON doc.CUST = cc.CUST
JOIN dbo.SERNUMBERS as sn ON svc.SERN = sn.SERN 
JOIN dbo.MBA_SERNUMBERS as mbasn ON sn.SERN = mbasn.SERN
JOIN dbo.PART as pt ON svc.PART = pt.PART
JOIN dbo.MNFCTR as mnf ON mbasn.MNF = mnf.MNF
JOIN dbo.MBA_DOCUMENTS as mbad ON doc.DOC = mbad.DOC 
JOIN dbo.DOCUMENTS AS Docs2 ON mbad.DOC_D = Docs2.DOC 
JOIN dbo.DOCUMENTS AS Docs3 ON mbad.DOC_N = Docs3.DOC 
JOIN dbo.MBA_PART as mbp ON mbp.PART = pt.PART
JOIN dbo.DEPT as dp ON mbp.DEPT = dp.DEPT
JOIN dbo.TRANSORDER as tro ON tro.DOC = mbad.DOC_N AND svc.PART = tro.PART AND mbastc.KLINE = tro.KLINE 
LEFT JOIN dbo.LORRIES as l ON doc.LORRY = l.LORRY
LEFT JOIN dbo.DESTCODES as dst ON doc.DESTCODE = dst.DESTCODE 
WHERE srtr.CURDATE > (DATEDIFF(n, '1988-01-01', GETDATE())-48000) AND srtr.CURDATE <= (DATEDIFF(n, '1988-01-01', GETDATE())) 
)
SELECT
	orddata.SourceOrderId,
	orddata.OrderDetailId,
	orddata.ORDSTATUS,
    descr.SERN,
    descr.KLINE,
    descr.PARTTYPE,
	orddata.ORDNAME,
	descr.DOC,
	COALESCE(orddata.OpenDate,descr.OpenDate) as OpenDate,
	COALESCE(orddata.OrderLineCnt,descr.OrderLineCnt) as OrderLineCnt,
    descr.CalibDate,
    COALESCE(orddata.CUST,descr.CustomerSourceId) AS CustomerSourceId,
	descr.SerialNumber,
    descr.AdditionalDeviceNumber,
	descr.ManufacturerNumber,
	descr.Devicemodel,
	NULL AS SpecialCareTypeId,
	NULL AS InHouse,
	descr.MainCategorySourceId,
	descr.SecondCategorySourceId,
	COALESCE(orddata.PART,descr.PART) as PART,
	COALESCE(orddata.PartName,descr.PartName) as PartName,
	COALESCE(orddata.DeviceType,descr.DeviceType) as DeviceType,
	descr.MbaReportNumber,
	COALESCE(NULLIF(orddata.VPRICE,0),descr.VPRICE) as VPRICE,
	COALESCE(NULLIF(orddata.PRICE,0),descr.PRICE) as PRICE,
	descr.ProductLocation,
    descr.CustomerPackingExists,
    descr.ActualReturnDate,
    descr.ExpectedReturnDate,
    descr.PackageLocation,
	orddata.ShipType,
	orddata.ShipTypeDesc,
    descr.NextCalibrationDate,
    calst1.STATCODE AS CurrentCalibrationStatus,
    IIF(calst2.STATCODE = N'CO',calst2.StatusDate, NULL) AS CustomerReceivingDate,
    descr.ShippingDoc,
    descr.ShippingAddress,
    descr.DOC_N,
    descr.DESTCODE,
	descr.OrdersDeviceManufacturer
FROM orderdata as orddata
LEFT JOIN descrdata as descr ON orddata.OrderDetailId = descr.OrderDetailId
LEFT JOIN CalibStatuses as calst1 ON descr.DOC = calst1.DOC AND calst1.CurrentStatus = 1
LEFT JOIN CalibStatuses as calst2 ON descr.DOC = calst2.DOC AND calst2.ReceivedStatus = 1
GO


