--Find invoice requests with more than one associated invoice
if object_id('tempdb..#MemberAgreementInvoiceReqs') is not null drop table #MemberAgreementInvoiceReqs
if object_id('tempdb..#sponsorTransactions') is not null drop table #sponsorTransactions

    select pr.RoleID  --636 rows
      , invreq.MemberAgreementInvoiceRequestId
   , invreq.MemberAgreementId
      , [InvoiceCount] = count(*) 
   into #MemberAgreementInvoiceReqs
   from TxInvoice inv
inner join MemberAgreementInvoiceRequest invreq on invreq.MemberAgreementInvoiceRequestId = inv.LinkId
inner join MemberAgreement ma on ma.MemberAgreementId = invreq.MemberAgreementId
inner join PartyRole pr on pr.PartyRoleID = ma.PartyRoleId
  where inv.LinkTypeId in (4)
    and inv.TargetDate between '9/1/2013' and '9/30/2013'
  group by pr.RoleID
         , invreq.MemberAgreementInvoiceRequestId
   , invreq.MemberAgreementId
    having count(*) > 1


select * into #sponsorTransactions from TxTransaction  where TxInvoiceId in (
  select inv.TxInvoiceID
     from TxInvoice inv
  inner join #MemberAgreementInvoiceReqs invreq on invreq.MemberAgreementInvoiceRequestId = inv.LinkId and inv.LinkTypeId = 4)
  and TxTypeId = 4 and LinkTypeId = 8


------------------------Delete logic
declare @protect bit = 1; 
--if this is set to 1(true) then an exception will be thrown if any Invoice Requests or Payment Request have references to it
--if this is set to 0(false) then any invoice requests or payment requests will be updated to remove reference to the invoice and transactions
declare @simulateOnly bit = 0;
--if this is set to true, it will only do selects vs deletes and updates

----------Insert your invoice Ids here-------------------------
declare @invoicesToRemove table (
  txInvoiceId int not null
)
Insert into @invoicesToRemove
  select inv.TxInvoiceId
     from TxInvoice inv
  inner join #MemberAgreementInvoiceReqs invreq on invreq.MemberAgreementInvoiceRequestId = inv.LinkId and inv.LinkTypeId = 4 
  where TxInvoiceID not in (select TxInvoiceID from MemberAgreementInvoiceRequest where TxInvoiceId in (
    select inv.TxInvoiceID
       from TxInvoice inv
    inner join #MemberAgreementInvoiceReqs invreq on invreq.MemberAgreementInvoiceRequestId = inv.LinkId and inv.LinkTypeId = 4
  )) and TxInvoiceID not in (select TxInvoiceID from #sponsorTransactions)



-------------------------Logic Here down----------------------------------------
declare @now DateTime = GetDate();
declare @prefix varchar(50) = '_invoiceRemoval' + convert(varchar(5),  DatePart(day, @now)) + '_' + convert(varchar(5),  DatePart(hour, @now))
   + '_' + convert(varchar(5),  DatePart(minute, @now)) + '_' + convert(varchar(5),  DatePart(SECOND, @now)) + '_'
declare @txInvoiceId int;
declare @sql varchar(max);

---------------------Create the backup tables
set @sql = 'CREATE TABLE [dbo].[' + @prefix + 'MemberAgreementPaymentRequestItem](
				[MemberAgreementPaymentRequestItemId] [int] NOT NULL,
				[ObjectId] [uniqueidentifier] ROWGUIDCOL  NOT NULL,
				[MemberAgreementPaymentRequestId] [int] NOT NULL,
				[MemberAgreementInvoiceRequestItemId] [int] NOT NULL,
				[MemberAgreementItemPaySourceId] [int] NULL,
				[MemberAgreementItemPerpetualPaySourceId] [int] NULL,
				[FixedAmount] [decimal](15, 3) NULL,
				[TxTransactionId] [int] NULL,
				[InstallmentId] [int] NOT NULL)';
exec(@sql);

set @sql = 'CREATE TABLE [dbo].[' + @prefix + 'MemberAgreementPaymentRequest](
				[MemberAgreementInvoiceRequestId] [int] NOT NULL,
				[ObjectId] [uniqueidentifier] ROWGUIDCOL  NOT NULL,
				[MemberAgreementId] [int] NOT NULL,
				[TxInvoiceId] [int] NULL,
				[BillDate] [datetime] NOT NULL,
				[BillDate_ZoneFormat] [varchar](5) NULL,
				[Status] [int] NOT NULL,
				[Comments] [nvarchar](1000) NULL,
				[BillDate_UTC] [datetime] NOT NULL,
				[PrimaryTxInvoiceId] [int] NULL,
				[ProcessType] [int] NULL)';
exec(@sql);

set @sql = 'CREATE TABLE [dbo].[' + @prefix + 'MemberAgreementInvoiceRequestItem](
				[MemberAgreementInvoiceRequestItemId] [int] NOT NULL,
				[ObjectId] [uniqueidentifier] ROWGUIDCOL  NOT NULL,
				[MemberAgreementInvoiceRequestId] [int] NOT NULL,
				[MemberAgreementItemId] [int] NOT NULL,
				[MemberAgreementItemPerpetualId] [int] NULL,
				[Quantity] [decimal](16, 7) NOT NULL,
				[Comments] [nvarchar](1000) NULL,
				[TxTransactionId] [int] NULL,
				[ActivityStartDate] [datetime] NULL,
				[ActivityStartDate_ZoneFormat] [varchar](5) NULL,
				[ActivityEndDate] [datetime] NULL,
				[ActivityEndDate_ZoneFormat] [varchar](5) NULL,
				[ActivityStartDate_UTC] [datetime] NULL,
				[ActivityEndDate_UTC] [datetime] NULL)';
exec(@sql);

set @sql = 'CREATE TABLE [dbo].[' + @prefix + 'MemberAgreementInvoiceRequest](
				[MemberAgreementInvoiceRequestId] [int] NOT NULL,
				[ObjectId] [uniqueidentifier] ROWGUIDCOL  NOT NULL,
				[MemberAgreementId] [int] NOT NULL,
				[TxInvoiceId] [int] NULL,
				[BillDate] [datetime] NOT NULL,
				[BillDate_ZoneFormat] [varchar](5) NULL,
				[Status] [int] NOT NULL,
				[Comments] [nvarchar](1000) NULL,
				[BillDate_UTC] [datetime] NOT NULL,
				[PrimaryTxInvoiceId] [int] NULL,
				[ProcessType] [int] NULL)';
exec(@sql);


set @sql = 'CREATE TABLE [dbo].[' + @prefix + 'ActivityTransaction](
				[ActivityTransactionId] [int] NOT NULL,
				[ObjectId] [uniqueidentifier] NOT NULL,
				[ActivityId] [int] NOT NULL,
				[ActivityTypeId] [int] NOT NULL,
				[RedeemByPartyRoleId] [int] NULL,
				[GeneralLedgerId] [int] NULL,
				[IsAccountingCredit] [bit] NOT NULL,
				[Amount] [decimal](15, 3) NOT NULL,
				[TargetDate] [datetime] NOT NULL,
				[TargetDate_ZoneFormat] [varchar](5) NULL,
				[GroupId] [int] NOT NULL,
				[WorkUnitId] [int] NOT NULL,
				[Comment] [nvarchar](255) NULL,
				[RedemptionType] [int] NOT NULL,
				[ReinstatementReasonId] [int] NULL,
				[TargetDate_UTC] [datetime] NOT NULL,
				[MasterAppointmentId] [int] NULL,
				[BusinessUnitId] [int] NOT NULL,
				[ScheduledDate] [datetime] NULL,
				[ScheduledDate_ZoneFormat] [varchar](5) NULL,
				[ScheduledDate_UTC] [datetime] NULL,
				[RedeemDate] [datetime] NULL,
				[RedeemDate_ZoneFormat] [varchar](5) NULL,
				[RedeemDate_UTC] [datetime] NULL,
				[AutoRedeemed] [bit] NULL,
				[LinkId] [int] NULL,
				[LinkTypeId] [int] NULL,
				[MemberAuthorizationRequired] [bit] NOT NULL,
				[MemberAuthorizationTypeId] [int] NULL,
				[MemberAuthorizationDate] [datetime] NULL,
				[MemberAuthorizationDate_UTC] [datetime] NULL,
				[MemberAuthorizationDate_ZoneFormat] [varchar](5) NULL,
				[EmployeeAuthorizationPartyRoleId] [int] NULL,
				[EmployeeAuthorizationDate] [datetime] NULL,
				[EmployeeAuthorizationDate_UTC] [datetime] NULL,
				[EmployeeAuthorizationDate_ZoneFormat] [varchar](5) NULL,
				[UsingPartyRoleId] [int] NULL)';
exec(@sql);

set @sql = 'CREATE TABLE [dbo].[' + @prefix + 'Activity](
				[ActivityId] [int] NOT NULL,
				[ObjectId] [uniqueidentifier] NOT NULL,
				[MemberPartyRoleId] [int] NULL,
				[TxTransactionId] [int] NULL,
				[StartTime] [datetime] NOT NULL,
				[StartTime_ZoneFormat] [varchar](5) NULL,
				[EndTime] [datetime] NULL,
				[EndTime_ZoneFormat] [varchar](5) NULL,
				[ItemId] [int] NOT NULL,
				[UnitsAcquired] [int] NULL,
				[UnitsConsumed] [int] NULL,
				[RedemptionLocationType] [int] NOT NULL,
				[StatusId] [int] NOT NULL,
				[StartTime_UTC] [datetime] NOT NULL,
				[EndTime_UTC] [datetime] NULL,
				[CheckinTypeId] [int] NULL)';
exec(@sql);

set @sql = 'CREATE TABLE [dbo].[' + @prefix + 'Transaction](
				[TxTransactionID] [int] NOT NULL,
				[ObjectId] [uniqueidentifier] ROWGUIDCOL  NOT NULL,
				[TxInvoiceId] [int] NOT NULL,
				[TargetDate] [datetime] NOT NULL,
				[TxTypeId] [int] NOT NULL,
				[Quantity] [decimal](16, 7) NULL,
				[Description] [nvarchar](200) NULL,
				[UnitPrice] [decimal](12, 3) NULL,
				[Amount] [decimal](15, 3) NOT NULL,
				[Comments] [nvarchar](max) NULL,
				[TargetDate_ZoneFormat] [varchar](5) NULL,
				[DisplayOrder] [smallint] NOT NULL,
				[GroupId] [smallint] NOT NULL,
				[ItemId] [int] NOT NULL,
				[WorkUnitId] [bigint] NOT NULL,
				[IsAccountingCredit] [bit] NOT NULL,
				[PriceId] [int] NOT NULL,
				[BundleId] [int] NULL,
				[BundleGroupId] [int] NULL,
				[TargetBusinessUnitId] [int] NOT NULL,
				[PriceIdType] [int] NULL,
				[LinkTypeId] [int] NULL,
				[LinkId] [int] NULL,
				[TargetDate_UTC] [datetime] NOT NULL,
				[SalesPersonPartyRoleId] [int] NULL)';
exec(@sql);


set @sql = 'CREATE TABLE [dbo].[' + @prefix + 'Invoice](
				[TxInvoiceID] [int] NOT NULL,
				[ObjectId] [uniqueidentifier] ROWGUIDCOL  NOT NULL,
				[TargetBusinessUnitId] [int] NOT NULL,
				[TargetDate] [datetime] NOT NULL,
				[PaymentDueDate] [datetime] NULL,
				[TxInvoiceStatusId] [int] NOT NULL,
				[CurrencyId] [int] NOT NULL,
				[Comments] [nvarchar](max) NULL,
				[TargetDate_ZoneFormat] [varchar](5) NULL,
				[PaymentDueDate_ZoneFormat] [varchar](5) NULL,
				[PartyRoleId] [int] NULL,
				[WorkUnitId] [bigint] NOT NULL,
				[VoidReasonId] [int] NULL,
				[LinkTypeId] [tinyint] NULL,
				[LinkId] [int] NULL,
				[ClientAccountId] [int] NULL,
				[TargetDate_UTC] [datetime] NOT NULL,
				[PaymentDueDate_UTC] [datetime] NULL,
				[BillingStatus] [int] NOT NULL)';
exec(@sql);

set @sql = 'CREATE TABLE [dbo].[' + @prefix + 'Payment](
				[TxPaymentID] [int] NOT NULL,
				[ObjectId] [uniqueidentifier] ROWGUIDCOL  NOT NULL,
				[TargetBusinessUnitId] [int] NOT NULL,
				[TargetDate] [datetime] NOT NULL,
				[CreditCardTypeId] [int] NULL,
				[Reference] [nvarchar](100) NULL,
				[Comments] [nvarchar](max) NULL,
				[Amount] [decimal](15, 3) NOT NULL,
				[TargetDate_ZoneFormat] [varchar](5) NULL,
				[PartyRoleId] [int] NULL,
				[WorkUnitId] [bigint] NOT NULL,
				[IsReversal] [bit] NOT NULL,
				[TenderTypeID] [int] NOT NULL,
				[VoidReasonId] [int] NULL,
				[ClientAccountId] [int] NULL,
				[LinkTypeId] [int] NULL,
				[LinkId] [int] NULL,
				[DeclineReasonId] [int] NULL,
				[IsDeclined] [bit] NOT NULL,
				[TargetDate_UTC] [datetime] NOT NULL)';
exec(@sql);

set @sql = 'CREATE TABLE [dbo].[' + @prefix + 'MemberRental](
				[MemberRentalId] [int] NOT NULL,
				[ObjectID] [uniqueidentifier] NOT NULL,
				[PartyRoleId] [int] NOT NULL,
				[RentalId] [int] NOT NULL,
				[RentalTypeId] [int] NOT NULL,
				[MemberAgreementId] [int] NULL,
				[ExpirationDate] [datetime] NULL,
				[ExpirationDate_ZoneFormat] [varchar](5) NULL,
				[ExpirationDate_UTC] [datetime] NULL,
				[TxTransactionId] [int] NULL,
				[ItemId] [int] NULL)';
exec(@sql);

set @sql = 'CREATE TABLE [dbo].[' + @prefix + 'PaymentProcessRequest](
				[PaymentProcessRequestId] [int] NOT NULL,
				[ObjectId] [uniqueidentifier] ROWGUIDCOL  NOT NULL,
				[PaymentProcessBatchId] [int] NOT NULL,
				[MerchantAccountCode] [nvarchar](6) NOT NULL,
				[TxPaymentId] [int] NULL,
				[ItemCode] [nvarchar](20) NULL,
				[TransactionDate] [date] NOT NULL,
				[TransactionType] [int] NOT NULL,
				[AccountType] [int] NOT NULL,
				[CardExpiration] [date] NULL,
				[BankRouting] [nvarchar](10) NULL,
				[Token] [nvarchar](22) NOT NULL,
				[TotalAmount] [decimal](15, 3) NOT NULL,
				[TaxAmount] [decimal](13, 3) NULL,
				[FeeAmount] [decimal](13, 3) NULL,
				[AccountHolderType] [int] NOT NULL,
				[AccountHolderName] [nvarchar](100) NOT NULL,
				[BillingStreet] [nvarchar](128) NULL,
				[BillingCity] [nvarchar](50) NULL,
				[BillingState] [nchar](2) NULL,
				[BillingZip] [nvarchar](15) NULL,
				[BillingTelephone] [nvarchar](20) NULL,
				[BillingEmail] [nvarchar](100) NULL,
				[Memo] [nvarchar](255) NULL,
				[ClientAccountId] [int] NULL,
				[ProcessorRebilled] [bit] NOT NULL)';
exec(@sql);

	

declare LoopCursor Cursor for
	select txInvoiceId from @invoicesToRemove
Open LoopCursor;
Fetch Next from LoopCursor Into @txInvoiceId;
Begin Transaction
WHILE (@@fetch_status <> -1) 
  BEGIN
        
        declare @errorMsg varchar(50) =  'Invoice Id:' + convert(varchar(max), @txInvoiceId) + ' This TxInvoice Cannot be deleted because there is a dependency on it and protect is turned on';
        
        ---------------Payment Requests Items-------------
        if (@protect = 1)
        Begin
          if Exists(select * from MemberAgreementPaymentRequestItem
                  where TxTransactionId in (select TxTransactionId from TxTransaction where TxInvoiceId = @txInvoiceId)) 
                  THROW 50000, @errorMsg, 1;  
        end

        if (@protect = 0)
        Begin
          
          if (@simulateOnly = 0)
          Begin
			set @sql = 'Insert into ' + @prefix + 'MemberAgreementPaymentRequestItem select * ' + 
                ' from MemberAgreementPaymentRequestItem
                  where TxTransactionId in (select TxTransactionId from TxTransaction where TxInvoiceId = ' + convert(varchar(10),  @txInvoiceId) + ');
            ';
			
            exec(@sql);
          
            UPDATE       MemberAgreementPaymentRequestItem
              SET                TxTransactionId = NULL
              WHERE        (TxTransactionId IN
                             (SELECT        TxTransactionID
                               FROM            TxTransaction
                               WHERE        (TxInvoiceId = @txInvoiceId)))
          End

          if (@simulateOnly = 1)
          Begin
            SELECT        TxTransactionId
            FROM            MemberAgreementPaymentRequestItem
            WHERE        (TxTransactionId IN
                           (SELECT        TxTransactionID
                             FROM            TxTransaction
                             WHERE        (TxInvoiceId = @txInvoiceId)))
          End
        end

        ---------------------------------------------

        ---------------Payment Requests -------------
        if (@protect = 1)
        Begin
          if Exists(select * from MemberAgreementPaymentRequest
                where TxPaymentId in ( select TxPaymentId from TxPayment where TxPaymentID in (
                            select ItemId from TxTransaction where TxInvoiceId = @txInvoiceId and TxTypeId = 4
                        )
                )) 
                  THROW 50000, @errorMsg, 1;  
        end

        if (@protect = 0)
        Begin

          if (@simulateOnly = 0)
          Begin
			
            set @sql = 'Insert into ' + @prefix + 'MemberAgreementPaymentRequest select * ' + 
                ' from MemberAgreementPaymentRequest
                  where TxPaymentId in ( select TxPaymentId from TxPayment where TxPaymentID in (
                            select ItemId from TxTransaction where TxInvoiceId = ' + convert(varchar(10),  @txInvoiceId) + ' and TxTypeId = 4))';
			
            exec(@sql);
            UPDATE       MemberAgreementPaymentRequest
              SET                TxPaymentId = NULL
              WHERE        (TxPaymentId IN
                             (SELECT        TxPaymentID
                               FROM            TxPayment
                               WHERE        (TxPaymentID IN
                                             (SELECT        ItemId
                                               FROM            TxTransaction
                                               WHERE        (TxInvoiceId = @txInvoiceId) AND (TxTypeId = 4)))))
          End

          if (@simulateOnly = 1)
          Begin
            SELECT        TxPaymentId
              FROM            MemberAgreementPaymentRequest
              WHERE        (TxPaymentId IN
                             (SELECT        TxPaymentID
                               FROM            TxPayment
                               WHERE        (TxPaymentID IN
                                             (SELECT        ItemId
                                               FROM            TxTransaction
                                               WHERE        (TxInvoiceId = @txInvoiceId) AND (TxTypeId = 4)))))
          End
        end

        ---------------------------------------------

		---------------Invoice Requests Items -------------
        if (@protect = 1)
        Begin
          if Exists(select * from MemberAgreementInvoiceRequestItem where TxTransactionId in (select TxTransactionId from TxTransaction where TxInvoiceId = @txInvoiceId)) 
                  THROW 50000, @errorMsg, 1;  
        end

        if (@protect = 0)
        Begin
          
          if (@simulateOnly = 0)
          Begin
			
            set @sql = 'Insert into ' + @prefix + 'MemberAgreementInvoiceRequestItem select * ' + 
                ' from MemberAgreementInvoiceRequestItem where TxTransactionId in (select TxTransactionId from TxTransaction where TxInvoiceId = ' + convert(varchar(10),  @txInvoiceId) + ')';
			
            exec(@sql);
            UPDATE       MemberAgreementInvoiceRequestItem
              SET                TxTransactionId = NULL
              WHERE        (TxTransactionId IN
                             (SELECT        TxTransactionID
                               FROM            TxTransaction
                               WHERE        (TxInvoiceId = @txInvoiceId)))
          End

          if (@simulateOnly = 1)
          Begin
            SELECT        TxTransactionId
              FROM            MemberAgreementInvoiceRequestItem
              WHERE        (TxTransactionId IN
                             (SELECT        TxTransactionID
                               FROM            TxTransaction
                               WHERE        (TxInvoiceId = @txInvoiceId)))
          End
        end

        ---------------------------------------------
		
        ---------------Invoice Requests Items -------------
        if (@protect = 1)
        Begin
          if Exists(select * from MemberAgreementInvoiceRequest where TxInvoiceId = @txInvoiceId) 
                  THROW 50000, @errorMsg, 1;  
        end

        if (@protect = 0)
        Begin

          if (@simulateOnly = 0)
          Begin

			
            set @sql = 'Insert into ' + @prefix + 'MemberAgreementInvoiceRequest select * ' + 
                ' from MemberAgreementInvoiceRequest where TxInvoiceId = ' + convert(varchar(10),  @txInvoiceId);
			
            exec(@sql);


            UPDATE       MemberAgreementInvoiceRequest
              SET                TxInvoiceId = NULL
              WHERE        (TxInvoiceId = @txInvoiceId)
          End

          if (@simulateOnly = 1)
          Begin
            SELECT        TxInvoiceId
              FROM            MemberAgreementInvoiceRequest
              WHERE        (TxInvoiceId = @txInvoiceId)
          End
        end

        ---------------------------------------------
		
		------Activity--------

        if (@simulateOnly = 0)
          Begin

			
            set @sql = 'Insert into ' + @prefix + 'ActivityTransaction select * ' + 
                  ' from ActivityTransaction
                    where ActivityId in (
                      select ActivityId from Activity where TxTransactionId in (
                        select TxTransactionID from TxTransaction where TxInvoiceId = ' + convert(varchar(10),  @txInvoiceId) + ' and TxTypeId = 1
                      )
                  )
            ';
		    exec(@sql);

            delete ActivityTransaction where ActivityId in (
              select ActivityId from Activity where TxTransactionId in (
                select TxTransactionID from TxTransaction where TxInvoiceId = @txInvoiceId and TxTypeId = 1
              )
            )
			set @sql = 'Insert into ' + @prefix + 'Activity select * ' + 
                  ' from Activity
                    where TxTransactionId in (
                      select TxTransactionID from TxTransaction where TxInvoiceId = ' + convert(varchar(10),  @txInvoiceId) + ' and TxTypeId = 1
                    )
            ';
			
            exec(@sql);

            delete Activity where TxTransactionId in (
              select TxTransactionID from TxTransaction where TxInvoiceId = @txInvoiceId and TxTypeId = 1
            )
          End

        if (@simulateOnly = 1)
          Begin
            select * from  ActivityTransaction where ActivityId in (
              select ActivityId from Activity where TxTransactionId in (
                select TxTransactionID from TxTransaction where TxInvoiceId = @txInvoiceId and TxTypeId = 1
              )
            )

            select * from  Activity where TxTransactionId in (
              select TxTransactionID from TxTransaction where TxInvoiceId = @txInvoiceId and TxTypeId = 1
            )
          End
        
        ----------------------
		
        --------Payment-------------
        if (@simulateOnly = 0)
          Begin
			set @sql = 'Insert into ' + @prefix + 'PaymentProcessRequest SELECT ppr.*
					  FROM [PaymentProcessRequest] ppr 
					  inner join TxPayment p on p.TxPaymentID = ppr.TxPaymentId
					  where p.TxPaymentID in (
										  select ItemId from TxTransaction where TxInvoiceId = ' + convert(varchar(10),  @txInvoiceId) + ' and TxTypeId = 4
					)
            ';
			exec(@sql);

			DELETE FROM PaymentProcessRequest
			FROM            PaymentProcessRequest INNER JOIN
									 TxPayment AS p ON p.TxPaymentID = PaymentProcessRequest.TxPaymentId
			WHERE        (p.TxPaymentID IN
										 (SELECT        ItemId
										   FROM            TxTransaction
										   WHERE        (TxInvoiceId = @txInvoiceId) AND (TxTypeId = 4)))


            set @sql = 'Insert into ' + @prefix + 'Payment select * ' + 
                  ' from TxPayment where TxPaymentID in (
                      select ItemId from TxTransaction where TxInvoiceId = ' + convert(varchar(10),  @txInvoiceId) + ' and TxTypeId = 4
                  )
            ';
			exec(@sql);

            delete TxPayment where TxPaymentID in (
                select ItemId from TxTransaction where TxInvoiceId = @txInvoiceId and TxTypeId = 4
            )
          End


        if (@simulateOnly = 1)
          Begin
            select * from TxPayment where TxPaymentID in (
                select ItemId from TxTransaction where TxInvoiceId = @txInvoiceId and TxTypeId = 4
            )
          End
        ----------------------------

        ------Invoice Selection------

        if (@simulateOnly = 0)
          Begin
			
			set @sql = 'Insert into ' + @prefix + 'MemberRental select mr.* from MemberRental mr 
						inner join TxTransaction t on t.TxTransactionID = mr.TxTransactionId
						where t.TxInvoiceId = ' + convert(varchar(10),  @txInvoiceId);
			exec(@sql);

			DELETE FROM MemberRental
			FROM            MemberRental INNER JOIN
									 TxTransaction AS t ON t.TxTransactionID = MemberRental.TxTransactionId
			WHERE        (t.TxInvoiceId = @txInvoiceId)

            set @sql = 'Insert into ' + @prefix + 'Transaction select * ' + 
                  ' from TxTransaction where TxInvoiceId = ' + convert(varchar(10),  @txInvoiceId);
			exec(@sql);
            delete TxTransaction where TxInvoiceId = @txInvoiceId
        
			set @sql = 'Insert into ' + @prefix + 'Invoice select * ' + 
                  ' from TxInvoice where TxInvoiceID = ' + convert(varchar(10),  @txInvoiceId);
			
            exec(@sql);
            delete TxInvoice where TxInvoiceID = @txInvoiceId
          End

        if (@simulateOnly = 1)
          Begin
            select * from TxTransaction where TxInvoiceId = @txInvoiceId
            select * from TxInvoice where TxInvoiceID = @txInvoiceId
          End
        -----------------------------       
		
  Fetch Next from LoopCursor Into @txInvoiceId;
  END;
  COMMIT TRANSACTION;
close LoopCursor;
deAllocate LoopCursor;



