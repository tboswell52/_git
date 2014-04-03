select mapri.* into #activePaymentRequestItems from MemberAgreementPaymentRequestItem  mapri
inner join MemberAgreementInvoiceRequestItem mairi on mapri.MemberAgreementInvoiceRequestItemId = mairi.MemberAgreementInvoiceRequestItemId
inner join MemberAgreementPaymentRequest mapr on mapri.MemberAgreementPaymentRequestId = mapr.MemberAgreementPaymentRequestId
where isnull(mapr.ProcessType,0) != 1


select mapri.* into #allPaymentRequestItems from MemberAgreementPaymentRequestItem  mapri
inner join MemberAgreementPaymentRequest mapr on mapri.MemberAgreementPaymentRequestId = mapr.MemberAgreementPaymentRequestId
where isnull(mapr.ProcessType,0) != 1
--where MemberAgreementInvoiceRequestItemId = 5316582


select * into #itemsToRemove from #allPaymentRequestItems
except
select * from #activePaymentRequestItems

DELETE FROM MemberAgreementPaymentRequestItem
FROM            [#itemsToRemove] AS i INNER JOIN
                         MemberAgreementPaymentRequestItem ON MemberAgreementPaymentRequestItem.MemberAgreementPaymentRequestItemId = i.MemberAgreementPaymentRequestItemId