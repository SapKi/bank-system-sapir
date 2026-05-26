User manager = [SELECT Id, Email, Username FROM User WHERE LastName = 'Manager' LIMIT 1];
manager.Email = 'sapirkikoz@gmail.com';
update manager;
System.setPassword(manager.Id, 'BankLeumi@2024');
System.debug('Password set. Login with: ' + manager.Username + ' / BankLeumi@2024');
