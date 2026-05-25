// Selector layer — owns all SOQL queries against Customer__c.
// with sharing ensures queries respect the running user's record visibility.
public with sharing class CustomerSelector {

    public static Map<Id, Customer__c> getByIds(Set<Id> ids) {
        if (ids == null || ids.isEmpty()) return new Map<Id, Customer__c>();

        return new Map<Id, Customer__c>(
            [SELECT Id, FirstName__c, LastName__c, Email__c
             FROM Customer__c
             WHERE Id IN :ids
             WITH SECURITY_ENFORCED]
        );
    }
}
