if object_id('tempdb..#I') is not null drop table #I
if object_id('tempdb..#tt') is not null drop table #tt
if object_id('tempdb..#all') is not null drop table #all

--Tender Types
select TenderTypeID into #tt from TenderType where TenderInterfaceId in (1,2);

--Get all the cash transactions
select TxInvoiceId into #I from TxTransaction t
Inner join TxPayment p on t.ItemId = p.TxPaymentID
inner join #tt tt on tt.TenderTypeID = p.TenderTypeID
where TxTypeId = 4 and t.LinkTypeId is not null

select sum(Amount * ((cast(IsAccountingCredit as int) + cast(IsAccountingCredit as int)) - 1)) as 'Amt', t.TxInvoiceId
into #all
from TxTransaction t
inner join #I i on i.TxInvoiceId = t.TxInvoiceId
group by t.TxInvoiceId

select pr.RoleID, i.TxInvoiceID, a.Amt from #all a
inner join TxInvoice i on i.TxInvoiceID = a.TxInvoiceId
inner join PartyRole pr on pr.PartyRoleID = i.PartyRoleId
where Amt > 0

