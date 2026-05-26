public with sharing class LoanRequestFormController {

    @AuraEnabled
    public static LoanRequest__c saveLoanRequest(
        Id      customerId,
        Decimal loanAmount,
        String  loanStatus
    ) {
        LoanRequest__c lr = new LoanRequest__c(
            Customer__c   = customerId,
            LoanAmount__c = loanAmount,
            LoanStatus__c = loanStatus
        );
        insert lr;
        return LoanRequestSelector.getById(lr.Id);
    }

    @AuraEnabled(cacheable=false)
    public static LoanRequest__c getLoanRequest(Id recordId) {
        return LoanRequestSelector.getById(recordId);
    }

    @AuraEnabled(cacheable=false)
    public static List<LoanRequest__c> getRecentLoanRequests() {
        return LoanRequestSelector.getRecent(5);
    }
}
