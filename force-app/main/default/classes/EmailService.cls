// without sharing — email composition must not be blocked by sharing rules
public without sharing class EmailService {

    public static Messaging.SingleEmailMessage buildApprovalEmail(Customer__c cust, LoanRequest__c lr) {
        String customerName = cust.FirstName__c + ' ' + cust.LastName__c;
        String amount       = lr.LoanAmount__c != null ? lr.LoanAmount__c.format() : 'N/A';

        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new List<String>{ cust.Email__c });
        mail.setReplyTo(LoanRequestConstants.EMAIL_REPLY_TO);
        mail.setSubject(LoanRequestConstants.EMAIL_SUBJECT);
        mail.setPlainTextBody(
            String.format(LoanRequestConstants.EMAIL_BODY_TEMPLATE, new List<String>{ customerName, amount })
        );
        return mail;
    }
}
