@IsTest
private class LoanRequestFormControllerTest {

    @TestSetup
    static void makeData() {
        insert new Customer__c(
            FirstName__c = 'Jane',
            LastName__c  = 'Smith',
            Email__c     = 'jane.smith@test.example.com'
        );
    }

    @IsTest
    static void saveLoanRequest_withMatchingCustomer_linksRecord() {
        Test.startTest();
        LoanRequest__c result = LoanRequestFormController.saveLoanRequest(
            'Jane Smith', 120000, 'Draft'
        );
        Test.stopTest();

        Assert.isNotNull(result.Id,            'Record Id should be populated');
        Assert.areEqual(120000,   result.LoanAmount__c, 'Loan amount should match');
        Assert.areEqual('Draft',  result.LoanStatus__c, 'Loan status should match');
        Assert.isNotNull(result.Customer__r,             'Customer relationship should be resolved');
        Assert.areEqual('Jane',  result.Customer__r.FirstName__c, 'First name should match');
        Assert.areEqual('Smith', result.Customer__r.LastName__c,  'Last name should match');
    }

    @IsTest
    static void saveLoanRequest_withUnknownCustomer_savesWithoutLink() {
        Test.startTest();
        LoanRequest__c result = LoanRequestFormController.saveLoanRequest(
            'Unknown Person', 50000, 'In Review'
        );
        Test.stopTest();

        Assert.isNotNull(result.Id,           'Record Id should be populated');
        Assert.areEqual(50000,      result.LoanAmount__c, 'Loan amount should match');
        Assert.areEqual('In Review', result.LoanStatus__c, 'Loan status should match');
        Assert.isNull(result.Customer__r, 'Customer lookup should be null when not found');
    }

    @IsTest
    static void saveLoanRequest_withBlankCustomerName_savesWithoutLink() {
        Test.startTest();
        LoanRequest__c result = LoanRequestFormController.saveLoanRequest(
            '', 75000, 'Submitted'
        );
        Test.stopTest();

        Assert.isNotNull(result.Id, 'Record Id should be populated');
        Assert.isNull(result.Customer__r, 'Customer lookup should be null for blank name');
    }

    @IsTest
    static void getLoanRequest_returnsExpectedRecord() {
        LoanRequest__c lr = new LoanRequest__c(
            LoanAmount__c = 200000,
            LoanStatus__c = 'Approved'
        );
        insert lr;

        Test.startTest();
        LoanRequest__c result = LoanRequestFormController.getLoanRequest(lr.Id);
        Test.stopTest();

        Assert.areEqual(lr.Id,    result.Id,            'Ids should match');
        Assert.areEqual(200000,   result.LoanAmount__c,  'Loan amount should match');
        Assert.areEqual('Approved', result.LoanStatus__c, 'Status should match');
        Assert.isNotNull(result.CreatedDate, 'CreatedDate should be populated');
    }
}
