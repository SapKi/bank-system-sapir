// ─────────────────────────────────────────────────────────────────────────────
// DEMO SCRIPT — exercises every business requirement in one run.
// Run via: sf apex run --target-org my-scratch-org --file scripts/demo_data.apex
// ─────────────────────────────────────────────────────────────────────────────

// 1. Customer
Customer__c cust = new Customer__c(
    FirstName__c = 'Sapir',
    LastName__c  = 'Demo',
    Email__c     = 'sapir.demo@test.com',
    RiskLevel__c = 'High'
);
insert cust;
System.debug('✔ Customer created: ' + cust.Id);

// 2. High-Value Loan — no manager assigned
//    → Requirement: WARN AuditLog (HighValueNoManager), no Task
LoanRequest__c lrNoManager = new LoanRequest__c(
    Customer__c   = cust.Id,
    LoanAmount__c = 300000,
    LoanType__c   = 'Mortgage',
    TermMonths__c = 240,
    LoanStatus__c = 'Draft'
);
insert lrNoManager;
System.debug('✔ High-value loan (no manager) created: ' + lrNoManager.Id);

// 3. High-Value Loan — manager assigned
//    → Requirement: Task created, AlertSent__c = true
LoanRequest__c lrWithManager = new LoanRequest__c(
    Customer__c        = cust.Id,
    LoanAmount__c      = 500000,
    LoanType__c        = 'Business',
    TermMonths__c      = 120,
    LoanStatus__c      = 'Draft',
    AssignedManager__c = UserInfo.getUserId()
);
insert lrWithManager;
System.debug('✔ High-value loan (with manager) created: ' + lrWithManager.Id);

// 4. Status change: Draft → In Review
//    → Requirement: AuditLog (StatusChanged, WARN because amount > 250k)
lrWithManager.LoanStatus__c = 'In Review';
update lrWithManager;
System.debug('✔ Status changed to In Review');

// 5. Status change: In Review → Approved
//    → Requirement: AuditLog (StatusChanged) + approval email sent
lrWithManager.LoanStatus__c = 'Approved';
update lrWithManager;
System.debug('✔ Status changed to Approved — email should be queued');

// 6. A fresh loan — status → Submitted
//    → Requirement: LoanApproval__c created, Queueable dispatched
//      (Queueable will fail the HTTP call since Named Credential has no real endpoint,
//       but you can see the LoanApproval record and, after async runs, the ERROR AuditLog)
LoanRequest__c lrSubmit = new LoanRequest__c(
    Customer__c        = cust.Id,
    LoanAmount__c      = 150000,
    LoanType__c        = 'Personal',
    TermMonths__c      = 60,
    LoanStatus__c      = 'Draft',
    AssignedManager__c = UserInfo.getUserId()
);
insert lrSubmit;
lrSubmit.LoanStatus__c = 'Submitted';
update lrSubmit;
System.debug('✔ Status changed to Submitted — LoanApproval created, Queueable enqueued');

// ── Print record IDs for easy navigation ─────────────────────────────────────
System.debug('');
System.debug('=== RECORD IDs (copy into the URL bar in Setup → Object Manager → Records) ===');
System.debug('Customer Id:                  ' + cust.Id);
System.debug('LoanRequest (no manager):     ' + lrNoManager.Id);
System.debug('LoanRequest (with manager):   ' + lrWithManager.Id);
System.debug('LoanRequest (submitted):      ' + lrSubmit.Id);

List<AuditLog__c> logs = [SELECT Id, Action__c, Severity__c, OldValue__c, NewValue__c FROM AuditLog__c ORDER BY Timestamp__c];
System.debug('');
System.debug('=== AuditLog records created (' + logs.size() + ') ===');
for (AuditLog__c l : logs) {
    System.debug('[' + l.Severity__c + '] ' + l.Action__c + '  |  ' + l.OldValue__c + ' → ' + l.NewValue__c + '  |  Id: ' + l.Id);
}

List<Task> tasks = [SELECT Id, Subject, Priority, Status, WhatId FROM Task WHERE WhatId = :lrWithManager.Id];
System.debug('');
System.debug('=== Tasks on high-value loan (' + tasks.size() + ') ===');
for (Task t : tasks) {
    System.debug('[' + t.Priority + '] ' + t.Subject + '  |  Id: ' + t.Id);
}

List<LoanApproval__c> approvals = [SELECT Id, ApprovalStatus__c, SentToExternal__c FROM LoanApproval__c];
System.debug('');
System.debug('=== LoanApproval records (' + approvals.size() + ') ===');
for (LoanApproval__c a : approvals) {
    System.debug('[' + a.ApprovalStatus__c + '] Sent: ' + a.SentToExternal__c + '  |  Id: ' + a.Id);
}
