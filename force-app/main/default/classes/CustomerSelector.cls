// Selector layer — owns all SOQL queries against Customer__c.
// with sharing: record visibility is enforced (users only see customers they have access to).
// FLS is intentionally not enforced here: this selector is called only from a trigger,
// which is a server-side process reading related data to fulfil a business rule (send email).
// FLS enforcement belongs in UI-facing controllers, not internal trigger data reads.
public with sharing class CustomerSelector {

    public static Map<Id, Customer__c> getByIds(Set<Id> ids) {
        if (ids == null || ids.isEmpty()) return new Map<Id, Customer__c>();

        return new Map<Id, Customer__c>(
            [SELECT Id, FirstName__c, LastName__c, Email__c
             FROM Customer__c
             WHERE Id IN :ids]
        );
    }
}
