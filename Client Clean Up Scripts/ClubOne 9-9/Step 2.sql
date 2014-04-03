---Fix wrong TxInvoices in Invoice Requests

--Find invoice requests with more than one associated invoice
if object_id('tempdb..#MemberAgreementInvoiceReqs') is not null drop table #MemberAgreementInvoiceReqs
if object_id('tempdb..#paymentTransactions') is not null drop table #paymentTransactions
if object_id('tempdb..#sponsorTransactions') is not null drop table #sponsorTransactions
if object_id('tempdb..#invoicesToDelete') is not null drop table #invoicesToDelete
if object_id('tempdb..#txUpdate') is not null drop table #txUpdate


    select pr.RoleID  --636 rows
      , invreq.MemberAgreementInvoiceRequestId
   , invreq.MemberAgreementId
      , [InvoiceCount] = count(*) 
   into #MemberAgreementInvoiceReqs
   from TxInvoice inv
inner join MemberAgreementInvoiceRequest invreq on invreq.MemberAgreementInvoiceRequestId = inv.LinkId
inner join MemberAgreement ma on ma.MemberAgreementId = invreq.MemberAgreementId
inner join PartyRole pr on pr.PartyRoleID = ma.PartyRoleId
  where inv.LinkTypeId in (4)
    and inv.TargetDate between '9/1/2013' and '9/30/2013'
  group by pr.RoleID
         , invreq.MemberAgreementInvoiceRequestId
   , invreq.MemberAgreementId
    having count(*) > 1

select * into #sponsorTransactions from TxTransaction  where TxInvoiceId in (
  select inv.TxInvoiceID
     from TxInvoice inv
  inner join #MemberAgreementInvoiceReqs invreq on invreq.MemberAgreementInvoiceRequestId = inv.LinkId and inv.LinkTypeId = 4)
  and TxTypeId = 4 and LinkTypeId = 8


--Find invoices
select inv.TxInvoiceId
  into #invoicesToDelete
   from TxInvoice inv
inner join #MemberAgreementInvoiceReqs invreq on invreq.MemberAgreementInvoiceRequestId = inv.LinkId and inv.LinkTypeId = 4


----------Problems in which the MemberAgreementInvoiceRequest points to the wrong txInvoiceId
select mairi.* into _updatedInvoiceRequestItems_09_09 from MemberAgreementInvoiceRequest mair 
  inner join MemberAgreementInvoiceRequestItem mairi on mairi.MemberAgreementInvoiceRequestId = mair.MemberAgreementInvoiceRequestId
  inner join #invoicesToDelete i on mair.TxInvoiceId = i.TxInvoiceID
  inner join TxTransaction t on t.TxInvoiceId = i.TxInvoiceID 
where t.TxTypeId = 1 and t.TxTransactionID <> mairi.TxTransactionId and i.TxInvoiceID not in (select TxInvoiceID from #sponsorTransactions)


select mairi.MemberAgreementInvoiceRequestItemId, t.TxTransactionID into #txUpdate from MemberAgreementInvoiceRequest mair 
  inner join MemberAgreementInvoiceRequestItem mairi on mairi.MemberAgreementInvoiceRequestId = mair.MemberAgreementInvoiceRequestId
  inner join #invoicesToDelete i on mair.TxInvoiceId = i.TxInvoiceID
  inner join TxTransaction t on t.TxInvoiceId = i.TxInvoiceID 
where t.TxTypeId = 1 and t.TxTransactionID <> mairi.TxTransactionId and i.TxInvoiceID not in (select TxInvoiceID from #sponsorTransactions)


UPDATE       MemberAgreementInvoiceRequestItem
SET                TxTransactionId = t.TxTransactionId
FROM            MemberAgreementInvoiceRequestItem INNER JOIN
                         [#txUpdate] AS t ON MemberAgreementInvoiceRequestItem.MemberAgreementInvoiceRequestItemId = t.MemberAgreementInvoiceRequestItemId



