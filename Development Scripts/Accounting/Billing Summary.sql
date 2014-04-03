declare @localFromTime DATETIME = '6/1/2013';
declare @localToTime DATETIME = DATEADD(DAY, 1, '6/27/2013');
declare @userBusinessUnitId INT = 1;
Declare @IncludeTax int

-- convert local time to utc
DECLARE @utcFromTime DATETIME = dbo.BULocalTimeToUtc(@userBusinessUnitId, @localFromTime);
DECLARE @utcToTime DATETIME = dbo.BULocalTimeToUtc(@userBusinessUnitId, @localToTime);

Set @IncludeTax = 0 -- 1 = Include; Else don't include

/*********Terry's Changes***************/
declare @baseTable table 
(
	[MemberAgreementId] int
    ,[PartyRoleId] int
    ,[ClientAccountId] int
    ,[TxTransactionId] int
    ,[TxInvoiceId] int
    ,[GroupId] int
    ,[TxTypeId] int
    ,[BusinessUnitId] int
    ,[TargetDate] DateTime
    ,[TargetDate_UTC] DateTime
    ,[TargetDate_ZoneFormat] Varchar(5)
    ,[LinkTypeId] int
    ,[LinkId] int
    ,[Description] Varchar(max)
    ,[Amount] decimal(12, 2)
    ,[SaleItemId] int
    ,[Quantity] decimal(16,7)
    ,[UnitPrice] decimal(12,2)
    ,[TxPaymentID] int
    ,[IsPaymentDeclined] bit
    ,[TenderTypeId] int
    ,[TenderTypeName] varchar(max)
    ,[TenderInterfaceId] int
    ,[CreditCardTypeId] int
    ,[GLId] int
    ,[DueDate] DateTime
    ,[DueDate_UTC] DateTime
    ,[DueDate_ZoneFormat] varchar(5)
    ,[PaymentProcessBatchId] int
    ,[MosoPayBatchId] int 
    ,[ProcessorResponseCode] varchar(max)
    ,[ProcessorResponseMessage] varchar(max)
    ,[DeclineTxPaymentId] int
)
INSERT INTO @baseTable
SELECT *
  FROM [TransactionsFromBillingService] TXB
  WHERE((0 = 1 AND TXB.PaymentProcessBatchId is not null) OR 0 = 0)
	AND ((0 = 0 AND TXB.TargetDate_UTC >= @utcFromTime
	AND TXB.TargetDate_UTC < @utcToTime) OR (0 = 1 AND TXB.MosoPayBatchId = 0))  

declare @saletable table
(
	TxInvoiceId int,
	Amount Decimal(12,2),
	GroupId int
)
Insert into @saletable
select TxInvoiceId, Amount, GroupId from @baseTable Group by TxInvoiceId, TxTypeId, GroupId, Amount Having TxTypeId = 1

declare @taxtable table
(
	TxInvoiceId int,
	Amount Decimal(12,2),
	GroupId int
)
insert into @taxtable
select TxInvoiceId, Amount, GroupId from @baseTable Group by TxInvoiceId, TxTypeId, GroupId, Amount Having TxTypeId = 3

SELECT TOP(9223372036854775807)
MAX(BU.DivisionID) 'DivisionId',
MAX(BU.DivisionName) 'DivisionName',
MAX(BU.BusinessUnitId) 'BusinessUnitId',
MAX(BU.BUName) 'BUName',
MAX(CASE WHEN ML.PartyRoleID is null THEN OL.RoleID ELSE ML.RoleID END) as 'MemberID',
MAX(CASE WHEN ML.PartyRoleID is null THEN OL.OrganizationName ELSE ML.FirstName END)'FirstName',
MAX(CASE WHEN ML.PartyRoleID is null THEN '' ELSE ML.LastName END) 'LastName', 
TXB.TxInvoiceId 'SaleInvoiceID',
TXB.GroupId,
MAX(TXB.MemberAgreementId) 'MemberAgreementId',
MAX(TXB.TargetDate_UTC) 'BillDate',
MAX(TXB.DueDate) 'DueDate',
(select TOP(1) t.ItemID
FROM TxTransaction t
WHERE t.TxInvoiceId = TXB.TxInvoiceId
AND t.GroupId = TXB.GroupId
AND t.TxTypeId = 1) 'SaleItemId',
(select TOP(1) I.UPC
FROM TxTransaction t
JOIN Item I on t.ItemId = I.ItemID
WHERE t.TxInvoiceId = TXB.TxInvoiceId
AND t.GroupId = TXB.GroupId
AND t.TxTypeId = 1) 'SaleItemCode', 
(select TOP(1) I.Name
FROM TxTransaction t
JOIN Item I on t.ItemId = I.ItemID
WHERE t.TxInvoiceId = TXB.TxInvoiceId
AND t.GroupId = TXB.GroupId
AND t.TxTypeId = 1) 'SaleItem',
MAX(TXB.Description) as LineItem, 
MAX(CASE WHEN TXB.TxTypeId = 4 OR TXB.TxTypeId = 5 THEN TXB.TargetDate END) 'PaymentDate',
MAX(TXB.GLId) as GLId,
MAX(GL.Code) as GLCode,
MAX(GL.Description) as GLDescription, 

--MAX(CASE WHEN TXB.TxTypeId = 1 THEN TXB.GLId END) 'RevenueGLId',
SUM(CASE WHEN (TXB.TxTypeId = 1 OR TXB.TxTypeId = 3) AND TXB.Amount Is not null  THEN TXB.Amount ELSE ISNULL(s.Amount, 0) END) 'Sales',

--MAX(CASE WHEN TXB.TxTypeId = 2 THEN TXB.GLId END) 'TaxGLId',
SUM(CASE WHEN (TXB.TxTypeId = 2) And TXB.Amount is not null THEN TXB.Amount ELSE ISNULL(t.Amount, 0) END) 'Tax',

SUM(CASE WHEN TXB.TxTypeId in (1,2,3) and Txb.amount is not null THEN TXB.Amount ELSE ISNULL(s.Amount, 0) + ISNULL(t.Amount, 0) END) 'SalesTaxTotal',
--MAX(CASE WHEN TXB.TxTypeId = 4 OR TXB.TxTypeId = 5 THEN TXB.GLId END) 'TenderGLId',
MAX(TXB.TenderTypeId) 'TenderTypeId',
ISNULL(MAX(CASE WHEN TXB.TenderInterfaceId in (3,11) THEN CC.Description ELSE TXB.TenderTypeName END),'Cash') 'TenderType',
MAX(TXB.TenderInterfaceId) 'TenderTypeInterfaceId',
MAX(TXB.CreditCardTypeId) 'CreditCardTypeId',
MAX(CASE WHEN TXB.IsPaymentDeclined = 1 THEN 1 ELSE 0 END) 'IsDeclined',
SUM(CASE WHEN TXB.TxTypeId = 4 OR TXB.TxTypeId = 5 THEN TXB.Amount ELSE 0 END) 'Payment',

COUNT(
CASE 
WHEN TXB.TxTypeId = 4 AND ABS(DATEDIFF(DAY, TXB.DueDate_UTC, @utcToTime)) <= 30 THEN TXB.TxPaymentID 
END
) 'CountCurrentPayments',

SUM(
CASE 
WHEN TXB.TxTypeId = 4 AND ABS(DATEDIFF(DAY, TXB.DueDate_UTC, @utcToTime)) <= 30 --[Sharon] need to add this
--AND @IncludeTax = 1 
THEN TXB.Amount
--[Sharon] And need to find out what to do here to get this to work. 
--  WHEN @IncludeTax = 0
--  THEN 
ELSE
0.0
END
) 'SumCurrentPayments',
TXB.TxTransactionId,
COUNT(
CASE 
WHEN TXB.TxTypeId = 4 AND ABS(DATEDIFF(DAY, TXB.DueDate_UTC, @utcToTime)) > 30 THEN 
TXB.TxPaymentID 
END
) 'CountPastDuePayments',

SUM(
CASE 
WHEN TXB.TxTypeId = 4 AND ABS(DATEDIFF(DAY, TXB.DueDate_UTC, @utcToTime)) > 30 THEN
TXB.Amount
ELSE
0.0
END
) 'SumPastDuePayments'


FROM @baseTable TXB
JOIN PartyRole PR on TXB.PartyRoleId = PR.PartyRoleId
LEFT OUTER JOIN GeneralLedgerCode GL on (TXB.GLId = GL.GeneralLedgerCodeId)
LEFT OUTER JOIN rpt_BusinessUnitAndDiv BU ON (TXB.BusinessUnitId = BU.BusinessUnitId)
LEFT OUTER JOIN rpt_MemberList ML ON (PR.PartyRoleId = ML.PartyRoleId
AND PR.PartyRoleTypeId = 1) --Member Only
LEFT OUTER JOIN rpt_OrganizationList OL ON (PR.PartyRoleId = OL.PartyRoleId
AND PR.PartyRoleTypeId = 7) -- Org Only
LEFT OUTER JOIN [METAALIAS].FocusMeta.dbo.CreditCardType CC on TXB.CreditCardTypeId = CC.CreditCardTypeID 
--LEFT OUTER JOIN PartyRole PR ON (TXB.PartyRoleId = PR.PartyRoleID)
Left Outer Join @saletable s on s.TxInvoiceId = TXB.TxInvoiceId and s.GroupId = txb.GroupId
Left Outer Join @taxtable t on t.TxInvoiceId = TXB.TxInvoiceId and t.GroupId = txb.GroupId
WHERE ((0 = 1 AND TXB.PaymentProcessBatchId is not null) OR 0 = 0)
AND ((0 = 0 AND TXB.TargetDate_UTC >= @utcFromTime
AND TXB.TargetDate_UTC < @utcToTime) OR (0 = 1 AND TXB.MosoPayBatchId = 0))
AND (BU.BusinessUnitID in (15) or '15' = '-1')
AND (BU.DivisionID = -1 or -1 = -1)
AND (TXB.TenderTypeID in (-1) or '-1' = '-1')
and (ML.RoleID = '' OR '' = '' 
OR ('' = '-1' 
AND (ML.FirstName like '%%' 
OR ML.LastName like '%who%'
OR CONVERT(varchar(10), ML.RoleID) = '')))
/* 
AND (2 = 2 OR (2 = 1 AND ml.PartyRoleId in (SELECT DISTINCT PartyRoleId FROM PartyProperties pp
WHERE TypeId = -1
AND Value in (''))))
*/
AND (0 = 0 OR (0 <> 0 AND ml.PartyRoleId in (SELECT DISTINCT PartyRoleId FROM PartyProperties pp
WHERE ((-1 <> -1 
AND TypeId = -1
AND Value in (''))
OR (-1 <> -1 
AND TypeId = -1
AND ((1 = 1 AND Value like '%%') OR (1 = 2 AND Value = '')))
OR (-1 <> -1 
AND TypeId = -1
AND convert(date, Value) >= '06/26/2013' AND convert(date, Value) <= '06/27/2013')
OR (-1 <> -1 
AND TypeId = -1
AND Convert(Numeric(12,2), Value) > 0)))))


AND ((TXB.IsPaymentDeclined = 0) or ( TXB.IsPaymentDeclined = 1 AND TXB.DeclineTxPaymentId is not null) or
(TXB.IsPaymentDeclined = 1 AND TXB.DeclineTxPaymentId is null and @utcFromTime<=
(Select isnull(DPay.TargetDate_UTC,@utcFromTime) from TxPayment Pay 
inner join PaymentProcessResponse PPR on PPR.DeclineTxPaymentId = Pay.TxPaymentID
inner join PaymentProcessRequest Req on Req.PaymentProcessRequestId = PPr.PaymentProcessRequestId
inner join TxPayment DPay on DPay.TxPaymentID = req.TxPaymentId
where TXB.TxPaymentID = Pay.TxPaymentID
and DPay.TargetDate_UTC>=@utcFromTime and DPay.TargetDate_UTC<@utcToTime
))) 
GROUP BY
TXB.TxTransactionId,
TXB.TxInvoiceId,
TXB.GroupId

ORDER BY
TXB.TxInvoiceId,
TXB.GroupId