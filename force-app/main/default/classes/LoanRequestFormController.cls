public with sharing class LoanRequestFormController {

    @AuraEnabled
    public static LoanRequest__c saveLoanRequest(
        Id      customerId,
        Decimal loanAmount,
        String  loanStatus
    ) {
        LoanRequest__c lr = LoanRequestService.createLoanRequest(customerId, loanAmount, loanStatus);
        return LoanRequestSelector.getById(lr.Id);
    }

    @AuraEnabled(cacheable=false)
    public static LoanRequest__c getLoanRequest(Id recordId) {
        return LoanRequestSelector.getById(recordId);
    }

    @AuraEnabled(cacheable=false)
    public static List<LoanRequest__c> getRecentLoanRequests() {
        return LoanRequestSelector.getRecent(LoanRequestConstants.MAX_RECENT_LOAN_REQUESTS);
    }
}
