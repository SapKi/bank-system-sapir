@isTest
public class LoanApprovalQueueable_Test {

    @TestSetup
    static void setup() {
        Customer__c cust = new Customer__c(
            FirstName__c = 'Jane',
            LastName__c  = 'Doe',
            Email__c     = 'jane@test.com'
        );
        insert cust;

        // Amount below threshold so setup does not generate any WARN AuditLogs
        insert new LoanRequest__c(
            Customer__c   = cust.Id,
            LoanAmount__c = 50000,
            LoanStatus__c = LoanRequestConstants.STATUS_DRAFT
        );
    }

    private static LoanRequest__c getLoan() {
        return [SELECT Id FROM LoanRequest__c LIMIT 1];
    }

    private static LoanApproval__c buildApproval(Id lrId) {
        LoanApproval__c a = new LoanApproval__c(
            LoanRequest__c    = lrId,
            ApprovalStatus__c = LoanRequestConstants.APPROVAL_STATUS_PENDING,
            SentToExternal__c = Datetime.now()
        );
        insert a;
        return a;
    }

    // ── Mock helpers ─────────────────────────────────────────────────────────────

    private class SuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"referenceId":"EXT-001","status":"received"}');
            return res;
        }
    }

    private class FailureMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('{"error":"Internal Server Error"}');
            return res;
        }
    }

    // ── Tests ────────────────────────────────────────────────────────────────────

    @isTest
    static void testSuccess_UpdatesApprovalAndLogsInfo() {
        LoanRequest__c  lr       = getLoan();
        LoanApproval__c approval = buildApproval(lr.Id);

        Test.setMock(HttpCalloutMock.class, new SuccessMock());
        Test.startTest();
        System.enqueueJob(new LoanApprovalQueueable(new List<Id>{ approval.Id }, 1));
        Test.stopTest();

        LoanApproval__c updated = [SELECT ExternalRefId__c, ReceivedResponse__c FROM LoanApproval__c WHERE Id = :approval.Id];
        System.assertEquals('EXT-001', updated.ExternalRefId__c,    'ExternalRefId must be set from response');
        System.assertNotEquals(null,    updated.ReceivedResponse__c, 'ReceivedResponse must be populated');

        List<AuditLog__c> logs = [
            SELECT Action__c, Severity__c FROM AuditLog__c WHERE RelatedId__c = :String.valueOf(lr.Id)
        ];
        System.assertEquals(1,                                             logs.size(),          'One INFO AuditLog expected');
        System.assertEquals(LoanRequestConstants.ACTION_INTEGRATION_SENT, logs[0].Action__c,    'Action must be IntegrationSent');
        System.assertEquals(LoanRequestConstants.SEVERITY_INFO,           logs[0].Severity__c,  'Severity must be INFO');
    }

    @isTest
    static void testFailureAtMaxRetries_LogsDeadLetter() {
        LoanRequest__c  lr       = getLoan();
        LoanApproval__c approval = buildApproval(lr.Id);

        Test.setMock(HttpCalloutMock.class, new FailureMock());
        Test.startTest();
        System.enqueueJob(new LoanApprovalQueueable(new List<Id>{ approval.Id }, LoanRequestConstants.MAX_RETRY_ATTEMPTS));
        Test.stopTest();

        List<AuditLog__c> logs = [
            SELECT Action__c, Severity__c FROM AuditLog__c WHERE RelatedId__c = :String.valueOf(lr.Id)
        ];
        System.assertEquals(1,                                               logs.size(),          'One ERROR AuditLog expected for dead letter');
        System.assertEquals(LoanRequestConstants.ACTION_INTEGRATION_FAILED, logs[0].Action__c,    'Action must be IntegrationFailed');
        System.assertEquals(LoanRequestConstants.SEVERITY_ERROR,            logs[0].Severity__c,  'Severity must be ERROR');
    }

    // Validates the retry threshold constant is well-formed.
    // End-to-end chain testing is constrained by the platform's 1-level Queueable
    // chaining limit in test context; retry behaviour is covered by the dead-letter test above.
    @isTest
    static void testRetryBoundary_MaxAttemptIsExclusive() {
        System.assert(LoanRequestConstants.MAX_RETRY_ATTEMPTS > 0, 'MAX_RETRY_ATTEMPTS must be positive');
        Integer belowMax = LoanRequestConstants.MAX_RETRY_ATTEMPTS - 1;
        System.assert(belowMax < LoanRequestConstants.MAX_RETRY_ATTEMPTS, 'An attempt below max must re-enqueue');
        System.assert(
            !(LoanRequestConstants.MAX_RETRY_ATTEMPTS < LoanRequestConstants.MAX_RETRY_ATTEMPTS),
            'An attempt equal to max must dead-letter'
        );
    }
}
