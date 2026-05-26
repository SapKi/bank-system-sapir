// Selector layer — owns all SOQL queries against LoanApproval__c.
// with sharing: record visibility is enforced (users only see approvals they have access to).
// FLS is intentionally not enforced here: this selector is called only from internal
// server-side processes (triggers, async jobs, REST resources). FLS enforcement
// belongs in UI-facing controllers, not internal data reads.
public with sharing class LoanApprovalSelector {

    public static Map<Id, LoanApproval__c> getByIds(Set<Id> ids) {
        if (ids == null || ids.isEmpty()) return new Map<Id, LoanApproval__c>();

        return new Map<Id, LoanApproval__c>(
            [SELECT Id, LoanRequest__c, ExternalRefId__c, ApprovalStatus__c, SentToExternal__c
             FROM   LoanApproval__c
             WHERE  Id IN :ids]
        );
    }

    public static LoanApproval__c getByExternalRefId(String externalRefId) {
        if (String.isBlank(externalRefId)) return null;

        List<LoanApproval__c> results = [
            SELECT Id, LoanRequest__c, ApprovalStatus__c
            FROM   LoanApproval__c
            WHERE  ExternalRefId__c = :externalRefId
            LIMIT  1
        ];
        return results.isEmpty() ? null : results[0];
    }
}
