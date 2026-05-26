// Re-triggers the approval email on the existing loan
LoanRequest__c lr = [
    SELECT Id, LoanStatus__c
    FROM LoanRequest__c
    WHERE Customer__c IN (SELECT Id FROM Customer__c WHERE Email__c = 'sapirkikoz@gmail.com')
    ORDER BY CreatedDate DESC
    LIMIT 1
];

// Reset to In Review first so the trigger sees a real Draft→Approved transition
lr.LoanStatus__c = 'In Review';
update lr;

lr.LoanStatus__c = 'Approved';
update lr;

System.debug('✔ Email re-triggered for LoanRequest: ' + lr.Id);
