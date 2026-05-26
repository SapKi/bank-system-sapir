Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard Platform User' LIMIT 1];

User clerk = new User(
    FirstName          = 'Yael',
    LastName           = 'Clerk',
    Email              = 'sapirkikoz@gmail.com',
    Username           = 'yael.clerk.' + DateTime.now().getTime() + '@bankleumi-demo.com',
    Alias              = 'yclrk',
    TimeZoneSidKey     = 'Asia/Jerusalem',
    LocaleSidKey       = 'iw_IL',
    EmailEncodingKey   = 'UTF-8',
    LanguageLocaleKey  = 'en_US',
    ProfileId          = p.Id
);
insert clerk;
System.setPassword(clerk.Id, 'BankLeumi@2024');
System.debug('Clerk created. Login: ' + clerk.Username + ' / BankLeumi@2024');
