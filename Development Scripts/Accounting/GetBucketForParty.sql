declare @partyId int = 15;
declare @cutoffTimeLocal DateTime = GetDate();
declare @cutoffTimeUtc DAteTime =GetUtcDate();
declare @includeExternalClientAccounts bit = 0;			
				
				declare @upperDate Datetime;
                declare @lowerDate DateTime;
                declare @TimeZoneName varchar(50);
                declare @zeroToThirty decimal(12,2);
                declare @thirtyToSixty decimal(12,2);
                declare @sixtyToNinety  decimal(12,2);
                declare @older decimal(12,2);
                declare @balance decimal(12,2);

				Declare @table table
                (
					Id int,
	                DueAmount decimal(12,2),
	                TargetDate_UTC Datetime, 
					LinkTypeId int null,
					LinkId int null,
					BusinessUnitId int,
					TxInvoiceId int					
                )
                Insert into @table
                select TxTransactionId, DueAmount, TargetDate_UTC, LinkTypeId, LinkId, TargetBusinessUnitId, TxInvoiceId from 
                TransactionsDueByParty(@cutoffTimeLocal, @partyId, @includeExternalClientAccounts) t

				declare @updateTable table
				(
					Id int,
	                DueAmount decimal(12,2),
	                TargetDate_UTC Datetime					
				)

				Insert Into @updateTable
				select id, sum(DueAmount), TargetDate_UTC from (
				select tx.Id, ISNULL(dbo.PaymentRequestItemAmount(mapri.MemberAgreementPaymentRequestItemId) + 
					   (select ISNULL(sum(case when IsAccountingCredit = 1 then -Amount else Amount end), 0) 
						  from TxTransaction where LinkTypeId = 3 AND LinkId = mapri.MemberAgreementPaymentRequestItemId AND TxTypeId IN (4, 5)), tx.DueAmount) as DueAmount,
						  ISNULL(mapr.DueDate_UTC, tx.TargetDate_UTC) as TargetDate_UTC
				  from @table tx
				  join BusinessUnit bu on tx.BusinessUnitId = bu.BusinessUnitId
				  left join MemberAgreementInvoiceRequest mair on tx.TxInvoiceId = mair.TxInvoiceId
				  left join MemberAgreementPaymentRequest mapr on mapr.MemberAgreementInvoiceRequestId = mair.MemberAgreementInvoiceRequestId
				  left join MemberAgreementPaymentRequestItem mapri on mapri.MemberAgreementPaymentRequestId = mapr.MemberAgreementPaymentRequestId	 
				  ) s group by id, TargetDate_UTC;
				  
				Update t
				Set 
					DueAmount = u.DueAmount,
					TargetDate_UTC = u.TargetDate_UTC				
				From @table t
				Inner Join @updateTable u on t.Id = u.Id

				
				--today
                select @cutoffTimeUtc
				select @upperDate
                select @zeroToThirty = Sum(DueAmount) from 
                @table t
                Where
                t.TargetDate_UTC < @cutoffTimeUtc And
                t.TargetDate_UTC >  @upperDate

                --0 to 30
                set @lowerDate = NULL;		
                set @upperDate = DATEADD(day, -30, GETDATE());
				select @cutoffTimeUtc
				select @upperDate
                select @zeroToThirty = Sum(DueAmount) from 
                @table t
                Where
                t.TargetDate_UTC < @cutoffTimeUtc And
                t.TargetDate_UTC >  @upperDate


                --31 to 60
                set @lowerDate = DATEADD(MILLISECOND, -1, DATEADD(day, -30, GETDATE()));		
                set @upperDate = DATEADD(day, -60, GETDATE());
				select @lowerDate
				select @upperDate
                select @thirtyToSixty = Sum(DueAmount) from 
                @table t
                Where
                t.TargetDate_UTC < @lowerDate And
                t.TargetDate_UTC >  @upperDate 


                --61 to 90
                set @lowerDate = DATEADD(MILLISECOND,1, DATEADD(day, -60, GETDATE()));		
                set @upperDate = DATEADD(day, -90, GETDATE());

                select @sixtyToNinety = Sum(DueAmount) from 
                @table t
                Where
                t.TargetDate_UTC < @lowerDate And
                t.TargetDate_UTC >  @upperDate 


                --91 to 120
                set @lowerDate = DATEADD(MILLISECOND,1, DATEADD(day, -90, GETDATE()));		
                set @upperDate = NULL;

                select @older = Sum(DueAmount) from 
                @table t
                Where
                t.TargetDate_UTC < @lowerDate  

                --Total

                select @balance = Sum(DueAmount) from 
                @table t
                Where
                t.TargetDate_UTC < @cutoffTimeUtc 

                select @zeroToThirty as 'ZeroToThirty',
	                 @thirtyToSixty as 'ThirtyOneToSixty',
	                 @sixtyToNinety as 'SixtyOneToNinety',
	                 @older as'Older',
	                 @balance as 'Balance'