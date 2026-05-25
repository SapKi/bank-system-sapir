/**
 * Handler for LoanRequestTrigger.
 * Enforces sharing rules (with sharing) — FLS is enforced via WITH SECURITY_ENFORCED in SOQL.
 */
public with sharing class LoanRequestTriggerHandler {

    // Prevents recursive execution when AlertSent__c is updated by this handler
    private static Boolean alreadyRun = false;

    public static void handle(List<LoanRequest__c> newList, Map<Id, LoanRequest__c> oldMap) {
        if (alreadyRun) return;
        alreadyRun = true;

        handleHighValueAlert(newList);
        handleStatusChange(newList, oldMap);
    }

    // ─── Section 1: High-Value Task Creation ────────────────────────────────────

    /**
     * Creates a Task for AssignedManager__c when LoanAmount__c > 250,000.
     * Sets AlertSent__c = true to prevent duplicate Tasks across updates.
     */
    private static void handleHighValueAlert(List<LoanRequest__c> newList) {
        List<Task>           tasksToInsert  = new List<Task>();
        List<LoanRequest__c> recordsToFlag  = new List<LoanRequest__c>();
        List<AuditLog__c>    logsToInsert   = new List<AuditLog__c>();

        for (LoanRequest__c lr : newList) {
            if (lr.LoanAmount__c == null || lr.LoanAmount__c <= 250000 || lr.AlertSent__c == true) {
                continue;
            }
            if (lr.AssignedManager__c != null) {
                tasksToInsert.add(new Task(
                    Subject      = 'בקשת הלוואה גבוהה — דורשת אישור מנהל',
                    Priority     = 'High',
                    Status       = 'Not Started',
                    ActivityDate = Date.today().addDays(3),
                    OwnerId      = lr.AssignedManager__c,
                    WhatId       = lr.Id
                ));
                recordsToFlag.add(new LoanRequest__c(Id = lr.Id, AlertSent__c = true));
            } else {
                // No manager — skip Task creation, log warning
                logsToInsert.add(AuditLogService.buildLog(
                    lr.Id, 'LoanRequest__c', 'DATA_CHANGE',
                    'HighValueNoManager', 'WARN',
                    null, String.valueOf(lr.LoanAmount__c)
                ));
            }
        }

        // Single DML for Tasks
        if (!tasksToInsert.isEmpty()) {
            try {
                insert tasksToInsert;
            } catch (DmlException e) {
                logsToInsert.add(AuditLogService.buildLog(
                    null, 'LoanRequest__c', 'DATA_CHANGE',
                    'TaskInsertFailed', 'ERROR', null, e.getMessage()
                ));
            }
        }

        // Single DML to set AlertSent__c = true
        // This update fires the trigger again; alreadyRun = true causes it to return immediately
        if (!recordsToFlag.isEmpty()) {
            try {
                update recordsToFlag;
            } catch (DmlException e) {
                logsToInsert.add(AuditLogService.buildLog(
                    null, 'LoanRequest__c', 'DATA_CHANGE',
                    'AlertFlagUpdateFailed', 'ERROR', null, e.getMessage()
                ));
            }
        }

        if (!logsToInsert.isEmpty()) {
            try {
                insert logsToInsert;
            } catch (DmlException e) {
                System.debug(LoggingLevel.ERROR, 'AuditLog insert failed: ' + e.getMessage());
            }
        }
    }

    // ─── Section 2: Status Change — Email + Audit Log ───────────────────────────

    /**
     * Sends an approval email and writes an AuditLog__c record for every status change.
     * SOQL executes before the loop — bulk-safe for batches of up to 200 records.
     */
    private static void handleStatusChange(List<LoanRequest__c> newList, Map<Id, LoanRequest__c> oldMap) {
        if (oldMap == null) return; // After insert — no previous status to compare

        Set<Id>              customerIds  = new Set<Id>();
        List<LoanRequest__c> changedRecs  = new List<LoanRequest__c>();

        for (LoanRequest__c lr : newList) {
            LoanRequest__c oldLr = oldMap.get(lr.Id);
            if (oldLr != null && lr.LoanStatus__c != oldLr.LoanStatus__c) {
                changedRecs.add(lr);
                if (lr.Customer__c != null) {
                    customerIds.add(lr.Customer__c);
                }
            }
        }

        if (changedRecs.isEmpty()) return;

        // SOQL before the loop — result stored in Map for O(1) access per record
        Map<Id, Customer__c> custMap = customerIds.isEmpty()
            ? new Map<Id, Customer__c>()
            : new Map<Id, Customer__c>(
                [SELECT Id, FirstName__c, LastName__c, Email__c
                 FROM Customer__c
                 WHERE Id IN :customerIds
                 WITH SECURITY_ENFORCED]);

        List<AuditLog__c>                   logsToInsert = new List<AuditLog__c>();
        List<Messaging.SingleEmailMessage>  emails       = new List<Messaging.SingleEmailMessage>();

        for (LoanRequest__c lr : changedRecs) {
            String oldStatus = oldMap.get(lr.Id).LoanStatus__c;
            String newStatus = lr.LoanStatus__c;
            String severity  = (lr.LoanAmount__c != null && lr.LoanAmount__c > 250000) ? 'WARN' : 'INFO';

            // Audit every status change
            logsToInsert.add(AuditLogService.buildLog(
                lr.Id, 'LoanRequest__c', 'DATA_CHANGE',
                'StatusChanged', severity, oldStatus, newStatus
            ));

            // Email only on approval
            if (newStatus == 'מאושר') {
                Customer__c cust = lr.Customer__c != null ? custMap.get(lr.Customer__c) : null;
                if (cust != null && String.isNotBlank(cust.Email__c)) {
                    emails.add(EmailService.buildApprovalEmail(cust, lr));
                } else {
                    String reason = cust == null ? 'Customer not found' : 'Customer has no email address';
                    logsToInsert.add(AuditLogService.buildLog(
                        lr.Id, 'LoanRequest__c', 'DATA_CHANGE',
                        'EmailSkipped', 'WARN', null, reason
                    ));
                }
            }
        }

        // Single DML for all audit logs
        if (!logsToInsert.isEmpty()) {
            try {
                insert logsToInsert;
            } catch (DmlException e) {
                System.debug(LoggingLevel.ERROR, 'AuditLog insert failed: ' + e.getMessage());
            }
        }

        // Single sendEmail call for all approval emails — one invocation regardless of record count
        if (!emails.isEmpty()) {
            try {
                Messaging.sendEmail(emails, false);
            } catch (EmailException e) {
                System.debug(LoggingLevel.ERROR, 'Email send failed: ' + e.getMessage());
            }
        }
    }
}
