public with sharing class LoanRequestTriggerHandler implements ITriggerHandler {

    private static Boolean alreadyRun = false;

    // ── ITriggerHandler interface ────────────────────────────────────────────────

    public void afterInsert(List<SObject> newRecords) {
        processRecords((List<LoanRequest__c>) newRecords, null);
    }

    public void afterUpdate(List<SObject> newRecords, Map<Id, SObject> oldRecords) {
        processRecords(
            (List<LoanRequest__c>) newRecords,
            (Map<Id, LoanRequest__c>) oldRecords
        );
    }

    // ── Core orchestration ───────────────────────────────────────────────────────

    private static void processRecords(List<LoanRequest__c> newList, Map<Id, LoanRequest__c> oldMap) {
        if (alreadyRun) return;
        alreadyRun = true;
        try {
            handleHighValueAlert(newList);
            handleStatusChange(newList, oldMap);
            handleIntegration(newList, oldMap);
        } finally {
            // Reset after full execution so subsequent legitimate DML operations
            // (e.g., a user update after an insert) are still processed.
            // The flag correctly blocks only the recursive inner call triggered
            // by the AlertSent__c update inside handleHighValueAlert.
            alreadyRun = false;
        }
    }

    // ── Section 1: High-Value Task Creation ─────────────────────────────────────

    private static void handleHighValueAlert(List<LoanRequest__c> newList) {
        List<Task>           tasksToInsert = new List<Task>();
        List<LoanRequest__c> recordsToFlag = new List<LoanRequest__c>();
        List<AuditLog__c>    logsToInsert  = new List<AuditLog__c>();

        for (LoanRequest__c lr : newList) {
            if (lr.LoanAmount__c == null
                || lr.LoanAmount__c <= LoanRequestConstants.HIGH_VALUE_THRESHOLD
                || lr.AlertSent__c == true) {
                continue;
            }
            if (lr.AssignedManager__c != null) {
                tasksToInsert.add(new Task(
                    Subject      = LoanRequestConstants.TASK_SUBJECT,
                    Priority     = LoanRequestConstants.TASK_PRIORITY,
                    Status       = LoanRequestConstants.TASK_STATUS,
                    ActivityDate = Date.today().addDays(LoanRequestConstants.TASK_DUE_DAYS),
                    OwnerId      = lr.AssignedManager__c,
                    WhatId       = lr.Id
                ));
                recordsToFlag.add(new LoanRequest__c(Id = lr.Id, AlertSent__c = true));
            } else {
                logsToInsert.add(AuditLogService.buildLog(
                    lr.Id,
                    LoanRequestConstants.OBJ_LOAN_REQUEST,
                    LoanRequestConstants.EVENT_DATA_CHANGE,
                    LoanRequestConstants.ACTION_HIGH_VALUE_NO_MANAGER,
                    LoanRequestConstants.SEVERITY_WARN,
                    null,
                    String.valueOf(lr.LoanAmount__c)
                ));
            }
        }

        if (!tasksToInsert.isEmpty()) {
            try {
                insert tasksToInsert;
            } catch (DmlException e) {
                logsToInsert.add(AuditLogService.buildLog(
                    null,
                    LoanRequestConstants.OBJ_LOAN_REQUEST,
                    LoanRequestConstants.EVENT_DATA_CHANGE,
                    LoanRequestConstants.ACTION_TASK_INSERT_FAILED,
                    LoanRequestConstants.SEVERITY_ERROR,
                    null, e.getMessage()
                ));
            }
        }

        // This update re-fires the trigger; alreadyRun = true causes it to return immediately
        if (!recordsToFlag.isEmpty()) {
            try {
                update recordsToFlag;
            } catch (DmlException e) {
                logsToInsert.add(AuditLogService.buildLog(
                    null,
                    LoanRequestConstants.OBJ_LOAN_REQUEST,
                    LoanRequestConstants.EVENT_DATA_CHANGE,
                    LoanRequestConstants.ACTION_ALERT_FLAG_FAILED,
                    LoanRequestConstants.SEVERITY_ERROR,
                    null, e.getMessage()
                ));
            }
        }

        if (!logsToInsert.isEmpty()) {
            try { insert logsToInsert; } catch (DmlException e) {
                System.debug(LoggingLevel.ERROR, 'AuditLog insert failed: ' + e.getMessage());
            }
        }

        sendManagerNotifications(newList);
    }

    private static void sendManagerNotifications(List<LoanRequest__c> newList) {
        List<CustomNotificationType> notifTypes = [
            SELECT Id FROM CustomNotificationType
            WHERE DeveloperName = :LoanRequestConstants.NOTIF_TYPE_API_NAME
            LIMIT 1
        ];
        if (notifTypes.isEmpty()) return;
        String notifTypeId = notifTypes[0].Id;

        for (LoanRequest__c lr : newList) {
            if (lr.LoanAmount__c == null
                || lr.LoanAmount__c <= LoanRequestConstants.HIGH_VALUE_THRESHOLD
                || lr.AssignedManager__c == null
                || lr.AlertSent__c != true) {
                continue;
            }
            try {
                Messaging.CustomNotification notif = new Messaging.CustomNotification();
                notif.setNotificationTypeId(notifTypeId);
                notif.setTargetId(lr.Id);
                notif.setTitle('High-Value Loan Request Requires Approval');
                notif.setBody('Loan amount: ' + lr.LoanAmount__c.format() + ' — please review and action.');
                notif.send(new Set<String>{ lr.AssignedManager__c });
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'CustomNotification failed: ' + e.getMessage());
            }
        }
    }

    // ── Section 2: Status Change — Email + Audit Log ─────────────────────────────

    private static void handleStatusChange(List<LoanRequest__c> newList, Map<Id, LoanRequest__c> oldMap) {
        if (oldMap == null) return;

        Set<Id>              customerIds = new Set<Id>();
        List<LoanRequest__c> changedRecs = new List<LoanRequest__c>();

        for (LoanRequest__c lr : newList) {
            LoanRequest__c oldLr = oldMap.get(lr.Id);
            if (oldLr != null && lr.LoanStatus__c != oldLr.LoanStatus__c) {
                changedRecs.add(lr);
                if (lr.Customer__c != null) customerIds.add(lr.Customer__c);
            }
        }

        if (changedRecs.isEmpty()) return;

        Map<Id, Customer__c> custMap = CustomerSelector.getByIds(customerIds);

        List<AuditLog__c>                  logsToInsert = new List<AuditLog__c>();
        List<Messaging.SingleEmailMessage> emails       = new List<Messaging.SingleEmailMessage>();

        for (LoanRequest__c lr : changedRecs) {
            String oldStatus = oldMap.get(lr.Id).LoanStatus__c;
            String newStatus = lr.LoanStatus__c;
            String severity  = (lr.LoanAmount__c != null
                && lr.LoanAmount__c > LoanRequestConstants.HIGH_VALUE_THRESHOLD)
                ? LoanRequestConstants.SEVERITY_WARN
                : LoanRequestConstants.SEVERITY_INFO;

            logsToInsert.add(AuditLogService.buildLog(
                lr.Id,
                LoanRequestConstants.OBJ_LOAN_REQUEST,
                LoanRequestConstants.EVENT_DATA_CHANGE,
                LoanRequestConstants.ACTION_STATUS_CHANGED,
                severity, oldStatus, newStatus
            ));

            if (newStatus == LoanRequestConstants.STATUS_APPROVED) {
                Customer__c cust = lr.Customer__c != null ? custMap.get(lr.Customer__c) : null;
                if (cust != null && String.isNotBlank(cust.Email__c)) {
                    emails.add(EmailService.buildApprovalEmail(cust, lr));
                } else {
                    String reason = cust == null ? 'Customer not found' : 'Customer has no email address';
                    logsToInsert.add(AuditLogService.buildLog(
                        lr.Id,
                        LoanRequestConstants.OBJ_LOAN_REQUEST,
                        LoanRequestConstants.EVENT_DATA_CHANGE,
                        LoanRequestConstants.ACTION_EMAIL_SKIPPED,
                        LoanRequestConstants.SEVERITY_WARN,
                        null, reason
                    ));
                }
            }
        }

        if (!logsToInsert.isEmpty()) {
            try { insert logsToInsert; } catch (DmlException e) {
                System.debug(LoggingLevel.ERROR, 'AuditLog insert failed: ' + e.getMessage());
            }
        }

        if (!emails.isEmpty()) {
            try { Messaging.sendEmail(emails, false); } catch (EmailException e) {
                System.debug(LoggingLevel.ERROR, 'Email send failed: ' + e.getMessage());
            }
        }
    }

    // ── Section 3: Integration — Dispatch Queueable on Submission ────────────────
    //
    // Scalability note: all LoanApproval__c records are inserted in one DML call
    // and a SINGLE Queueable is enqueued regardless of batch size, avoiding the
    // 50-enqueued-jobs-per-transaction governor limit.

    private static void handleIntegration(List<LoanRequest__c> newList, Map<Id, LoanRequest__c> oldMap) {
        if (oldMap == null) return;

        List<LoanApproval__c> approvalsToInsert = new List<LoanApproval__c>();

        for (LoanRequest__c lr : newList) {
            LoanRequest__c oldLr = oldMap.get(lr.Id);
            if (oldLr != null
                && lr.LoanStatus__c == LoanRequestConstants.STATUS_SUBMITTED
                && oldLr.LoanStatus__c != LoanRequestConstants.STATUS_SUBMITTED) {
                approvalsToInsert.add(new LoanApproval__c(
                    LoanRequest__c    = lr.Id,
                    ApprovalStatus__c = LoanRequestConstants.APPROVAL_STATUS_PENDING,
                    SentToExternal__c = Datetime.now()
                ));
            }
        }

        if (approvalsToInsert.isEmpty()) return;

        try {
            LoanApprovalService.insertApprovals(approvalsToInsert);
        } catch (DmlException e) {
            AuditLogService.log(
                null,
                LoanRequestConstants.OBJ_LOAN_APPROVAL,
                LoanRequestConstants.EVENT_INTEGRATION,
                LoanRequestConstants.ACTION_INTEGRATION_FAILED,
                LoanRequestConstants.SEVERITY_ERROR,
                null, e.getMessage()
            );
            return;
        }

        List<Id> approvalIds = new List<Id>();
        for (LoanApproval__c a : approvalsToInsert) approvalIds.add(a.Id);
        System.enqueueJob(new LoanApprovalQueueable(approvalIds, 1));
    }
}
