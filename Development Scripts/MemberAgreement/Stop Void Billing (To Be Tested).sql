if object_id('tempdb..#Payments') is not null drop table #Payments
if object_id('tempdb..#Invoices') is not null drop table #Invoices
if object_id('tempdb..#InvWithBal') is not null drop table #InvWithBal
select * into #payments from TxPayment p where IsMultiInvoice = 1 



select * 
into #Invoices
from (
select distinct i.TxInvoiceID,i.PartyRoleID, pr.RoleID, pr.CreatedDate, p.Amount from #payments p
inner join TxTransaction t on p.TxPaymentID = t.ItemId and t.TxTypeId = 4
inner join TxInvoice i on t.TxInvoiceId = i.TxInvoiceID
inner join PartyRole pr on pr.PartyRoleID = i.PartyRoleId

) t

--select * from #Invoices


select 
#Invoices.PartyRoleID,
#Invoices.RoleID,
#Invoices.TxInvoiceID,


#Invoices.CreatedDate,
#invoices.Amount,
null as Balance
Into #InvWithBal
from #Invoices
--left join Txtransaction tx on tx.TxinvoiceId = #Invoices.TxInvoiceID


--group by #Invoices.txInvoiceID,RoleID, CreatedDate, #Invoices.Amount


UPdate #InvWithBal
set Balance = 

   (  Select   
    Sum(CASE TX.IsAccountingCredit     
     WHEN 0 THEN TX.Amount    
     ELSE -TX.Amount    
    END    )
from txTransaction tx
where tx.TxinvoiceId = #InvWithBal.txInvoiceId
Group By Tx.TxInvoiceId
   ) 


select mair.ProcessType from #InvWithBal i
inner join TxInvoice tx on i.TxInvoiceID = tx.TxInvoiceID
inner join MemberAgreementInvoiceRequest mair on mair.MemberAgreementInvoiceRequestId = tx.LinkId and tx.LinkTypeId = 4
where tx.LinkTypeId is not null


select mapr.ProcessType from #InvWithBal i
inner join TxInvoice tx on i.TxInvoiceID = tx.TxInvoiceID
inner join MemberAgreementInvoiceRequest mair on mair.MemberAgreementInvoiceRequestId = tx.LinkId and tx.LinkTypeId = 4
inner join MemberAgreementPaymentRequest mapr on mapr.MemberAgreementInvoiceRequestId = mair.MemberAgreementInvoiceRequestId
where tx.LinkTypeId is not null and mapr.ProcessType is null 


UPDATE       MemberAgreementInvoiceRequest
SET                ProcessType = 1
FROM            [#InvWithBal] AS i INNER JOIN
                         TxInvoice AS tx ON i.TxInvoiceID = tx.TxInvoiceID INNER JOIN
                         MemberAgreementInvoiceRequest ON MemberAgreementInvoiceRequest.MemberAgreementInvoiceRequestId = tx.LinkId AND tx.LinkTypeId = 4
WHERE        (tx.LinkTypeId IS NOT NULL)


UPDATE       MemberAgreementPaymentRequest
SET                ProcessType = 1
FROM            [#InvWithBal] AS i INNER JOIN
                         TxInvoice AS tx ON i.TxInvoiceID = tx.TxInvoiceID INNER JOIN
                         MemberAgreementInvoiceRequest AS mair ON mair.MemberAgreementInvoiceRequestId = tx.LinkId AND tx.LinkTypeId = 4 INNER JOIN
                         MemberAgreementPaymentRequest ON MemberAgreementPaymentRequest.MemberAgreementInvoiceRequestId = mair.MemberAgreementInvoiceRequestId
WHERE        (tx.LinkTypeId IS NOT NULL) AND (MemberAgreementPaymentRequest.ProcessType IS NULL)








Terry Boswell | Director of Application Development

800.829.4321
www.motionsoft.net

