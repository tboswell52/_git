/*
Active
	5
	
Cancelled
	7
	
Delinquent
	8
	
Depleted
	9
	
Expired
	6
	
Freeze
	11
	
Hold
	10
	
Invalid
	0
	
NotFinalized
	1
	
PendingStart
	4
	
Processing
	2
	
RequiresPayment
	3
	
Terminated
	12

*/

select count(*) as Active from MemberAgreement where Status in (5,8,9,11,10,4)