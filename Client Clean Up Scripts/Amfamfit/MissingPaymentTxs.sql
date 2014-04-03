--Begin Transaction;

declare @origTxId int;
declare @txInvoiceId int;
declare @targetDate DateTime;
declare @description varchar(max);
declare @amount Decimal(12,2);
declare @targetDate_ZoneFormat varchar(12);
declare @targetDate_UTC DateTime;
declare @displayOrder int;
declare @groupId int;
declare @itemId int;
declare @linkId int;
declare @targetBusinessUnitId int;
declare @newTxId int;
declare TxCursor Cursor for
		  select maipri.TxTransactionId as TxTransactionId, mair.TxInvoiceId, p.TargetDate, 
			  'ID: ' + convert(varchar(max),p.TxPaymentID) + '| Payment request due: ' + convert(varchar(max), convert(date, p.TargetDate)) as Description, 
				p.Amount as Amount, p.TargetDate_ZoneFormat as TargetDate_ZoneFormat, p.TargetDate_UTC,
				(select count(*) + 1 from TxTransaction where TxInvoiceId = t.TxInvoiceId)  as DisplayOrder, t.GroupId as GroupId, p.TxPaymentID as ItemId,
				maipri.MemberAgreementPaymentRequestItemID, p.TargetBusinessUnitId
			from MemberAgreementPaymentRequestItem maipri
			inner join MemberAgreementPaymentRequest mapr on mapr.MemberAgreementPaymentRequestId = maipri.MemberAgreementPaymentRequestId
			inner join TxPayment p on p.TxPaymentID = mapr.TxPaymentId
			inner join PaymentProcessRequest ppr on p.TxPaymentID = ppr.TxPaymentId
			inner join MemberAgreementInvoiceRequest mair on mair.MemberAgreementInvoiceRequestId = mapr.MemberAgreementInvoiceRequestId
			inner join TxTransaction t on t.TxInvoiceID = mair.TxInvoiceId and t.TxTypeId = 1
			where maipri.TxTransactionId not in (select TxTransactionId from TxTransaction)
		  
		  
Open TxCursor;

Fetch Next from TxCursor Into @origTxId ,@txInvoiceId, @targetDate,@description, @amount, @targetDate_ZoneFormat, @targetDate_UTC, @displayOrder, @groupId, @itemId, @linkId, @targetBusinessUnitId;

WHILE (@@fetch_status <> -1) 

	BEGIN
	
		INSERT INTO TxTransaction
                         (TxInvoiceId, TargetDate, TxTypeId, Quantity, 
						 Description, UnitPrice, Amount, Comments, 
						 TargetDate_ZoneFormat, DisplayOrder, GroupId, 
						 ItemId, WorkUnitId, IsAccountingCredit, PriceId, 
						 BundleId, BundleGroupId, TargetBusinessUnitId, PriceIdType, 
						 LinkTypeId, LinkId, TargetDate_UTC, SalesPersonPartyRoleId)
		VALUES        (@txInvoiceId,@targetDate,4,null,
						@description,null,@amount,'',
						@targetDate_ZoneFormat,@displayOrder,@groupId,
						@itemId,0,1,0,
						null,null,@targetBusinessUnitId,null,
						3,@linkId,@targetDate_UTC,null);
		SELECT @newTxId = scope_identity();
	
		

		UPDATE       MemberAgreementPaymentRequestItem
		SET                TxTransactionId = @newTxId
		WHERE        (TxTransactionId = @origTxId)
	
		UPDATE       PartyRoleStatus
		SET                AccountStatus = 1
		FROM            TxInvoice AS i INNER JOIN
								 PartyRoleStatus ON PartyRoleStatus.PartyRoleId = i.PartyRoleId
		WHERE        (i.TxInvoiceID = @txInvoiceId)
						
	Fetch Next from TxCursor Into @origTxId ,@txInvoiceId, @targetDate,@description, @amount, @targetDate_ZoneFormat, @targetDate_UTC, @displayOrder, @groupId, @itemId, @linkId, @targetBusinessUnitId;


	END;

	close TxCursor;

deAllocate TxCursor;

/*
select * from MemberAgreementPaymentRequestItem mapri
where mapri.TxTransactionId not in (select TxTransactionId from TxTransaction)
*/

/*
select
'ID: ' + convert(varchar(max),f.itemId) + ' | ' +
case Left(ppr.Token, 2) when 'AC' then 'AMEX' when 'VC' then 'VISA' when 'VD' then 'VISA' 
when 'MC' then 'MC' when 'MD' then 'MC' when 'BC' then 'Bank Draft(US)' when 'DC' then 'DISC' end + ':' +
case Left(ppr.Token, 2) when 'BC' then right(ppr.token, 3) else right(ppr.token, 4) end + ' | Payment request due:' + convert(varchar(max), f.targetdate, 101),
t.Description from _fixMissingTxOn03052014Terry f
inner join TxTransaction t on f.ItemId = t.ItemId and t.TxTypeId = 4
inner join PaymentProcessRequest ppr on t.ItemId = ppr.TxPaymentId
*/
select maipri.TxTransactionId as TxTransactionId, mair.TxInvoiceId, p.TargetDate, 
			  'ID: ' + convert(varchar(max),p.TxPaymentID) + '| Payment request due: ' + convert(varchar(max), convert(date, p.TargetDate)) as Description, 
				p.Amount as Amount, p.TargetDate_ZoneFormat as TargetDate_ZoneFormat, p.TargetDate_ZoneFormat,
				(select count(*) + 1 from TxTransaction where TxInvoiceId = t.TxInvoiceId)  as DisplayOrder, t.GroupId as GroupId, p.TxPaymentID as ItemId,
				maipri.MemberAgreementPaymentRequestItemID, p.TargetBusinessUnitId
			from MemberAgreementPaymentRequestItem maipri
			inner join MemberAgreementPaymentRequest mapr on mapr.MemberAgreementPaymentRequestId = maipri.MemberAgreementPaymentRequestId
			inner join TxPayment p on p.TxPaymentID = mapr.TxPaymentId
			inner join PaymentProcessRequest ppr on p.TxPaymentID = ppr.TxPaymentId
			inner join MemberAgreementInvoiceRequest mair on mair.MemberAgreementInvoiceRequestId = mapr.MemberAgreementInvoiceRequestId
			inner join TxTransaction t on t.TxInvoiceID = mair.TxInvoiceId and t.TxTypeId = 1
			where maipri.TxTransactionId not in (select TxTransactionId from TxTransaction)
--rollback transaction;
--commit transaction;