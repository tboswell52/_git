if object_id('tempdb..#problems') is not null drop table #problems

select mai.MemberAgreementId, Maips.PaymentInstallments  + 1 as InstallmentCount /**Initial + 1*/, (select count(*) from MemberAgreementPaymentRequest maprX
	inner join MemberAgreementInvoiceRequest mairX on mairX.MemberAgreementInvoiceRequestId = maprX.MemberAgreementInvoiceRequestId
	Where maprX.ProcessType is null and mairX.MemberAgreementInvoiceRequestId = mair.MemberAgreementInvoiceRequestId) as CalcCount
into #problems
from MemberAgreementInvoiceRequest mair
	inner join MemberAgreementInvoiceRequestItem mairi on mair.MemberAgreementInvoiceRequestId = mairi.MemberAgreementInvoiceRequestId
	inner join MemberAgreementItem mai on mai.MemberAgreementItemId = mairi.MemberAgreementItemId
	inner join MemberAgreementItemPaySource maips on maips.MemberAgreementItemId = mai.MemberAgreementItemId
where maips.PaymentInstallments is not null and maips.PaymentInstallments > 1 and
	Maips.PaymentInstallments + 1 /**Initial + 1*/ < (select count(*) from MemberAgreementPaymentRequest maprX
	inner join MemberAgreementInvoiceRequest mairX on mairX.MemberAgreementInvoiceRequestId = maprX.MemberAgreementInvoiceRequestId
	Where maprX.ProcessType is null and mairX.MemberAgreementInvoiceRequestId = mair.MemberAgreementInvoiceRequestId)

/*************See the problem agreements and counts
select * from #problems

**************************************/

/************ See the problem Requests
select * from MemberAgreementPaymentRequest
	where MemberAgreementInvoiceRequestId in
		(select MemberAgreementInvoiceRequestId from 
			MemberAgreementInvoiceRequest where MemberAgreementId in (select memberAgreementId from #problems)) and ProcessType is null
*/

/************ Remove the problems

UPDATE       MemberAgreementPaymentRequest
SET                ProcessType = 1
WHERE        (MemberAgreementInvoiceRequestId IN
                             (SELECT        MemberAgreementInvoiceRequestId
                               FROM            MemberAgreementInvoiceRequest
                               WHERE        ( MemberAgreementId in (select memberAgreementId from #problems))
							   )) AND (ProcessType IS NULL) AND (TxPaymentId IS NULL)

*/
