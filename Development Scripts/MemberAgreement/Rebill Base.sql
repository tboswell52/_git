if object_id('tempdb..#results') is not null drop table #results
declare @BusinessUnitId int = 1;
declare @minDays int = 7;
declare @maxDays int = 60;
declare @billingDate DateTime = '10/25/2013'; --set this to simulate the billing day

				SELECT 
					REQ.PaymentProcessRequestId,
					REQ.PaymentProcessBatchId,
					PAY.TxPaymentId,
					PAY.ClientAccountId,
					PAY.PartyRoleId,
					PAY.TargetDate,
					PAY.TargetDate_UTC,
					PAY.TargetDate_ZoneFormat,
					PAY.TenderTypeID,
					PAY.LinkTypeId,
					PAY.LinkId,
					DR.DeclineReasonId,
					RSP.ReferenceId,
					rsp.RebillPaymentProcessRequestId 
				into #results
				FROM
					PaymentProcessResponse AS RSP INNER JOIN
					PaymentProcessRequest AS REQ ON (REQ.PaymentProcessRequestId = RSP.PaymentProcessRequestId) INNER JOIN
					PaymentProcessBatch AS BATCH ON (BATCH.PaymentProcessBatchId = REQ.PaymentProcessBatchId) INNER JOIN
					TxPayment AS PAY ON (PAY.TxPaymentId = REQ.TxPaymentId) LEFT OUTER JOIN
					DeclineReason AS DR ON (DR.DeclineReasonId = PAY.DeclineReasonId)
				WHERE
					RSP.RebillPaymentProcessRequestId IS NULL AND --Checks this to make sure it hasn't been rebilled
					BATCH.BusinessUnitId = @BusinessUnitId AND
					PAY.IsDeclined = 1 AND --Checks this to make sure it is going after a decline
					(DR.DoNotReprocess IS NULL OR DR.DoNotReprocess = 0) --Checks this to make sure it should reprocess				
				 AND PAY.TargetDate_UTC >= DateAdd(day, -@maxDays, @billingDate)  --baseline from date coming from the collective bill schedule max days from today.


select * from #results
where
--min date and Max Date
@billingDate > DATEADD(day, @minDays, TargetDate) 