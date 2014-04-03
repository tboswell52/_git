if object_id('tempdb..#m') is not null drop table #m
if object_id('tempdb..#ma') is not null drop table #ma
select 
    pr.RoleID
    ,mair.MemberAgreementID
       ,ma.BusinessUnitId
    ,ma.StartDate
    ,mair.BillDate
    ,mairi.MemberAgreementItemId         
       into #m
from
    MemberAgreementInvoiceRequest mair
    inner join MemberAgreementInvoiceRequestItem mairi on mair.MemberAgreementInvoiceRequestId = mairi.MemberAgreementInvoiceRequestId
    inner join MemberAgreement ma on mair.MemberAgreementId = ma.MemberAgreementId
    inner join PartyRole pr on ma.PartyRoleId = pr.PartyRoleID
where
    mair.BillDate >= '20140201'
and mair.BillDate < '20140301'
and isnull(processtype,0)<>1
group by 
    pr.RoleID
    ,mair.MemberAgreementID, ma.BusinessUnitId
    --,mair.MemberAgreementInvoiceRequestID
    ,mair.BillDate
    ,mairi.MemberAgreementItemId
    ,ma.StartDate
having 
    count(*) > 1


select ROW_NUMBER() OVER (Partition by MemberAgreementId order by MemberAgreementId) as row,  MemberAgreementId,
MemberAgreementInvoiceRequestId,
BillDate into #ma from (
       select mair.* from MemberAgreementInvoiceRequest mair
       inner join #m m on m.MemberAgreementId = mair.MemberAgreementId
       where isnull(ProcessType,0) != 1 and mair.TxInvoiceId is null and mair.BillDate between '2/1/2014' and '2/28/2014'
) x


select * from #ma m
inner join MemberAgreementInvoiceRequest mair on mair.MemberAgreementInvoiceRequestId = m.MemberAgreementInvoiceRequestId
where row > 1 


select * from #ma m
inner join MemberAgreementPaymentRequest mapr on mapr.MemberAgreementInvoiceRequestId = m.MemberAgreementInvoiceRequestId
where row > 1 and mapr.TxPaymentId is null


UPDATE       MemberAgreementInvoiceRequest
SET                ProcessType = 1
FROM            [#ma] AS m INNER JOIN
                         MemberAgreementInvoiceRequest ON MemberAgreementInvoiceRequest.MemberAgreementInvoiceRequestId = m.MemberAgreementInvoiceRequestId
WHERE        (row > 1)


UPDATE       MemberAgreementPaymentRequest
SET                ProcessType = 1
FROM            [#ma] AS m INNER JOIN
                         MemberAgreementPaymentRequest ON MemberAgreementPaymentRequest.MemberAgreementInvoiceRequestId = m.MemberAgreementInvoiceRequestId
WHERE        (row > 1) AND (MemberAgreementPaymentRequest.TxPaymentId IS NULL)



Terry Boswell | Director of Application Development

800.829.4321
www.motionsoft.net

