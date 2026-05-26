// Selector layer — owns all SOQL queries against LoanRequest__c.
public with sharing class LoanRequestSelector {

    public static LoanRequest__c getById(Id recordId) {
        return [
            SELECT Id, Name, LoanAmount__c, LoanStatus__c, CreatedDate,
                   Customer__r.FirstName__c, Customer__r.LastName__c
            FROM   LoanRequest__c
            WHERE  Id = :recordId
            LIMIT  1
        ];
    }

    public static List<LoanRequest__c> getRecent(Integer maxRows) {
        return [
            SELECT Id, Name, LoanAmount__c, LoanStatus__c, CreatedDate,
                   Customer__r.FirstName__c, Customer__r.LastName__c
            FROM   LoanRequest__c
            ORDER BY CreatedDate DESC
            LIMIT  :maxRows
        ];
    }
}
