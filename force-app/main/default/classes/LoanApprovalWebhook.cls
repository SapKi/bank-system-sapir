@RestResource(urlMapping='/loan-approval-webhook/*')
global without sharing class LoanApprovalWebhook {

    @HttpPost
    global static void handleWebhook() {
        RestRequest  req = RestContext.request;
        RestResponse res = RestContext.response;
        res.addHeader('Content-Type', 'application/json');

        String requestBody = req.requestBody != null ? req.requestBody.toString() : '';

        if (!isSignatureValid(req, requestBody)) {
            res.statusCode    = 401;
            res.responseBody  = Blob.valueOf('{"error":"Invalid or missing HMAC-SHA256 signature"}');
            return;
        }

        try {
            Map<String, Object> payload      = (Map<String, Object>) JSON.deserializeUntyped(requestBody);
            String externalRefId  = String.valueOf(payload.get('referenceId'));
            String approvalStatus = String.valueOf(payload.get('status'));
            String rejectionReason = payload.containsKey('rejectionReason')
                ? String.valueOf(payload.get('rejectionReason')) : null;

            List<LoanApproval__c> approvals = [
                SELECT Id, LoanRequest__c, ApprovalStatus__c
                FROM   LoanApproval__c
                WHERE  ExternalRefId__c = :externalRefId
                LIMIT  1
            ];

            if (approvals.isEmpty()) {
                res.statusCode   = 404;
                res.responseBody = Blob.valueOf('{"error":"LoanApproval not found for referenceId: ' + externalRefId + '"}');
                return;
            }

            LoanApproval__c approval  = approvals[0];
            String          oldStatus = approval.ApprovalStatus__c;

            approval.ApprovalStatus__c   = approvalStatus;
            approval.ReceivedResponse__c = Datetime.now();
            if (String.isNotBlank(rejectionReason)) {
                approval.RejectionReason__c = rejectionReason;
            }
            update approval;

            AuditLogService.log(
                approval.LoanRequest__c,
                LoanRequestConstants.OBJ_LOAN_REQUEST,
                LoanRequestConstants.EVENT_INTEGRATION,
                LoanRequestConstants.ACTION_WEBHOOK_RECEIVED,
                LoanRequestConstants.SEVERITY_INFO,
                oldStatus, approvalStatus
            );

            res.statusCode   = 200;
            res.responseBody = Blob.valueOf('{"status":"ok"}');

        } catch (Exception e) {
            AuditLogService.log(
                null,
                LoanRequestConstants.OBJ_LOAN_REQUEST,
                LoanRequestConstants.EVENT_INTEGRATION,
                LoanRequestConstants.ACTION_WEBHOOK_FAILED,
                LoanRequestConstants.SEVERITY_ERROR,
                null, e.getMessage()
            );
            res.statusCode   = 500;
            res.responseBody = Blob.valueOf('{"error":"Internal server error"}');
        }
    }

    private static Boolean isSignatureValid(RestRequest req, String body) {
        String receivedSig = req.headers.get('X-Signature-SHA256');
        if (String.isBlank(receivedSig)) return false;

        Blob   hmac     = Crypto.generateMac(
            LoanRequestConstants.WEBHOOK_HMAC_ALGORITHM,
            Blob.valueOf(body),
            Blob.valueOf(LoanRequestConstants.WEBHOOK_SECRET)
        );
        String expected = EncodingUtil.convertToHex(hmac);
        return expected.equalsIgnoreCase(receivedSig);
    }
}
