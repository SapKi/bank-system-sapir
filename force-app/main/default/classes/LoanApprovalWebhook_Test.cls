@isTest
public class LoanApprovalWebhook_Test {

    private static final String EXTERNAL_REF = 'EXT-TEST-001';

    @TestSetup
    static void setup() {
        Customer__c cust = new Customer__c(
            FirstName__c = 'Bob',
            LastName__c  = 'Builder',
            Email__c     = 'bob@test.com'
        );
        insert cust;

        LoanRequest__c lr = new LoanRequest__c(
            Customer__c   = cust.Id,
            LoanAmount__c = 50000,
            LoanStatus__c = LoanRequestConstants.STATUS_DRAFT
        );
        insert lr;

        insert new LoanApproval__c(
            LoanRequest__c    = lr.Id,
            ApprovalStatus__c = LoanRequestConstants.APPROVAL_STATUS_PENDING,
            ExternalRefId__c  = EXTERNAL_REF,
            SentToExternal__c = Datetime.now()
        );
    }

    // ── Helpers ──────────────────────────────────────────────────────────────────

    private static void setupRestContext(String body, String signature) {
        RestRequest req  = new RestRequest();
        req.requestURI   = '/services/apexrest/loan-approval-webhook/';
        req.httpMethod   = 'POST';
        req.requestBody  = Blob.valueOf(body);
        if (String.isNotBlank(signature)) {
            req.headers.put('X-Signature-SHA256', signature);
        }
        RestContext.request  = req;
        RestContext.response = new RestResponse();
    }

    private static String sign(String body) {
        Blob hmac = Crypto.generateMac(
            LoanRequestConstants.WEBHOOK_HMAC_ALGORITHM,
            Blob.valueOf(body),
            Blob.valueOf(LoanRequestConstants.WEBHOOK_SECRET)
        );
        return EncodingUtil.convertToHex(hmac);
    }

    // ── Tests ────────────────────────────────────────────────────────────────────

    @isTest
    static void testApprovedWebhook_UpdatesStatusAndLogsInfo() {
        String body = '{"referenceId":"' + EXTERNAL_REF + '","status":"' + LoanRequestConstants.APPROVAL_STATUS_APPROVED + '"}';
        setupRestContext(body, sign(body));

        Test.startTest();
        LoanApprovalWebhook.handleWebhook();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode, 'HTTP 200 expected for valid approved payload');

        LoanApproval__c updated = [SELECT ApprovalStatus__c, ReceivedResponse__c FROM LoanApproval__c WHERE ExternalRefId__c = :EXTERNAL_REF];
        System.assertEquals(LoanRequestConstants.APPROVAL_STATUS_APPROVED, updated.ApprovalStatus__c,   'Status must be Approved');
        System.assertNotEquals(null,                                        updated.ReceivedResponse__c, 'ReceivedResponse must be set');

        LoanRequest__c lr = [SELECT Id FROM LoanRequest__c LIMIT 1];
        List<AuditLog__c> logs = [SELECT Action__c, Severity__c FROM AuditLog__c WHERE RelatedId__c = :String.valueOf(lr.Id)];
        System.assertEquals(1,                                              logs.size(),          'One AuditLog expected');
        System.assertEquals(LoanRequestConstants.ACTION_WEBHOOK_RECEIVED,  logs[0].Action__c,   'Action must be WebhookReceived');
        System.assertEquals(LoanRequestConstants.SEVERITY_INFO,            logs[0].Severity__c, 'Severity must be INFO');
    }

    @isTest
    static void testRejectedWebhook_SetsRejectionReason() {
        String reason = 'Insufficient credit score';
        String body   = '{"referenceId":"' + EXTERNAL_REF + '","status":"' + LoanRequestConstants.APPROVAL_STATUS_REJECTED + '","rejectionReason":"' + reason + '"}';
        setupRestContext(body, sign(body));

        Test.startTest();
        LoanApprovalWebhook.handleWebhook();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode, 'HTTP 200 expected for valid rejected payload');

        LoanApproval__c updated = [SELECT ApprovalStatus__c, RejectionReason__c FROM LoanApproval__c WHERE ExternalRefId__c = :EXTERNAL_REF];
        System.assertEquals(LoanRequestConstants.APPROVAL_STATUS_REJECTED, updated.ApprovalStatus__c,  'Status must be Rejected');
        System.assertEquals(reason,                                         updated.RejectionReason__c, 'RejectionReason must be populated');
    }

    @isTest
    static void testInvalidSignature_Returns401() {
        String body = '{"referenceId":"' + EXTERNAL_REF + '","status":"Approved"}';
        setupRestContext(body, 'not-a-valid-hmac');

        Test.startTest();
        LoanApprovalWebhook.handleWebhook();
        Test.stopTest();

        System.assertEquals(401, RestContext.response.statusCode, 'HTTP 401 expected for tampered signature');
    }

    @isTest
    static void testMissingSignature_Returns401() {
        String body = '{"referenceId":"' + EXTERNAL_REF + '","status":"Approved"}';
        setupRestContext(body, null);

        Test.startTest();
        LoanApprovalWebhook.handleWebhook();
        Test.stopTest();

        System.assertEquals(401, RestContext.response.statusCode, 'HTTP 401 expected when signature header is absent');
    }

    @isTest
    static void testUnknownReferenceId_Returns404() {
        String body = '{"referenceId":"EXT-DOES-NOT-EXIST","status":"Approved"}';
        setupRestContext(body, sign(body));

        Test.startTest();
        LoanApprovalWebhook.handleWebhook();
        Test.stopTest();

        System.assertEquals(404, RestContext.response.statusCode, 'HTTP 404 expected for unknown referenceId');
    }
}
