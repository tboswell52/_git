
/*
SELECT        MemberAgreement.MemberAgreementId, MemberAgreementItemPerpetual.BillCount, MemberAgreement.Status, PartyRole.RoleID
FROM            MemberAgreement INNER JOIN
                         MemberAgreementItem ON MemberAgreement.MemberAgreementId = MemberAgreementItem.MemberAgreementId INNER JOIN
                         MemberAgreementItemPerpetual ON 
                         MemberAgreementItem.MemberAgreementItemId = MemberAgreementItemPerpetual.MemberAgreementItemId INNER JOIN
                         PartyRole ON MemberAgreement.PartyRoleId = PartyRole.PartyRoleID
WHERE        (MemberAgreement.Status = 5) AND (NOT (MemberAgreementItemPerpetual.BillCount IS NULL))
*/
declare @memberAgreementId int = 1507;
---Items
select * from MemberAgreementItem where MemberAgreementId = @memberAgreementId
--Perpetual Records
select * from MemberAgreementItemPerpetual where MemberAgreementItemId in (
	select MemberAgreementItemId from MemberAgreementItem where MemberAgreementId = @memberAgreementId
)

--Invoice Requests
select * from MemberAgreementInvoiceRequest where MemberAgreementId = @memberAgreementId;
