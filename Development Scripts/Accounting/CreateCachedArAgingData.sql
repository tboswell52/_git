declare @businessUnitId int;
declare @cutOffDate DateTime = GetDate();

declare myCursor Cursor for
		  select BusinessUnitId from BusinessUnit
		  
		  
Open myCursor;

Fetch Next from myCursor Into @businessUnitId;

WHILE (@@fetch_status <> -1) 

	BEGIN
				delete from CachedArAging where BusinessUnitId = @businessUnitId;
                declare @localCutOffDate Date = Convert(date, @cutOffDate);
				if object_id('tempdb..#CachedArAging') is not null drop table #CachedArAging
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
		                @cutoffTimeLocal = @cutoffDate,
		                @businessUnitId = @businessUnitId,
		                @partyId = NULL,
		                @clientAccountId = NULL

				Insert #CachedArAging
				select pr.BusinessUnitID, cap.ClientAccountId, pr.PartyID, ma.MemberAgreementId, pr.PartyRoleID, 
				0 as AgingCurrent, 0 as Aging30, 0 as Aging60, 0 as Aging90, 0 as Aging120, 0 as AgingOver120, 0 as TotalDue,
				0 as TotalPastDue, Null as AcctCredit from PartyRole pr
				inner join ClientAccountParty cap on cap.PartyId = pr.PartyID
				inner join MemberAgreement ma on ma.PartyRoleId = pr.PartyRoleID
				where PartyRoleTypeID = 1
				and pr.PartyRoleId not in (select PartyRoleId from #CachedArAging)
				and pr.BusinessUnitID = @businessUnitId

                INSERT INTO CachedArAging
                                         (AgedDate, BusinessUnitId, ClientAccountId, PartyId, 
		                MemberAgreementId, PartyRoleId, AgingCurrent, Aging30, Aging60, Aging90, Aging120, AgingOver120, TotalDue, TotalPastDue, AcctCredit)
                SELECT        @localCutOffDate, BusinessUnitId, ClientAccountId, PartyId, 
		                MemberAgreementId, PartyRoleId, AgingCurrent, Aging30, Aging60, Aging90, Aging120, AgingOver120, TotalDue, TotalPastDue, AcctCredit
                FROM            #CachedArAging;

	Fetch Next from myCursor Into @businessUnitId;

	END;

	close myCursor;

deAllocate myCursor;

select count(*) from CachedArAging

