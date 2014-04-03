declare @PartyId int;
declare @ClientAccountId int;
select @PartyId = partyId from PartyRole where RoleId = '1010' and PartyRoleTypeID = 1

declare @charges decimal(12,2);
declare @payments decimal(12,2);
declare @upperDate Datetime;
declare @lowerDate DateTime;

declare LoopCursor Cursor for
	select ClientAccountId from ClientAccountParty where PartyId = @PartyId
Open LoopCursor;
		Fetch Next from LoopCursor Into @ClientAccountId;
		WHILE (@@fetch_status <> -1) 
		Begin
			--0 to 30
			set @lowerDate = NULL;		
			set @upperDate = DATEADD(day, -30, GETDATE());
			select @charges = sum(amount) from TxTransaction
			where TxInvoiceId in (
				select TxInvoiceId from TxInvoice where ClientAccountId = @ClientAccountId	and PaymentDueDate > @upperDate 
			) and IsAccountingCredit = 0

			select @payments = sum(amount) from TxTransaction
			where TxInvoiceId in (
				select TxInvoiceId from TxInvoice where ClientAccountId = @ClientAccountId	and PaymentDueDate > @upperDate  
			) and IsAccountingCredit = 1

			select '30 Day' as Range, @lowerDate as FromDate, @upperDate as ToDate, @ClientAccountId as AccountId, @charges as Charges, @payments as Payments, (@charges - @payments) as Balance

			--31 to 60
			set @lowerDate = DATEADD(minute,1, DATEADD(day, -30, GETDATE()));		
			set @upperDate = DATEADD(day, -60, GETDATE());
			
			select @charges = sum(amount) from TxTransaction
			where TxInvoiceId in (
				select TxInvoiceId from TxInvoice where ClientAccountId = @ClientAccountId	and PaymentDueDate Between @upperDate and @lowerDate 
			) and IsAccountingCredit = 0

			select @payments = sum(amount) from TxTransaction
			where TxInvoiceId in (
				select TxInvoiceId from TxInvoice where ClientAccountId = @ClientAccountId	and PaymentDueDate Between @upperDate and @lowerDate 
			) and IsAccountingCredit = 1

			select '60 Day' as Range, @lowerDate as FromDate, @upperDate as ToDate,@ClientAccountId as AccountId, @charges as Charges, @payments as Payments, (@charges - @payments) as Balance

			--61 to 90
			set @lowerDate = DATEADD(minute,1, DATEADD(day, -60, GETDATE()));		
			set @upperDate = DATEADD(day, -90, GETDATE());
			
			select @charges = sum(amount) from TxTransaction
			where TxInvoiceId in (
				select TxInvoiceId from TxInvoice where ClientAccountId = @ClientAccountId	and PaymentDueDate Between @upperDate and @lowerDate 
			) and IsAccountingCredit = 0

			select @payments = sum(amount) from TxTransaction
			where TxInvoiceId in (
				select TxInvoiceId from TxInvoice where ClientAccountId = @ClientAccountId	and PaymentDueDate Between @upperDate and @lowerDate 
			) and IsAccountingCredit = 1

			select '90 Day' as Range, @lowerDate as FromDate, @upperDate as ToDate,@ClientAccountId as AccountId, @charges as Charges, @payments as Payments, (@charges - @payments) as Balance

			--91 to 120
			set @lowerDate = DATEADD(minute,1, DATEADD(day, -90, GETDATE()));		
			set @upperDate = NULL;
			
			select @charges = sum(amount) from TxTransaction
			where TxInvoiceId in (
				select TxInvoiceId from TxInvoice where ClientAccountId = @ClientAccountId	and PaymentDueDate  < @lowerDate
			) and IsAccountingCredit = 0

			select @payments = sum(amount) from TxTransaction
			where TxInvoiceId in (
				select TxInvoiceId from TxInvoice where ClientAccountId = @ClientAccountId	and PaymentDueDate < @lowerDate 
			) and IsAccountingCredit = 1

			select '90+' as Range, @lowerDate as FromDate, @upperDate as ToDate,@ClientAccountId as AccountId, @charges as Charges, @payments as Payments, (@charges - @payments) as Balance

			--Total
			select @charges = sum(amount) from TxTransaction
			where TxInvoiceId in (
				select TxInvoiceId from TxInvoice where ClientAccountId = @ClientAccountId	
			) and IsAccountingCredit = 0

			select @payments = sum(amount) from TxTransaction
			where TxInvoiceId in (
				select TxInvoiceId from TxInvoice where ClientAccountId = @ClientAccountId	
			) and IsAccountingCredit = 1

			select 'Total' as Range, NUll as FromDate, Null as ToDate, @ClientAccountId as AccountId, @charges as Charges, @payments as Payments, (@charges - @payments) as Balance
			Fetch Next from LoopCursor Into @ClientAccountId;		
		END

close LoopCursor;
deAllocate LoopCursor;
