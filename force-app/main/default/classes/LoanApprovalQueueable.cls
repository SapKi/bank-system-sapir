public class LoanApprovalQueueable implements Queueable, Database.AllowsCallouts {

    private final Id      loanRequestId;
    private final Id      loanApprovalId;
    private final Integer attemptNumber;

    public LoanApprovalQueueable(Id loanRequestId, Id loanApprovalId, Integer attemptNumber) {
        this.loanRequestId  = loanRequestId;
        this.loanApprovalId = loanApprovalId;
        this.attemptNumber  = attemptNumber;
    }

    public void execute(QueueableContext ctx) {
        LoanApproval__c approval = [
            SELECT Id, LoanRequest__c, ExternalRefId__c, ApprovalStatus__c
            FROM   LoanApproval__c
            WHERE  Id = :loanApprovalId
        ];

        HttpRequest req = new HttpRequest();
        req.setEndpoint(LoanRequestConstants.LOAN_CORE_ENDPOINT);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(buildPayload(approval));
        req.setTimeout(30000);

        try {
            HttpResponse res = new Http().send(req);
            if (res.getStatusCode() == 200 || res.getStatusCode() == 201) {
                handleSuccess(approval, res);
            } else {
                handleFailure(res.getStatusCode(), res.getBody());
            }
        } catch (Exception e) {
            handleFailure(0, e.getMessage());
        }
    }

    private String buildPayload(LoanApproval__c approval) {
        return JSON.serialize(new Map<String, Object>{
            'loanRequestId'  => loanRequestId,
            'loanApprovalId' => loanApprovalId,
            'attemptNumber'  => attemptNumber
        });
    }

    private void handleSuccess(LoanApproval__c approval, HttpResponse res) {
        approval.ReceivedResponse__c = Datetime.now();
        try {
            Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            if (body.containsKey('referenceId')) {
                approval.ExternalRefId__c = String.valueOf(body.get('referenceId'));
            }
        } catch (Exception e) {
            // Response body is optional — continue without parsing
        }
        update approval;

        AuditLogService.log(
            loanRequestId,
            LoanRequestConstants.OBJ_LOAN_REQUEST,
            LoanRequestConstants.EVENT_INTEGRATION,
            LoanRequestConstants.ACTION_INTEGRATION_SENT,
            LoanRequestConstants.SEVERITY_INFO,
            null, String.valueOf(res.getStatusCode())
        );
    }

    private void handleFailure(Integer statusCode, String errorBody) {
        if (attemptNumber < LoanRequestConstants.MAX_RETRY_ATTEMPTS) {
            // Re-enqueue with incremented attempt counter (exponential backoff is platform-paced)
            System.enqueueJob(new LoanApprovalQueueable(loanRequestId, loanApprovalId, attemptNumber + 1));
        } else {
            AuditLogService.log(
                loanRequestId,
                LoanRequestConstants.OBJ_LOAN_REQUEST,
                LoanRequestConstants.EVENT_INTEGRATION,
                LoanRequestConstants.ACTION_INTEGRATION_FAILED,
                LoanRequestConstants.SEVERITY_ERROR,
                String.valueOf(statusCode), errorBody
            );
        }
    }
}
