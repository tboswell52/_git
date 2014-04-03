--select * from TxInvoice where TxInvoiceID in (932487, 1022945, 1030708)

--select * from TxTransaction where TxInvoiceId = 1022945
drop table #FirstPass;
drop table #SecondPass;
drop table #ThirdPass;
drop table #ForthPass;
drop table #CachedArAging;

select * into #FirstPass from TxInvoice where TxInvoiceID in (
select i.TxInvoiceID from TxTransaction tx
Inner Join TxInvoice i on tx.TxInvoiceId = i.TxInvoiceID
where TxTypeId = 4 and IsAccountingCredit = 0 and Description like '%VISA%')

Select i.PartyRoleId into #SecondPass from TxInvoice i 
inner join TxTransaction t on t.TxInvoiceId = i.TxInvoiceID
inner join #FirstPass f on f.TxInvoiceID = i.TxInvoiceID
group by i.PartyRoleId, t.TxTypeId, t.IsAccountingCredit
having t.TxTypeId = 4 and t.IsAccountingCredit = 0 and count(*) > 1;

Select pr.RoleId, t.TxInvoiceId, i.BillingStatus, i.TxInvoiceStatusId, t.Description, t.LinkTypeId 
 into #ThirdPass
 from TxInvoice i 
inner join TxTransaction t on t.TxInvoiceId = i.TxInvoiceID
inner join #FirstPass f on f.TxInvoiceID = i.TxInvoiceID
inner join #SecondPass s on s.PartyRoleId = i.PartyRoleId
inner join PartyRole pr on pr.PartyRoleID = s.PartyRoleId
inner join MemberAgreement ma on pr.PartyRoleID = ma.PartyRoleId
where t.TxTypeId = 4 and t.IsAccountingCredit = 0 and Description not like '%Sponsor%' and ma.Status = 5 
order by RoleId

select RoleID 
into #ForthPass
from #ThirdPass
group by RoleId
having count(*) > 1

Create Table #CachedArAging
(
	BusinessUnitId int NOT NULL,
	ClientAccountId int NOT NULL,
	PartyId int NOT NULL,
	MemberAgreementId int NULL,
	PartyRoleId int NOT NULL,
	AgingCurrent Decimal(12,2) NOT NULL,
	Aging30 Decimal(12,2) NOT NULL,
	Aging60 Decimal(12,2) NOT NULL,
	Aging90 Decimal(12,2) NOT NULL,
	Aging120 Decimal(12,2) NOT NULL,
	AgingOver120 Decimal(12,2) NOT NULL,
	TotalDue Decimal(12,2) NOT NULL,
	TotalPastDue Decimal(12,2) NOT NULL,
	AcctCredit Decimal(12,2) NULL
)

Insert #CachedArAging
EXEC	ARAging_SP
		@cutoffTimeLocal = '1/10/2014',
		@businessUnitId = null,
		@partyId = NULL,
		@clientAccountId = NULL


select distinct t.* from #ThirdPass t
inner join #ForthPass f on f.RoleID = t.RoleID
inner join PartyRole pr on pr.RoleID = t.RoleID
inner join #CachedArAging c on c.PartyRoleId = pr.PartyRoleID
where pr.PartyRoleTypeID = 1 and c.TotalPastDue > 1



