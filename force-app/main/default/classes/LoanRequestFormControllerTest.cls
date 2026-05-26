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
    static void saveLoanRequest_withCustomer_linksRecord() {
        Id custId = [SELECT Id FROM Customer__c LIMIT 1].Id;

        Test.startTest();
        LoanRequest__c result = LoanRequestFormController.saveLoanRequest(
            custId, 120000, 'Draft'
        );
        Test.stopTest();

        Assert.isNotNull(result.Id,           'Record Id should be populated');
        Assert.areEqual(120000,  result.LoanAmount__c, 'Loan amount should match');
        Assert.areEqual('Draft', result.LoanStatus__c, 'Loan status should match');
        Assert.areEqual(custId,  result.Customer__c,   'Customer lookup should be set');
    }

    @IsTest
    static void saveLoanRequest_withNullCustomer_savesCleanly() {
        Test.startTest();
        LoanRequest__c result = LoanRequestFormController.saveLoanRequest(
            null, 50000, 'In Review'
        );
        Test.stopTest();

        Assert.isNotNull(result.Id,            'Record Id should be populated');
        Assert.areEqual(50000,      result.LoanAmount__c, 'Loan amount should match');
        Assert.areEqual('In Review', result.LoanStatus__c, 'Status should match');
        Assert.isNull(result.Customer__r, 'Customer relationship should be null');
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

        Assert.areEqual(lr.Id,      result.Id,            'Ids should match');
        Assert.areEqual(200000,     result.LoanAmount__c,  'Loan amount should match');
        Assert.areEqual('Approved', result.LoanStatus__c,  'Status should match');
        Assert.isNotNull(result.CreatedDate, 'CreatedDate should be populated');
    }

    @IsTest
    static void getRecentLoanRequests_returnsUpToFiveRecords() {
        List<LoanRequest__c> toInsert = new List<LoanRequest__c>();
        for (Integer i = 0; i < 7; i++) {
            toInsert.add(new LoanRequest__c(
                LoanAmount__c = 10000 * (i + 1),
                LoanStatus__c = 'Draft'
            ));
        }
        insert toInsert;

        Test.startTest();
        List<LoanRequest__c> results = LoanRequestFormController.getRecentLoanRequests();
        Test.stopTest();

        Assert.isTrue(results.size() <= 5, 'Should return at most 5 records');
        Assert.isTrue(results.size() > 0,  'Should return at least one record');
    }
}
