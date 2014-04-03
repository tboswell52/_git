
if object_id('tempdb..#dups') is not null drop table #dups
if object_id('tempdb..#removes') is not null drop table #removes
select MemberAgreementInvoiceRequestId, DueDate_UTC, ProcessType 
	into #dups
	from MemberAgreementPaymentRequest 
group By  MemberAgreementInvoiceRequestId, DueDate_UTC, ProcessType
having count(MemberAgreementInvoiceRequestId) <> 1 and ProcessType is null

select Rank() over (Partition by d.MemberAgreementInvoiceRequestId order by [Status], MemberAgreementPaymentRequestId) as Position, MemberAgreementPaymentRequestId, TxPaymentId 
	into #removes
from MemberAgreementPaymentRequest mapr
	inner join #dups d on d.MemberAgreementInvoiceRequestId = mapr.MemberAgreementInvoiceRequestId

select * into _MarkedAsDelete10_2 from #removes where TxPaymentId is null

UPDATE       MemberAgreementPaymentRequest
SET                ProcessType = 1
FROM            [#removes] AS r INNER JOIN
                         MemberAgreementPaymentRequest ON 
                         r.MemberAgreementPaymentRequestId = MemberAgreementPaymentRequest.MemberAgreementPaymentRequestId
WHERE        (Position = 1) AND (r.TxPaymentId IS NULL)