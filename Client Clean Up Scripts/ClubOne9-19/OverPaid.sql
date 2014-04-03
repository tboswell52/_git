--select * from TxTransaction where TxInvoiceId = 421555

if object_id('tempdb..#NoLinkTypeId') is not null drop table #NoLinkTypeId
if object_id('tempdb..#HeeBeeJeeBees') is not null drop table #HeeBeeJeeBees
if object_id('tempdb..#Due') is not null drop table #Due
if object_id('tempdb..#Paid') is not null drop table #Paid


select TxInvoiceId into #NoLinkTypeId from TxTransaction t where t.LinkTypeId is null and t.TxTypeId = 4 and t.IsAccountingCredit = 1 	


select t.* into #HeeBeeJeeBees from TxTransaction t
	inner join #NoLinkTypeId n on n.TxInvoiceId = t.TxInvoiceId
 Where LinkTypeId is not null and TxTypeId = 4 


 select T.TxInvoiceId, sum(t.Amount) as DueAmount into #Due from TxTransaction t
	inner join #HeeBeeJeeBees h on h.TxInvoiceId = t.TxInvoiceId
	Group by T.TxInvoiceId, t.IsAccountingCredit
	having t.IsAccountingCredit = 0

 select T.TxInvoiceId, sum(t.Amount) as PaidAmount into #Paid from TxTransaction t
	inner join #HeeBeeJeeBees h on h.TxInvoiceId = t.TxInvoiceId
	Group by T.TxInvoiceId, t.IsAccountingCredit
	having t.IsAccountingCredit = 1

select pr.RoleID, chars.[First Name], chars.[Last Name], t.TxInvoiceID, t.TargetDate, bu.Name from #Due d
inner join #Paid p on p.TxInvoiceId = d.TxInvoiceId
inner join TxInvoice t on t.TxInvoiceID = p.TxInvoiceId
inner join ClientAccount ca on ca.ClientAccountId = t.ClientAccountId
inner join ClientAccountParty cap on cap.ClientAccountId = ca.ClientAccountId
inner join ReportingMemberCharacteristics chars on cap.PartyId = chars.PartyId
inner join BusinessUnit bu on t.TargetBusinessUnitId = bu.BusinessUnitId
inner join PartyRole pr on chars.PartyRoleId = pr.PartyRoleID
where d.DueAmount < p.PaidAmount and cap.PrimaryParty = 1 order by TargetDate

select pr.RoleID, Coalesce(chars.[First Name], ochars.[Organization Name]), chars.[Last Name], t.TxInvoiceID, t.TargetDate, bu.Name from #Due d
inner join #Paid p on p.TxInvoiceId = d.TxInvoiceId
inner join TxInvoice t on t.TxInvoiceID = p.TxInvoiceId
inner join ClientAccount ca on ca.ClientAccountId = t.ClientAccountId
inner join ClientAccountParty cap on cap.ClientAccountId = ca.ClientAccountId
Left join ReportingMemberCharacteristics chars on cap.PartyId = chars.PartyId
Left Join ReportingOrganizationCharacteristics oChars on oChars.PartyId = cap.PartyId
inner join BusinessUnit bu on t.TargetBusinessUnitId = bu.BusinessUnitId
Left join PartyRole pr on cap.PartyId = pr.PartyID
where d.DueAmount < p.PaidAmount and cap.PrimaryParty = 1 order by TargetDate


SELECT        ca.ClientAccountId, count(*)
FROM            [#Due] AS d INNER JOIN
                         [#Paid] AS p ON p.TxInvoiceId = d.TxInvoiceId INNER JOIN
                         TxInvoice AS t ON t.TxInvoiceID = p.TxInvoiceId INNER JOIN
                         ClientAccount AS ca ON ca.ClientAccountId = t.ClientAccountId
WHERE        (d.DueAmount < p.PaidAmount)
GROUP BY ca.ClientAccountId




 
