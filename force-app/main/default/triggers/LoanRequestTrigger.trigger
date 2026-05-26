trigger LoanRequestTrigger on LoanRequest__c (after insert, after update) {
    TriggerDispatcher.run(new LoanRequestTriggerHandler());
}
