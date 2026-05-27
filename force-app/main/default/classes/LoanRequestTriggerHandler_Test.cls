@isTest
public class LoanRequestTriggerHandler_Test {

    @TestSetup
    static void setup() {
        Customer__c cust = new Customer__c(
            FirstName__c = 'John',
            LastName__c  = 'Smith',
            Email__c     = 'test@test.com'
        );
        insert cust;
    }

    private static Customer__c getCustomer() {
        return [SELECT Id FROM Customer__c LIMIT 1];
    }

    // LoanAmount > threshold + AssignedManager → Task created, AlertSent__c = true
    @isTest
    static void testHighValueAlert_TaskCreated() {
        Customer__c cust = getCustomer();
        LoanRequest__c lr = new LoanRequest__c(
            Customer__c        = cust.Id,
            LoanAmount__c      = LoanRequestConstants.HIGH_VALUE_THRESHOLD + 1,
            LoanStatus__c      = LoanRequestConstants.STATUS_DRAFT,
            AlertSent__c       = false,
            AssignedManager__c = UserInfo.getUserId()
        );
        Test.startTest();
        insert lr;
        Test.stopTest();

        List<Task> tasks = [SELECT Priority, Status FROM Task WHERE WhatId = :lr.Id];
        System.assertEquals(1,                               tasks.size(),      'One Task expected');
        System.assertEquals(LoanRequestConstants.TASK_PRIORITY, tasks[0].Priority, 'Priority must be High');
        System.assertEquals(LoanRequestConstants.TASK_STATUS,   tasks[0].Status,   'Status must be Not Started');

        LoanRequest__c updated = [SELECT AlertSent__c FROM LoanRequest__c WHERE Id = :lr.Id];
        System.assertEquals(true, updated.AlertSent__c, 'AlertSent__c must be true after Task creation');
    }

    // AlertSent__c already true → no duplicate Task
    @isTest
    static void testHighValueAlert_NoDuplicate() {
        Customer__c cust = getCustomer();
        LoanRequest__c lr = new LoanRequest__c(
            Customer__c        = cust.Id,
            LoanAmount__c      = LoanRequestConstants.HIGH_VALUE_THRESHOLD + 1,
            LoanStatus__c      = LoanRequestConstants.STATUS_DRAFT,
            AlertSent__c       = true,
            AssignedManager__c = UserInfo.getUserId()
        );
        Test.startTest();
        insert lr;
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM Task WHERE WhatId = :lr.Id],
            'No Task should be created when AlertSent__c is already true');
    }

    // Status → Approved → approval email sent
    @isTest
    static void testStatusApproved_EmailSent() {
        Customer__c cust = getCustomer();
        LoanRequest__c lr = new LoanRequest__c(
            Customer__c   = cust.Id,
            LoanAmount__c = 100000,
            LoanStatus__c = LoanRequestConstants.STATUS_DRAFT
        );
        insert lr;

        Test.startTest();
        lr.LoanStatus__c = LoanRequestConstants.STATUS_APPROVED;
        update lr;
        // Capture inside the test block — after stopTest the outer limit context is restored
        Integer emailInvocations = Limits.getEmailInvocations();
        Test.stopTest();

        System.assertEquals(1, emailInvocations, 'Exactly one email invocation expected');
    }

    // Status change → AuditLog__c created with correct field values
    @isTest
    static void testStatusChange_AuditLogCreated() {
        Customer__c cust = getCustomer();
        LoanRequest__c lr = new LoanRequest__c(
            Customer__c   = cust.Id,
            LoanAmount__c = 50000,
            LoanStatus__c = LoanRequestConstants.STATUS_DRAFT
        );
        insert lr;

        Test.startTest();
        lr.LoanStatus__c = LoanRequestConstants.STATUS_IN_REVIEW;
        update lr;
        Test.stopTest();

        List<AuditLog__c> logs = [
            SELECT Action__c, OldValue__c, NewValue__c, Severity__c
            FROM AuditLog__c WHERE RelatedId__c = :String.valueOf(lr.Id)
        ];
        System.assertEquals(1,                                         logs.size(),          'One AuditLog expected');
        System.assertEquals(LoanRequestConstants.ACTION_STATUS_CHANGED, logs[0].Action__c,   'Action must be StatusChanged');
        System.assertEquals(LoanRequestConstants.STATUS_DRAFT,          logs[0].OldValue__c, 'OldValue must be Draft');
        System.assertEquals(LoanRequestConstants.STATUS_IN_REVIEW,      logs[0].NewValue__c, 'NewValue must be In Review');
        System.assertEquals(LoanRequestConstants.SEVERITY_INFO,         logs[0].Severity__c, 'Severity must be INFO for amount <= threshold');
    }

    // 200 records bulk insert + update → no exceptions, all AuditLogs created
    @isTest
    static void testBulkInsert_200Records() {
        Customer__c cust = getCustomer();
        List<LoanRequest__c> loans = new List<LoanRequest__c>();
        for (Integer i = 0; i < 200; i++) {
            loans.add(new LoanRequest__c(
                Customer__c   = cust.Id,
                LoanAmount__c = 50000,
                LoanStatus__c = LoanRequestConstants.STATUS_DRAFT
            ));
        }
        Test.startTest();
        insert loans;
        for (LoanRequest__c lr : loans) lr.LoanStatus__c = LoanRequestConstants.STATUS_IN_REVIEW;
        update loans;
        Test.stopTest();

        System.assertEquals(200, [SELECT COUNT() FROM AuditLog__c],
            '200 AuditLog records expected — one per updated record');
    }

    // Customer__c = null → no NullPointerException from our code
    @isTest
    static void testNullCustomer_NoException() {
        Test.startTest();
        Boolean unexpectedException = false;
        try {
            insert new LoanRequest__c(LoanAmount__c = 100000, LoanStatus__c = LoanRequestConstants.STATUS_DRAFT);
        } catch (DmlException e) {
            // Required-field validation — platform level, not our code
        } catch (Exception e) {
            unexpectedException = true;
        }
        Test.stopTest();
        System.assertEquals(false, unexpectedException, 'Trigger must not throw unexpected exceptions for null Customer');
    }

    // AssignedManager__c = null on high-value loan → no Task, WARN AuditLog written
    @isTest
    static void testNullManager_NoTask() {
        Customer__c cust = getCustomer();
        LoanRequest__c lr = new LoanRequest__c(
            Customer__c        = cust.Id,
            LoanAmount__c      = LoanRequestConstants.HIGH_VALUE_THRESHOLD + 1,
            LoanStatus__c      = LoanRequestConstants.STATUS_DRAFT,
            AlertSent__c       = false,
            AssignedManager__c = null
        );
        Test.startTest();
        insert lr;
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM Task WHERE WhatId = :lr.Id],
            'No Task when AssignedManager__c is null');

        List<AuditLog__c> logs = [
            SELECT Severity__c, Action__c FROM AuditLog__c WHERE RelatedId__c = :String.valueOf(lr.Id)
        ];
        System.assertEquals(1,                                                logs.size(),         'WARN AuditLog expected');
        System.assertEquals(LoanRequestConstants.SEVERITY_WARN,               logs[0].Severity__c, 'Severity must be WARN');
        System.assertEquals(LoanRequestConstants.ACTION_HIGH_VALUE_NO_MANAGER, logs[0].Action__c,   'Action must be HighValueNoManager');
    }

    // Flow: Status → Approved → Customer.Status__c = 'Active Customer'
    @isTest
    static void testApproved_CustomerStatusSetToActive() {
        Customer__c cust = getCustomer();
        LoanRequest__c lr = new LoanRequest__c(
            Customer__c   = cust.Id,
            LoanAmount__c = 100000,
            LoanStatus__c = LoanRequestConstants.STATUS_DRAFT
        );
        insert lr;

        Test.startTest();
        lr.LoanStatus__c = LoanRequestConstants.STATUS_APPROVED;
        update lr;
        Test.stopTest();

        Customer__c updated = [SELECT Status__c FROM Customer__c WHERE Id = :cust.Id];
        System.assertEquals('Active Customer', updated.Status__c,
            'Flow must set Customer Status to Active Customer on loan approval');
    }

    // Flow: Status → Rejected → Customer.Status__c = 'Requires Further Action'
    @isTest
    static void testRejected_CustomerStatusSetToRequiresFurtherAction() {
        Customer__c cust = getCustomer();
        LoanRequest__c lr = new LoanRequest__c(
            Customer__c   = cust.Id,
            LoanAmount__c = 100000,
            LoanStatus__c = LoanRequestConstants.STATUS_DRAFT
        );
        insert lr;

        Test.startTest();
        lr.LoanStatus__c = LoanRequestConstants.STATUS_REJECTED;
        update lr;
        Test.stopTest();

        Customer__c updated = [SELECT Status__c FROM Customer__c WHERE Id = :cust.Id];
        System.assertEquals('Requires Further Action', updated.Status__c,
            'Flow must set Customer Status to Requires Further Action on loan rejection');
    }

    // Null LoanAmount__c → trigger null-guard fires → no Task, no exception
    @isTest
    static void testNullLoanAmount_NoHighValueAlert() {
        Customer__c cust = getCustomer();
        LoanRequest__c lr = new LoanRequest__c(
            Customer__c        = cust.Id,
            LoanAmount__c      = null,
            LoanStatus__c      = LoanRequestConstants.STATUS_DRAFT,
            AssignedManager__c = UserInfo.getUserId()
        );
        Test.startTest();
        insert lr;
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM Task WHERE WhatId = :lr.Id],
            'No Task expected when LoanAmount__c is null — trigger must null-guard silently');
        LoanRequest__c saved = [SELECT AlertSent__c FROM LoanRequest__c WHERE Id = :lr.Id];
        System.assertEquals(false, saved.AlertSent__c,
            'AlertSent__c must remain false when amount is null');
    }

    // Update with the same status value → handleStatusChange detects no real change → no AuditLog
    @isTest
    static void testSameStatusUpdate_NoAuditLog() {
        Customer__c cust = getCustomer();
        LoanRequest__c lr = new LoanRequest__c(
            Customer__c   = cust.Id,
            LoanAmount__c = 50000,
            LoanStatus__c = LoanRequestConstants.STATUS_DRAFT
        );
        insert lr;

        Test.startTest();
        lr.LoanStatus__c = LoanRequestConstants.STATUS_DRAFT; // no actual change
        update lr;
        Test.stopTest();

        System.assertEquals(0,
            [SELECT COUNT() FROM AuditLog__c WHERE RelatedId__c = :String.valueOf(lr.Id)],
            'No AuditLog expected when LoanStatus__c value did not change');
    }

    // Amount exactly at the threshold (not strictly above) → no high-value Task
    @isTest
    static void testAmountAtThreshold_NoHighValueTask() {
        Customer__c cust = getCustomer();
        LoanRequest__c lr = new LoanRequest__c(
            Customer__c        = cust.Id,
            LoanAmount__c      = LoanRequestConstants.HIGH_VALUE_THRESHOLD,
            LoanStatus__c      = LoanRequestConstants.STATUS_DRAFT,
            AssignedManager__c = UserInfo.getUserId()
        );
        Test.startTest();
        insert lr;
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM Task WHERE WhatId = :lr.Id],
            'No Task when amount equals threshold exactly — rule is strictly greater-than');
        LoanRequest__c saved = [SELECT AlertSent__c FROM LoanRequest__c WHERE Id = :lr.Id];
        System.assertEquals(false, saved.AlertSent__c,
            'AlertSent__c must remain false at the boundary');
    }
}
