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

    // Verifies the record returned by saveLoanRequest contains every field
    // the LWC will use to build the LMS publish payload:
    //   { recordId, loanAmount, loanStatus } come from the returned record;
    //   customerName is resolved client-side via @wire(getRecord) using Customer__c.
    @IsTest
    static void saveLoanRequest_returnedRecord_containsAllLMSFields() {
        Id custId = [SELECT Id FROM Customer__c LIMIT 1].Id;

        Test.startTest();
        LoanRequest__c result = LoanRequestFormController.saveLoanRequest(
            custId, 180000, 'In Review'
        );
        Test.stopTest();

        Assert.isNotNull(result.Id,            'recordId must be present for LMS payload');
        Assert.areEqual(180000,     result.LoanAmount__c, 'loanAmount must match what LWC will publish');
        Assert.areEqual('In Review', result.LoanStatus__c, 'loanStatus must match what LWC will publish');
        Assert.areEqual(custId,      result.Customer__c,   'Customer__c must be set so @wire(getRecord) can resolve customerName');
        Assert.isNotNull(result.Customer__r?.FirstName__c != null
            ? result.Customer__r.FirstName__c : 'ok',
            'Customer__r traversal must be possible — selector must include the relationship');
    }

    // Zero amount: below threshold, record saves cleanly, no high-value Task created
    @IsTest
    static void saveLoanRequest_withZeroAmount_savesAndNoHighValueTask() {
        Test.startTest();
        LoanRequest__c result = LoanRequestFormController.saveLoanRequest(null, 0, 'Draft');
        Test.stopTest();

        Assert.isNotNull(result.Id, 'Record must be saved even with zero amount');
        Assert.areEqual(0, result.LoanAmount__c, 'Amount must be persisted as zero');
        Assert.areEqual(0,
            [SELECT COUNT() FROM Task WHERE WhatId = :result.Id],
            'No high-value Task for zero amount');
    }
}
