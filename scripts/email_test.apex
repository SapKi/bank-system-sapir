// Diagnose why email isn't arriving
Customer__c cust = [SELECT Id, FirstName__c, LastName__c, Email__c FROM Customer__c WHERE LastName__c = 'Kikoz' LIMIT 1];
System.debug('Customer email on record: ' + cust.Email__c);
System.debug('Customer name: ' + cust.FirstName__c + ' ' + cust.LastName__c);

List<AuditLog__c> skipped = [SELECT Action__c, NewValue__c FROM AuditLog__c WHERE Action__c = 'EmailSkipped'];
System.debug('EmailSkipped audit entries: ' + skipped.size());
for (AuditLog__c a : skipped) System.debug('  Reason: ' + a.NewValue__c);

// Send a direct test email to confirm deliverability works at all
Messaging.SingleEmailMessage testMail = new Messaging.SingleEmailMessage();
testMail.setToAddresses(new List<String>{ 'sapirkikoz@gmail.com' });
testMail.setSubject('Salesforce Deliverability Test');
testMail.setPlainTextBody('This is a direct test email from Salesforce. If you see this, deliverability is working.');
List<Messaging.SendEmailResult> results = Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ testMail }, false);
System.debug('Send result success: ' + results[0].isSuccess());
if (!results[0].isSuccess()) {
    for (Messaging.SendEmailError err : results[0].getErrors()) {
        System.debug('Email error: ' + err.getMessage() + ' | Status: ' + err.getStatusCode());
    }
}
