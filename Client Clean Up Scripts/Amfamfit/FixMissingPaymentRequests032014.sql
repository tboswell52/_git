------******************Gather the list into a temp table
select r.roleid, ma.memberagreementid, ma.startdate, mair.BillDate, mair.MemberAgreementInvoiceRequestId, mair.TxInvoiceId, mair.PrimaryTxInvoiceId
	into #tmp
from MemberAgreement ma, partyrole r, MemberAgreementInvoiceRequest mair
where ma.PartyRoleId=r.PartyRoleId
and mair.MemberAgreementId=ma.MemberAgreementId
and mair.BillDate>='20140301'
and mair.BillDate<='20140401'
and isnull(mair.processtype,0)<>1
and ma.Status = 5
and not exists
(select *
	from MemberAgreementPaymentRequest mapr
	where mapr.MemberAgreementInvoiceRequestId=mair.MemberAgreementInvoiceRequestId
	and isnull(mapr.processtype,0)<>1
)


select memberagreementid, RoleID 
into #finalSet
from #tmp
 where memberagreementid not in (
	select memberagreementid from (
	select m.memberagreementid from #tmp m
	inner join MemberAgreementItem mai on mai.MemberAgreementId = m.memberagreementid
	inner join MemberAgreementItemPerpetual maip on maip.MemberAgreementItemId = mai.MemberAgreementItemId
	where maip.Price = 0 ) x
	group by memberagreementid
union
	select memberagreementid from (
	select m.memberagreementid from #tmp m
	inner join MemberAgreementItem mai on mai.MemberAgreementId = m.memberagreementid
	inner join MemberAgreementItemPaySource maip on maip.MemberAgreementItemId = mai.MemberAgreementItemId
	where
		---100%sponsor
		(FromForeign = 1 and PaymentValue = 1)
	) x
	group by memberagreementid
union
	select MemberAgreementid from (
		select * from #tmp m
		inner join Cancellation c on c.EntityId = m.MemberAgreementId and c.EntityIdType = 1
		where c.Date < '04/1/2014'
	) x
	group by MemberAgreementId
union 
	select MemberAgreementId from #tmp t -------*******Zero dollar invoices
		where (select sum(Amount) from TxTransaction where TxInvoiceId = t.TxInvoiceId) = 0	
) 
group by memberagreementid, RoleID


select t.* 
into _missingPaymentRequests032014
from #tmp t
inner join #finalSet f on t.MemberAgreementId = f.MemberAgreementId

---*****************Null out the invoices and marked the process type as do not process
UPDATE       MemberAgreementInvoiceRequest
SET                TxInvoiceId = null, PrimaryTxInvoiceId = null, ProcessType = 1
FROM            MemberAgreementInvoiceRequest INNER JOIN
                         _missingPaymentRequests032014 AS mx ON mx.memberagreementid = MemberAgreementInvoiceRequest.MemberAgreementId AND CONVERT(Date, mx.BillDate) = CONVERT(Date, 
                         MemberAgreementInvoiceRequest.BillDate)
WHERE        (ISNULL(MemberAgreementInvoiceRequest.ProcessType, 0) <> 1)

-----*************Build the script to run sync, change the mtp box date, and run the script ***********WE CANNOT BATCH THEM DUE TO THE ISSUE WITH DATE TIME OVER NETWORK

Select 'Moso.TaskProcessor.exe /syncSchedule /businessUnitIds ' + convert(varchar(max),BusinessUnitId) +   ' /memAgrIds ' + convert(varchar(max), MemberAgreementId)  from (
select distinct BusinessUnitId, ma.MemberAgreementId
  from _missingPaymentRequests032014 m inner join MemberAgreement ma on ma.MemberAgreementId = m.memberagreementid
  where ma.MemberAgreementId not in (
	select m.memberagreementid from _missingPaymentRequests032014 m
	inner join Cancellation c on c.EntityId = m.memberagreementid and c.EntityIdType = 1
	where c.Date < '20140401'
  )	
) x order by BusinessUnitId

---*****************Undo Null out the invoices and marked the process type as do not process

declare @oldReqId int;
declare @newReqId int;
declare @maId int;
declare FixCursor Cursor for
		  select memberagreementid from _missingPaymentRequests032014 		  
		  --where MemberAgreementid not in (164972, 343016)
Open FixCursor;

Fetch Next from FixCursor Into @maId;

WHILE (@@fetch_status <> -1) 

	BEGIN
	
		
		select @newReqId = mair.MemberAgreementInvoiceRequestId
		from MemberAgreementInvoiceRequest mair 
		inner join _missingPaymentRequests032014 AS mx ON mx.memberagreementid = mair.MemberAgreementId AND CONVERT(Date, mx.BillDate) = CONVERT(Date, 
								 mair.BillDate)
		where mx.MemberAgreementId = @maId and (ISNULL(mair.ProcessType, 0) <> 1);

		select @oldReqId = mair.MemberAgreementInvoiceRequestId
		from MemberAgreementInvoiceRequest mair 
		inner join _missingPaymentRequests032014 AS mx ON mx.memberagreementid = mair.MemberAgreementId AND CONVERT(Date, mx.BillDate) = CONVERT(Date, 
								 mair.BillDate)
		where mx.MemberAgreementId = @maId and (ISNULL(mair.ProcessType, 0) = 1);

		------****************Update the Invoice Requests TxInvoiceIds
		--select TxInvoiceId,  (
		--	select TxInvoiceId from _missingPaymentRequests032014 old
		--	 where old.MemberAgreementInvoiceRequestId = @oldReqId
		--) as OldTxInvoiceId
		--, PrimaryTxInvoiceId
		--, (
		--	select TxInvoiceId from _missingPaymentRequests032014 old
		--	 where old.MemberAgreementInvoiceRequestId = @oldReqId
		--) oldPrimaryTx from MemberAgreementInvoiceRequest 
		--where MemberAgreementInvoiceRequestId = @newReqId

		update MemberAgreementInvoiceRequest set TxInvoiceId =  (
			select TxInvoiceId from _missingPaymentRequests032014 old
			 where old.MemberAgreementInvoiceRequestId = @oldReqId
		)
		, PrimaryTxInvoiceId =(
			select TxInvoiceId from _missingPaymentRequests032014 old
			 where old.MemberAgreementInvoiceRequestId = @oldReqId
		) from MemberAgreementInvoiceRequest 
		where MemberAgreementInvoiceRequestId = @newReqId

		------****************Update the Invoice Requests Items TxTransaction Ids
		--select oldItems.TxTransactionId, newItems.TxTransactionId, newItems.MemberAgreementInvoiceRequestItemId 
		--from MemberAgreementInvoiceRequestItem oldItems
		--	inner join MemberAgreementInvoiceRequestItem newItems on oldItems.MemberAgreementItemId = newItems.MemberAgreementItemId
		--where oldItems.MemberAgreementInvoiceRequestId = @oldReqId and newItems.MemberAgreementInvoiceRequestId = @newReqId;

		update newItems set newItems.TxTransactionId = oldItems.TxTransactionId
		from MemberAgreementInvoiceRequestItem oldItems
			inner join MemberAgreementInvoiceRequestItem newItems on oldItems.MemberAgreementItemId = newItems.MemberAgreementItemId
		where oldItems.MemberAgreementInvoiceRequestId = @oldReqId and newItems.MemberAgreementInvoiceRequestId = @newReqId;



		------****************Update the TxInvoice Link Ids
		--select i.LinkId, @newReqId from TxInvoice i
		--where i.LinkId = @oldReqId and i.LinkTypeId = 4

		update i set i.LinkId = @newReqId from TxInvoice i
		where i.LinkId = @oldReqId and i.LinkTypeId = 4


		------****************Update the TxTransaction Link Ids
		--select tx.LinkId, newItems.MemberAgreementInvoiceRequestItemId from MemberAgreementInvoiceRequestItem oldItems
		--	inner join MemberAgreementInvoiceRequestItem newItems on oldItems.MemberAgreementItemId = newItems.MemberAgreementItemId
		--	inner join TxTransaction tx on tx.LinkId = oldItems.MemberAgreementInvoiceRequestItemId and tx.LinkTypeId = 2
		--where oldItems.MemberAgreementInvoiceRequestId = @oldReqId and newItems.MemberAgreementInvoiceRequestId = @newReqId;
		
		UPDATE       TxTransaction
		SET                LinkId = newItems.MemberAgreementInvoiceRequestItemId
		FROM            MemberAgreementInvoiceRequestItem AS oldItems INNER JOIN
								 MemberAgreementInvoiceRequestItem AS newItems ON oldItems.MemberAgreementItemId = newItems.MemberAgreementItemId INNER JOIN
								 TxTransaction ON TxTransaction.LinkId = oldItems.MemberAgreementInvoiceRequestItemId AND TxTransaction.LinkTypeId = 2
		WHERE        (oldItems.MemberAgreementInvoiceRequestId = @oldReqId) AND (newItems.MemberAgreementInvoiceRequestId = @newReqId)  
				
	Fetch Next from FixCursor Into @maId;

	END;

	close FixCursor;

deAllocate FixCursor;
