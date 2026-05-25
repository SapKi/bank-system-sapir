trigger LoanRequestTrigger on LoanRequest__c (after insert, after update) {
    LoanRequestTriggerHandler.handle(Trigger.new, Trigger.oldMap);
}
