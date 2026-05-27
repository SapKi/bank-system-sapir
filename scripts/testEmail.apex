Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
mail.setToAddresses(new List<String>{'sapirkikoz@gmail.com'});
mail.setSubject('Salesforce Email Deliverability Test');
mail.setPlainTextBody('If you receive this, email deliverability is working correctly.');
List<Messaging.SendEmailResult> results = Messaging.sendEmail(
    new List<Messaging.SingleEmailMessage>{mail}, false
);
System.debug('Success: ' + results[0].isSuccess());
System.debug('Errors: ' + results[0].getErrors());
