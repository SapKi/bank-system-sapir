// without sharing — email composition must not be blocked by sharing rules
public without sharing class EmailService {

    public static Messaging.SingleEmailMessage buildApprovalEmail(Customer__c cust, LoanRequest__c lr) {
        String customerName = cust.FirstName__c + ' ' + cust.LastName__c;
        String amount       = lr.LoanAmount__c != null ? lr.LoanAmount__c.format() : 'N/A';

        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new List<String>{ cust.Email__c });
        mail.setReplyTo(LoanRequestConstants.EMAIL_REPLY_TO);
        mail.setSubject(LoanRequestConstants.EMAIL_SUBJECT);
        mail.setPlainTextBody(buildApprovalBody(customerName, amount));
        return mail;
    }

    private static String buildApprovalBody(String customerName, String amount) {
        return 'Dear ' + customerName + ',\n\n'
            + 'We are pleased to inform you that your loan request in the amount of '
            + amount + ' has been approved.\n\n'
            + 'For further details, please contact your nearest branch.\n\n'
            + 'Best regards,\nBank Leumi Team';
    }
}
