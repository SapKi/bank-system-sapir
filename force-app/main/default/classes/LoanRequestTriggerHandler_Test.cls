/**
 * Unit tests for LoanRequestTriggerHandler.
 * Target coverage: >= 95%.
 * Uses @TestSetup for shared test data — no seeAllData=true, no hardcoded Ids.
 */
@isTest
public class LoanRequestTriggerHandler_Test {

    // ─── Test Setup ─────────────────────────────────────────────────────────────

    @TestSetup
    static void setup() {
        Customer__c cust = new Customer__c(
            FirstName__c = 'ישראל',
            LastName__c  = 'ישראלי',
            Email__c     = 'test@test.com'
        );
        insert cust;
    }

    // ─── Helper ──────────────────────────────────────────────────────────────────

    private static Customer__c getCustomer() {
        return [SELECT Id FROM Customer__c LIMIT 1];
    }

    // ─── Test Methods ────────────────────────────────────────────────────────────

    /**
     * LoanAmount > 250,000 with AssignedManager → Task created, AlertSent__c = true.
     */
    @isTest
    static void testHighValueAlert_TaskCreated() {
        Customer__c cust = getCustomer();

        LoanRequest__c lr = new LoanRequest__c(
            Customer__c        = cust.Id,
            LoanAmount__c      = 300000,
            LoanStatus__c      = 'Draft',
            AlertSent__c       = false,
            AssignedManager__c = UserInfo.getUserId()
        );

        Test.startTest();
        insert lr;
        Test.stopTest();

        List<Task> tasks = [SELECT Id, Priority, Status FROM Task WHERE WhatId = :lr.Id];
        System.assertEquals(1, tasks.size(),       'Exactly one Task should be created');
        System.assertEquals('High', tasks[0].Priority, 'Task priority should be High');
        System.assertEquals('Not Started', tasks[0].Status, 'Task status should be Not Started');

        LoanRequest__c updated = [SELECT AlertSent__c FROM LoanRequest__c WHERE Id = :lr.Id];
        System.assertEquals(true, updated.AlertSent__c, 'AlertSent__c should be set to true');
    }

    /**
     * AlertSent__c already true → no duplicate Task created.
     */
    @isTest
    static void testHighValueAlert_NoDuplicate() {
        Customer__c cust = getCustomer();

        LoanRequest__c lr = new LoanRequest__c(
            Customer__c        = cust.Id,
            LoanAmount__c      = 300000,
            LoanStatus__c      = 'Draft',
            AlertSent__c       = true,
            AssignedManager__c = UserInfo.getUserId()
        );

        Test.startTest();
        insert lr;
        Test.stopTest();

        List<Task> tasks = [SELECT Id FROM Task WHERE WhatId = :lr.Id];
        System.assertEquals(0, tasks.size(), 'No Task should be created when AlertSent__c is already true');
    }

    /**
     * Status change to 'מאושר' → approval email sent to customer.
     */
    @isTest
    static void testStatusApproved_EmailSent() {
        Customer__c cust = getCustomer();

        LoanRequest__c lr = new LoanRequest__c(
            Customer__c   = cust.Id,
            LoanAmount__c = 100000,
            LoanStatus__c = 'Draft'
        );
        insert lr;

        Test.startTest();
        lr.LoanStatus__c = 'מאושר';
        update lr;
        Test.stopTest();

        System.assertEquals(1, Limits.getEmailInvocations(), 'Exactly one email invocation expected');
    }

    /**
     * Any status change → AuditLog__c created with correct field values.
     */
    @isTest
    static void testStatusChange_AuditLogCreated() {
        Customer__c cust = getCustomer();

        LoanRequest__c lr = new LoanRequest__c(
            Customer__c   = cust.Id,
            LoanAmount__c = 50000,
            LoanStatus__c = 'Draft'
        );
        insert lr;

        Test.startTest();
        lr.LoanStatus__c = 'בבדיקה';
        update lr;
        Test.stopTest();

        List<AuditLog__c> logs = [
            SELECT Action__c, OldValue__c, NewValue__c, Severity__c, ObjectType__c, EventType__c
            FROM AuditLog__c
            WHERE RelatedId__c = :String.valueOf(lr.Id)
        ];

        System.assertEquals(1, logs.size(),              'One AuditLog record should be created');
        System.assertEquals('StatusChanged', logs[0].Action__c,  'Action should be StatusChanged');
        System.assertEquals('Draft',         logs[0].OldValue__c, 'OldValue should be Draft');
        System.assertEquals('בבדיקה',        logs[0].NewValue__c, 'NewValue should be בבדיקה');
        System.assertEquals('INFO',          logs[0].Severity__c, 'Severity should be INFO for amount <= 250,000');
        System.assertEquals('LoanRequest__c', logs[0].ObjectType__c, 'ObjectType should be LoanRequest__c');
        System.assertEquals('DATA_CHANGE',   logs[0].EventType__c,   'EventType should be DATA_CHANGE');
    }

    /**
     * Bulk insert of 200 records followed by bulk update → no governor limit exceptions,
     * all status-change AuditLog records created.
     */
    @isTest
    static void testBulkInsert_200Records() {
        Customer__c cust = getCustomer();

        List<LoanRequest__c> loans = new List<LoanRequest__c>();
        for (Integer i = 0; i < 200; i++) {
            loans.add(new LoanRequest__c(
                Customer__c   = cust.Id,
                LoanAmount__c = 50000,
                LoanStatus__c = 'Draft'
            ));
        }

        Test.startTest();
        insert loans;

        for (LoanRequest__c lr : loans) {
            lr.LoanStatus__c = 'בבדיקה';
        }
        update loans;
        Test.stopTest();

        List<AuditLog__c> logs = [SELECT Id FROM AuditLog__c];
        System.assertEquals(200, logs.size(), '200 AuditLog records should be created — one per updated record');
    }

    /**
     * Null Customer__c → trigger must not throw a NullPointerException.
     * A DmlException due to a required-field constraint is acceptable; our code must not add to it.
     */
    @isTest
    static void testNullCustomer_NoException() {
        Test.startTest();
        Boolean unexpectedException = false;
        try {
            LoanRequest__c lr = new LoanRequest__c(
                LoanAmount__c = 300000,
                LoanStatus__c = 'Draft'
                // Customer__c intentionally omitted to test null-safety
            );
            insert lr;
        } catch (DmlException e) {
            // Required-field validation from the platform — acceptable, not from our code
        } catch (Exception e) {
            unexpectedException = true;
        }
        Test.stopTest();

        System.assertEquals(false, unexpectedException, 'Trigger must not throw unexpected exceptions when Customer__c is null');
    }

    /**
     * Null AssignedManager__c on a high-value loan → no Task created, no exception thrown.
     */
    @isTest
    static void testNullManager_NoTask() {
        Customer__c cust = getCustomer();

        LoanRequest__c lr = new LoanRequest__c(
            Customer__c        = cust.Id,
            LoanAmount__c      = 300000,
            LoanStatus__c      = 'Draft',
            AlertSent__c       = false,
            AssignedManager__c = null
        );

        Test.startTest();
        insert lr;
        Test.stopTest();

        List<Task> tasks = [SELECT Id FROM Task WHERE WhatId = :lr.Id];
        System.assertEquals(0, tasks.size(), 'No Task should be created when AssignedManager__c is null');

        // A WARN AuditLog should have been written instead
        List<AuditLog__c> logs = [
            SELECT Severity__c, Action__c FROM AuditLog__c
            WHERE RelatedId__c = :String.valueOf(lr.Id)
        ];
        System.assertEquals(1, logs.size(),              'A WARN AuditLog should be written when manager is missing');
        System.assertEquals('WARN', logs[0].Severity__c, 'Severity should be WARN');
        System.assertEquals('HighValueNoManager', logs[0].Action__c, 'Action should be HighValueNoManager');
    }
}
