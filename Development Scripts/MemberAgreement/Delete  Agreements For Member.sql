declare @prRemoveAgr table (
	agreeId int not null
)

Insert into @prRemoveAgr
select MemberAgreementId from MemberAgreement where PartyRoleId in (
	select PartyRoleID from PartyRole where RoleId = '1010' and PartyRoleTypeID = 1
)

DECLARE @memAgrId INT;
Declare @MemberAgrGroupID int;


declare LoopCursor Cursor for
	select agreeId from @prRemoveAgr
Open LoopCursor;
Fetch Next from LoopCursor Into @memAgrId;
WHILE (@@fetch_status <> -1) 
	BEGIN
			print 'Deleting agreement #' + convert(varchar(max),@memAgrId);		
			Set @MemberAgrGroupID = 
			(select MemberAgreementGroupId
			from MemberAgreementGroupRole
			where MemberAgreementId = @memAgrId
			and RoleType = 1)

			BEGIN TRANSACTION;

			-- gather info on member agreement transactions and invoices
				DECLARE @memAgrItemTxs TABLE(
					TxTransactionId INT NOT NULL,
					TxInvoiceId INT NOT NULL
				);

				INSERT INTO @memAgrItemTxs(TxTransactionId, TxInvoiceId)
					SELECT
						TX.TxTransactionID,
						TX.TxInvoiceId
					FROM
						MemberAgreementInvoiceRequestItem
							IRI
						INNER JOIN MemberAgreementInvoiceRequest
							IR
							ON (IRI.MemberAgreementInvoiceRequestId = IR.MemberAgreementInvoiceRequestId)
						INNER JOIN TxTransaction
							TX
							ON (IRI.TxTransactionId = TX.TxTransactionID)
					WHERE
						IR.MemberAgreementId = @memAgrId
						AND IRI.TxTransactionId IS NOT NULL;


			--ActivityTimeLog
				DELETE FROM ATL
				FROM 
					ActivityTimeLog 
						ATL
					INNER JOIN ActivityTransaction
						ATX
						ON (ATL.ActivityTransactionId = ATX.ActivityTransactionId)
					INNER JOIN Activity 
						ACT
						ON (ATX.ActivityId = ACT.ActivityId)
					INNER JOIN @memAgrItemTxs
						MAT
						ON (ACT.TxTransactionId = MAT.TxTransactionId);
				
			--ActivityTransaction
				DELETE FROM ATX
				FROM
					ActivityTransaction
						ATX
					INNER JOIN Activity 
						ACT
						ON (ATX.ActivityId = ACT.ActivityId)
					INNER JOIN @memAgrItemTxs
						MAT
						ON (ACT.TxTransactionId = MAT.TxTransactionId);	
					
			--Activity
				DELETE FROM ACT
				FROM
					Activity 
						ACT
					INNER JOIN @memAgrItemTxs
						MAT
						ON (ACT.TxTransactionId = MAT.TxTransactionId);	

			-- effected payments
				DECLARE @payIds TABLE(
					TxPaymentId INT NOT NULL PRIMARY KEY
				);
				INSERT INTO @payIds(TxPaymentId)
					SELECT DISTINCT
						TX.ItemId
					FROM 
						TxTransaction
							TX
						INNER JOIN @memAgrItemTxs
							MAT
							ON (TX.TxInvoiceId = MAT.TxInvoiceId)
					WHERE
						TX.TxTypeId IN (4,5);
								
			--TxTransaction
				DELETE FROM TX
				FROM 
					TxTransaction
						TX
					INNER JOIN @memAgrItemTxs
						MAT
						ON (TX.TxInvoiceId = MAT.TxInvoiceId);
									

			--effected batches
				DECLARE @batchIds TABLE(
					PaymentProcessBatchId INT NOT NULL PRIMARY KEY		
					);
				INSERT INTO @batchIds(PaymentProcessBatchId)
					SELECT DISTINCT PPB.PaymentProcessBatchId
					FROM 
						PaymentProcessBatch
							PPB
						INNER JOIN PaymentProcessRequest
							PPR
							ON (PPB.PaymentProcessBatchId = PPR.PaymentProcessBatchId)
						INNER JOIN @payIds
							PID
							ON (PPR.TxPaymentId = PID.TxPaymentId);
					
			--PaymentProcessRequestValidation
				DELETE FROM PPV
				FROM 
					PaymentProcessValidation
						PPV
					INNER JOIN PaymentProcessRequest
						PPR
						ON (PPV.PaymentProcessRequestId = PPR.PaymentProcessRequestId)
					INNER JOIN @payIds
						PID
						ON (PPR.TxPaymentId = PID.TxPaymentId);
						
			--PaymentProcessResponse
				DELETE FROM PRSP
				FROM
					PaymentProcessResponse
						PRSP
					INNER JOIN PaymentProcessRequest
						PPR
						ON (PRSP.PaymentProcessRequestId = PPR.PaymentProcessRequestId)
					INNER JOIN @payIds
						PID
						ON (PPR.TxPaymentId = PID.TxPaymentId);
					
			--PaymentProcessRequest
				DELETE FROM PPR
				FROM
					PaymentProcessRequest
						PPR
					INNER JOIN @payIds
						PID
						ON (PPR.TxPaymentId = PID.TxPaymentId);
						
			-- delete batch ids that have other requests
				DELETE FROM BID
				FROM @batchIds BID
				WHERE EXISTS(
					SELECT * FROM PaymentProcessRequest WHERE PaymentProcessBatchId = BID.PaymentProcessBatchId
					);

			--PaymentProcessError
				DELETE FROM PPE
				FROM 
					PaymentProcessError 
						PPE
					INNER JOIN @batchIds 
						BID
						ON (BID.PaymentProcessBatchId = PPE.PaymentProcessBatchId);

			--PaymentProcessBatch (if empty)
				DELETE FROM PPB
				FROM 
					PaymentProcessBatch
						PPB
					INNER JOIN @batchIds
						BID
						ON (PPB.PaymentProcessBatchId = BID.PaymentProcessBatchId);
				

			--TxPayment
				DELETE FROM PAY
				FROM
					TxPayment
						PAY
					INNER JOIN @payIds
						PID
						ON (PAY.TxPaymentID = PID.TxPaymentId)
				WHERE
					(SELECT COUNT(*) FROM TxTransaction WHERE TxTypeId IN (4,5) AND ItemId = PAY.TxPaymentID) = 0;
					
			--Update Amount on existing TxPayment
				UPDATE PAY SET
					PAY.Amount = ABS(
						(
							SELECT SUM(CASE IsAccountingCredit WHEN 0 THEN Amount ELSE -Amount END)
							FROM TxTransaction
							WHERE TxTypeId IN (4,5) AND ItemId = PAY.TxPaymentId
						)
					),
					PAY.IsReversal = 
						(
							CASE WHEN (
								SELECT SUM(CASE IsAccountingCredit WHEN 0 THEN Amount ELSE -Amount END)
								FROM TxTransaction
								WHERE TxTypeId IN (4,5) AND ItemId = PAY.TxPaymentId
								) < 0
								THEN 0
							ELSE
								1
							END
						)		
				FROM 
					TxPayment
						PAY
					INNER JOIN @payIds
						PID
						ON (PAY.TxPaymentID = PID.TxPaymentId);
					
			--TxInvoice
				DELETE FROM INV
				FROM
					TxInvoice
						INV
					INNER JOIN @memAgrItemTxs
						MAT
						ON (INV.TxInvoiceID = MAT.TxInvoiceID);
						
			--FC_TxTransaction
				DELETE FROM FTX
				FROM
					FC_TxTransaction
						FTX
					INNER JOIN FC_TxInvoice
						FINV
						ON (FTX.TxInvoiceId = FINV.TxInvoiceID)
					INNER JOIN @memAgrItemTxs
						MAT
						ON (FINV.OriginalTxInvoiceId = MAT.TxInvoiceId);
						
			--FC_TxPayment
				DELETE FROM FPAY
				FROM
					FC_TxPayment
						FPAY
					INNER JOIN @payIds
						PID
						ON (FPAY.OriginalTxPaymentId = PID.TxPaymentId);
						
			--FC_TxInvoice
				DELETE FROM FINV
				FROM
					FC_TxInvoice
						FINV
					INNER JOIN @memAgrItemTxs
						MAT
						ON (FINV.OriginalTxInvoiceId = MAT.TxInvoiceId);
						
			--SuspensionEndDate
				DELETE FROM SED
				FROM
					SuspensionEndDate
						SED
					INNER JOIN Suspension
						S
						ON (SED.SuspensionId = S.SuspensionId)
				WHERE
					S.TargetEntityIdType = 0x00000008
					AND s.TargetEntityId = @memAgrId;
					
			--Suspension
				DELETE FROM Suspension
				WHERE 
					TargetEntityIdType = 0x00000008
					AND TargetEntityId = @memAgrId;

			--CancellationDetail
				DELETE FROM CD
				FROM
					CancellationDetail
						CD
					INNER JOIN Cancellation
						C
						ON (CD.CancellationId = C.CancellationId)
				WHERE
					(C.EntityIdType = 1 AND c.EntityId = @memAgrId)
					OR (C.EntityIdType = 2 AND C.EntityId IN (SELECT TxInvoiceId FROM @memAgrItemTxs));
					
			--Cancellation
				DELETE FROM C
				FROM
					Cancellation
						C
				WHERE
					(C.EntityIdType = 1 AND c.EntityId = @memAgrId)
					OR (C.EntityIdType = 2 AND C.EntityId IN (SELECT TxInvoiceId FROM @memAgrItemTxs));
			--Promotions
			delete from MemberAgreementItemPromotionEffectApplication where MemberAgreementItemPromotionEffectId in (
				select MemberAgreementItemPromotionEffectId from MemberAgreementItemPromotionEffect
				where MemberAgreementItemId in (Select MemberAgreementId from MemberAgreementItem where MemberAgreementId = @memAgrId)
				)
			delete from MemberAgreementItemPromotionEffect
				where MemberAgreementItemId in (Select MemberAgreementId from MemberAgreementItem where MemberAgreementId = @memAgrId)
			
			delete from MemberAgreementPromotion where MemberAgreementId = @memAgrId
			
			
			--MemberAgreementSalesAdviser
				DELETE FROM MemberAgreementSalesAdviser
				WHERE MemberAgreementId = @memAgrId;

			--MemberAgreementPaymentRequestItem
				DELETE FROM PRI
				FROM 
					MemberAgreementPaymentRequestItem
						PRI
					INNER JOIN MemberAgreementPaymentRequest
						PR
						ON (PRI.MemberAgreementPaymentRequestId = PR.MemberAgreementPaymentRequestId)
					INNER JOIN MemberAgreementInvoiceRequest
						IR
						ON (PR.MemberAgreementInvoiceRequestId = IR.MemberAgreementInvoiceRequestId)
				WHERE
					IR.MemberAgreementId = @memAgrId;
				
			--MemberAgreementPaymentRequest
				DELETE FROM PR
				FROM 
					MemberAgreementPaymentRequest
						PR
					INNER JOIN MemberAgreementInvoiceRequest
						IR
						ON (PR.MemberAgreementInvoiceRequestId = IR.MemberAgreementInvoiceRequestId)
				WHERE
					IR.MemberAgreementId = @memAgrId;

			--MemberAgreementInvoiceRequestItem
				DELETE FROM IRI
				FROM
					MemberAgreementInvoiceRequestItem
						IRI
					INNER JOIN MemberAgreementInvoiceRequest
						IR
						ON (IRI.MemberAgreementInvoiceRequestId = IR.MemberAgreementInvoiceRequestId)
				WHERE 
					IR.MemberAgreementId = @memAgrId;
						
			--MemberAgreementInvoiceRequest
				DELETE FROM MemberAgreementInvoiceRequest
				WHERE MemberAgreementId = @memAgrId;

			--MemberAgreementItemPerpetualPaySource
				DELETE FROM PPS
				FROM
					MemberAgreementItemPerpetualPaySource
						PPS
					INNER JOIN MemberAgreementItemPerpetual
						IP
						ON (PPS.MemberAgreementItemPerpetualId = IP.MemberAgreementItemPerpetualId)
					INNER JOIN MemberAgreementItem
						I
						ON (IP.MemberAgreementItemId = I.MemberAgreementItemId)
				WHERE
					I.MemberAgreementId = @memAgrId;
					

			--MemberAgreementItemPaySource
				DELETE FROM IPS
				FROM
					MemberAgreementItemPaySource
						IPS
					INNER JOIN MemberAgreementItem
						I
						ON (IPS.MemberAgreementItemId = I.MemberAgreementItemId)
				WHERE
					I.MemberAgreementId = @memAgrId;
				

			--MemberAgreementItemPerpetual
				DELETE FROM IP
				FROM
					MemberAgreementItemPerpetual
						IP
					INNER JOIN MemberAgreementItem
						I
						ON (IP.MemberAgreementItemId = I.MemberAgreementItemId)
				WHERE
					I.MemberAgreementId = @memAgrId;
				
				------Group restrictions	
				delete from MemberAgreementGroupRestrictionAgreements
				where MemberAgreementGroupRestrictionId in (
					select MemberAgreementGroupRestrictionId from MemberAgreementGroupRestriction where MemberAgreementGroupId = @MemberAgrGroupID
				)

				delete from MemberAgreementGroupRestrictionPromotions
				where MemberAgreementGroupRestrictionId in (
					select MemberAgreementGroupRestrictionId from MemberAgreementGroupRestriction where MemberAgreementGroupId = @MemberAgrGroupID
				)

				delete from MemberAgreementGroupRestriction where MemberAgreementGroupId = @MemberAgrGroupID
			
					
			--MemberAgrementRole
				Delete from MemberAgreementGroupRole
				where MemberAgreementGroupId = @MemberAgrGroupID
				
			--MemberAgrementRule
				Delete from MemberAgreementGroupRule
				where MemberAgreementGroupId = @MemberAgrGroupID	
				
			--MemberAgrementGroup
				Delete from MemberAgreementGroup
				where MemberAgreementGroupId = @MemberAgrGroupID			

			--MemberAgreementItem
				DELETE FROM MemberAgreementItem
				WHERE MemberAgreementId = @memAgrId;

			--Payment plan items
			DELETE FROM MemberAgreementPaymentPlanItem
				WHERE        (MemberAgreementPaymentPlanId IN
                             (SELECT        MemberAgreementPaymentPlanId
                               FROM            MemberAgreementPaymentPlan
                               WHERE        (MemberAgreementId = @memAgrId)))

			--Payment Plans
			
			DELETE FROM MemberAgreementPaymentPlan
				WHERE        (MemberAgreementId = @memAgrId)

			--Promotion
			delete from MemberAgreementItemPromotionEffectApplication
			where MemberAgreementItemPromotionEffectId in (
				select MemberAgreementItemPromotionEffectId from MemberAgreementItemPromotionEffect
					where MemberAgreementPromotionId in (
						select MemberAgreementPromotionId from MemberAgreementPromotion where MemberAgreementId = @memAgrId
					)
			)


			delete from MemberAgreementItemPromotionEffect
			where MemberAgreementPromotionId in (
				select MemberAgreementPromotionId from MemberAgreementPromotion where MemberAgreementId = @memAgrId
			)
			
			delete from MemberAgreementPromotion where MemberAgreementId = @memAgrId;
			--MemberAgreement
				DELETE FROM MemberAgreement
				WHERE MemberAgreementId = @memAgrId;

			COMMIT TRANSACTION;
						
	Fetch Next from LoopCursor Into @memAgrId;
	END;
close LoopCursor;
deAllocate LoopCursor;





