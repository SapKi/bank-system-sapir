PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = 'BankLeumiFullAccess' LIMIT 1];
PermissionSetAssignment psa = new PermissionSetAssignment(
    AssigneeId = UserInfo.getUserId(),
    PermissionSetId = ps.Id
);
insert psa;
System.debug('PermissionSet assigned to: ' + UserInfo.getUserName());
