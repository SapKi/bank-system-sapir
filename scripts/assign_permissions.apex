PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = 'BankLeumiStaff' LIMIT 1];

List<User> staffUsers = [SELECT Id FROM User WHERE LastName IN ('Clerk', 'Manager')];

List<PermissionSetAssignment> assignments = new List<PermissionSetAssignment>();
for (User u : staffUsers) {
    assignments.add(new PermissionSetAssignment(
        PermissionSetId = ps.Id,
        AssigneeId      = u.Id
    ));
}
insert assignments;
System.debug('Assigned BankLeumiStaff to ' + assignments.size() + ' users.');
