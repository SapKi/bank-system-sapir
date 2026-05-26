// Step 1 — find a standard profile to assign to the manager user
Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];

// Step 2 — create the manager user
User manager = new User(
    FirstName          = 'David',
    LastName           = 'Manager',
    Email              = 'david.manager@bankleumi-demo.com',
    Username           = 'david.manager.' + DateTime.now().getTime() + '@bankleumi-demo.com',
    Alias              = 'dmgr',
    TimeZoneSidKey     = 'Asia/Jerusalem',
    LocaleSidKey       = 'iw_IL',
    EmailEncodingKey   = 'UTF-8',
    LanguageLocaleKey  = 'en_US',
    ProfileId          = p.Id
);
insert manager;
System.debug('Manager created: ' + manager.Id + ' | ' + manager.Username);

// Step 3 — create the customer
Customer__c cust = new Customer__c(
    FirstName__c = 'Sapir',
    LastName__c  = 'Kikoz',
    Email__c     = 'sapirkikoz@gmail.com'
);
insert cust;

// Step 4 — create a high-value loan request assigned to the manager
LoanRequest__c lr = new LoanRequest__c(
    Customer__c        = cust.Id,
    LoanAmount__c      = 350000,
    LoanStatus__c      = 'Draft',
    AlertSent__c       = false,
    AssignedManager__c = manager.Id
);
insert lr;

System.debug('Task should now be owned by Manager: ' + manager.Id);
System.debug('Loan Request Id: ' + lr.Id);
System.debug('Manager Username (use to login): ' + manager.Username);
