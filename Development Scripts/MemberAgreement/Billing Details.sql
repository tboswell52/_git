declare @memberAgrId int = 1070089;
declare @showAgreement bit = 0;
declare @showItems bit = 0;
declare @showInvoiceRequests bit = 1;
declare @showInvoiceRequestItems bit = 0;
declare @showPaymentRequests bit = 1;
declare @showPaymentRequestItems bit = 1;


if (@showAgreement = 1)
Begin
	select * from MemberAgreement where MemberAgreementId = @memberAgrId;
End

if (@showItems = 1)
Begin
	select * from MemberAgreementItem where MemberAgreementId = @memberAgrId;
End

if (@showInvoiceRequests = 1)
Begin
	select * from MemberAgreementInvoiceRequest mair 
	where MemberAgreementId = @memberAgrId and isnull(ProcessType,0) != 1;
End

if (@showInvoiceRequestItems = 1)
Begin
	select mairi.* from MemberAgreementInvoiceRequest mair 
	inner join MemberAgreementInvoiceRequestItem mairi on mairi.MemberAgreementInvoiceRequestId = mair.MemberAgreementInvoiceRequestId
	where MemberAgreementId = @memberAgrId and isnull(ProcessType,0) != 1;
End

if (@showPaymentRequests = 1)
Begin
	select mapr.* from MemberAgreementInvoiceRequest mair 
	inner join MemberAgreementPaymentRequest mapr on mapr.MemberAgreementInvoiceRequestId = mair.MemberAgreementInvoiceRequestId
	where MemberAgreementId = @memberAgrId and isnull(mair.ProcessType,0) != 1;
End

if (@showPaymentRequestItems = 1)
Begin
	select mapri.* from MemberAgreementInvoiceRequest mair 
	inner join MemberAgreementPaymentRequest mapr on mapr.MemberAgreementInvoiceRequestId = mair.MemberAgreementInvoiceRequestId
	inner join MemberAgreementPaymentRequestItem mapri on mapr.MemberAgreementPaymentRequestId =  mapri.MemberAgreementPaymentRequestId
	where MemberAgreementId = @memberAgrId and isnull(mair.ProcessType,0) != 1;
End