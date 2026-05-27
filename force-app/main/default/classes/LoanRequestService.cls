// Service layer — owns all DML operations on LoanRequest__c.
// with sharing: users can only create requests for records they have access to.
public with sharing class LoanRequestService {

    public static LoanRequest__c createLoanRequest(Id customerId, Decimal loanAmount, String loanStatus) {
        LoanRequest__c lr = new LoanRequest__c(
            Customer__c   = customerId,
            LoanAmount__c = loanAmount,
            LoanStatus__c = loanStatus
        );
        insert lr;
        return lr;
    }
}
