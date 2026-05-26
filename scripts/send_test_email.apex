Customer__c cust = new Customer__c(
    FirstName__c = 'Sapir',
    LastName__c  = 'Kikoz',
    Email__c     = 'sapirkikoz@gmail.com'
);
insert cust;

LoanRequest__c lr = new LoanRequest__c(
    Customer__c   = cust.Id,
    LoanAmount__c = 180000,
    LoanStatus__c = 'Draft'
);
insert lr;

lr.LoanStatus__c = 'Approved';
update lr;

System.debug('Done — email sent to: ' + cust.Email__c);
