public with sharing class LoanRequestFormController {

    /**
     * Creates a LoanRequest__c from form input and returns the full record.
     * Attempts to resolve customerName to an existing Customer__c lookup.
     */
    @AuraEnabled
    public static LoanRequest__c saveLoanRequest(
        String  customerName,
        Decimal loanAmount,
        String  loanStatus
    ) {
        LoanRequest__c lr = new LoanRequest__c(
            LoanAmount__c = loanAmount,
            LoanStatus__c = loanStatus,
            Customer__c   = resolveCustomerId(customerName)
        );
        insert lr;
        return getLoanRequest(lr.Id);
    }

    /** Returns a single LoanRequest__c with Customer relationship fields. */
    @AuraEnabled(cacheable=false)
    public static LoanRequest__c getLoanRequest(Id recordId) {
        return [
            SELECT Id, Name, LoanAmount__c, LoanStatus__c, CreatedDate,
                   Customer__r.FirstName__c, Customer__r.LastName__c
            FROM   LoanRequest__c
            WHERE  Id = :recordId
            LIMIT  1
        ];
    }

    // Matches "First Last" against Customer__c FirstName__c / LastName__c.
    // Returns null when no match is found so the record can still be saved.
    private static Id resolveCustomerId(String customerName) {
        if (String.isBlank(customerName)) return null;
        List<String> parts     = customerName.trim().split('\\s+', 2);
        String       firstName = parts[0];
        String       lastName  = parts.size() > 1 ? parts[1] : '';
        List<Customer__c> matches = [
            SELECT Id FROM Customer__c
            WHERE  FirstName__c = :firstName
            AND    LastName__c  = :lastName
            LIMIT  1
        ];
        return matches.isEmpty() ? null : matches[0].Id;
    }
}
