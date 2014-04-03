(---Fix wrong TxInvoices in Invoice Requests

--Find invoice requests with more than one associated invoice
if object_id('tempdb..#MemberAgreementInvoiceReqs') is not null drop table #MemberAgreementInvoiceReqs
if object_id('tempdb..#paymentTransactions') is not null drop table #paymentTransactions
if object_id('tempdb..#sponsorTransactions') is not null drop table #sponsorTransactions
if object_id('tempdb..#invoicesToDelete') is not null drop table #invoicesToDelete


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
select mair.* into _updatedInvoiceRequests_09_09 from MemberAgreementInvoiceRequest mair 
  inner join #invoicesToDelete i on mair.TxInvoiceId = i.TxInvoiceID
  inner join MemberAgreementPaymentRequest mapr on mapr.MemberAgreementInvoiceRequestId = mair.MemberAgreementInvoiceRequestId
  inner join MemberAgreementPaymentRequestItem mapri on mapr.MemberAgreementPaymentRequestId = mapri.MemberAgreementPaymentRequestId
  inner join TxTransaction t on mapri.TxTransactionId = t.TxTransactionID
where mapri.TxTransactionId is not null and t.LinkTypeId <> 8 and i.TxInvoiceID not in (select TxInvoiceID from #sponsorTransactions)

UPDATE       MemberAgreementInvoiceRequest
SET                TxInvoiceId = t.TxInvoiceId
FROM            MemberAgreementInvoiceRequest INNER JOIN
                         [#invoicesToDelete] AS i ON MemberAgreementInvoiceRequest.TxInvoiceId = i.TxInvoiceID INNER JOIN
                         MemberAgreementPaymentRequest AS mapr ON 
                         mapr.MemberAgreementInvoiceRequestId = MemberAgreementInvoiceRequest.MemberAgreementInvoiceRequestId INNER JOIN
                         MemberAgreementPaymentRequestItem AS mapri ON mapr.MemberAgreementPaymentRequestId = mapri.MemberAgreementPaymentRequestId INNER JOIN
                         TxTransaction AS t ON mapri.TxTransactionId = t.TxTransactionID
WHERE        (mapri.TxTransactionId IS NOT NULL) AND (t.LinkTypeId <> 8) and i.TxInvoiceID not in (select TxInvoiceID from #sponsorTransactions)

)