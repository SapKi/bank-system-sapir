// Scalability: accepts a list of approval IDs so one job handles any batch size.
// HTTP callouts are bounded by the platform limit of 100 per transaction.
// On failure, only the failed IDs are re-enqueued, keeping retry scope minimal.
public class LoanApprovalQueueable implements Queueable, Database.AllowsCallouts {

    private final List<Id> approvalIds;
    private final Integer  attemptNumber;

    public LoanApprovalQueueable(List<Id> approvalIds, Integer attemptNumber) {
        this.approvalIds   = approvalIds;
        this.attemptNumber = attemptNumber;
    }

    public void execute(QueueableContext ctx) {
        Map<Id, LoanApproval__c> approvalMap    = LoanApprovalSelector.getByIds(new Set<Id>(approvalIds));
        List<LoanApproval__c>    toUpdate        = new List<LoanApproval__c>();
        List<LoanApproval__c>    failedApprovals = new List<LoanApproval__c>();

        for (LoanApproval__c approval : approvalMap.values()) {
            try {
                HttpResponse res = new Http().send(buildRequest(approval));
                if (res.getStatusCode() == 200 || res.getStatusCode() == 201) {
                    toUpdate.add(applySuccess(approval, res));
                    AuditLogService.log(
                        approval.LoanRequest__c,
                        LoanRequestConstants.OBJ_LOAN_REQUEST,
                        LoanRequestConstants.EVENT_INTEGRATION,
                        LoanRequestConstants.ACTION_INTEGRATION_SENT,
                        LoanRequestConstants.SEVERITY_INFO,
                        null, String.valueOf(res.getStatusCode())
                    );
                } else {
                    failedApprovals.add(approval);
                }
            } catch (Exception e) {
                failedApprovals.add(approval);
            }
        }

        if (!toUpdate.isEmpty()) {
            try {
                LoanApprovalService.updateApprovals(toUpdate);
            } catch (DmlException e) {
                System.debug(LoggingLevel.ERROR, 'LoanApproval update failed: ' + e.getMessage());
            }
        }

        if (!failedApprovals.isEmpty()) {
            handleFailures(failedApprovals);
        }
    }

    private HttpRequest buildRequest(LoanApproval__c approval) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(LoanRequestConstants.LOAN_CORE_ENDPOINT);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(JSON.serialize(new Map<String, Object>{
            LoanRequestConstants.INTEGRATION_FIELD_LOAN_REQUEST_ID  => approval.LoanRequest__c,
            LoanRequestConstants.INTEGRATION_FIELD_LOAN_APPROVAL_ID => approval.Id,
            LoanRequestConstants.INTEGRATION_FIELD_ATTEMPT_NUMBER   => attemptNumber
        }));
        req.setTimeout(30000);
        return req;
    }

    private LoanApproval__c applySuccess(LoanApproval__c approval, HttpResponse res) {
        approval.ReceivedResponse__c = Datetime.now();
        try {
            Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            if (body.containsKey(LoanRequestConstants.INTEGRATION_FIELD_REFERENCE_ID)) {
                approval.ExternalRefId__c = String.valueOf(body.get(LoanRequestConstants.INTEGRATION_FIELD_REFERENCE_ID));
            }
        } catch (Exception e) {
            // Response body parsing is best-effort — field stays null
        }
        return approval;
    }

    private void handleFailures(List<LoanApproval__c> failedApprovals) {
        if (attemptNumber < LoanRequestConstants.MAX_RETRY_ATTEMPTS) {
            List<Id> failedIds = new List<Id>();
            for (LoanApproval__c a : failedApprovals) failedIds.add(a.Id);
            // Re-enqueue only the failed subset; platform pacing provides backoff
            System.enqueueJob(new LoanApprovalQueueable(failedIds, attemptNumber + 1));
        } else {
            for (LoanApproval__c a : failedApprovals) {
                AuditLogService.log(
                    a.LoanRequest__c,
                    LoanRequestConstants.OBJ_LOAN_REQUEST,
                    LoanRequestConstants.EVENT_INTEGRATION,
                    LoanRequestConstants.ACTION_INTEGRATION_FAILED,
                    LoanRequestConstants.SEVERITY_ERROR,
                    String.valueOf(attemptNumber), 'Max retries exceeded'
                );
            }
        }
    }
}
