// Service layer — owns all DML operations on LoanApproval__c.
// without sharing: approval records must always be written regardless of the
// running user's sharing rules (called from triggers, async jobs, and REST resources).
public without sharing class LoanApprovalService {

    public static void insertApprovals(List<LoanApproval__c> approvals) {
        if (approvals == null || approvals.isEmpty()) return;
        insert approvals;
    }

    public static void updateApprovals(List<LoanApproval__c> approvals) {
        if (approvals == null || approvals.isEmpty()) return;
        update approvals;
    }
}
