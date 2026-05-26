// Quick field probe — runs each field independently so we can see exactly which one fails
System.debug('Testing LastName__c...');
Customer__c c1 = new Customer__c(LastName__c = 'Test');
System.debug('LastName__c OK');

System.debug('Testing FirstName__c...');
Customer__c c2 = new Customer__c(FirstName__c = 'Test');
System.debug('FirstName__c OK');
