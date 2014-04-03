declare @memberAgreementId int = 5620;

select StartDate from MemberAgreement where MemberAgreementId = @memberAgreementId

select * from Activity where TxTransactionId in (
select TxTransactionID from TxTransaction where TxInvoiceId in (
	select TxInvoiceId from MemberAgreementInvoiceRequest where MemberAgreementId in (
	select MemberAgreementId from MemberAgreement
	where MemberAgreementId = @memberAgreementId
) and TxInvoiceId is not null and Status = 2

))

select * from MemberAgreementInvoiceRequest where MemberAgreementId in (
	select MemberAgreementId from MemberAgreement
	where MemberAgreementId = @memberAgreementId
) and TxInvoiceId is not null and Status = 2

