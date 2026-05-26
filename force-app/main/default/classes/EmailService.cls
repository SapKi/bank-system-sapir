// without sharing — email composition must not be blocked by sharing rules
public without sharing class EmailService {

    public static Messaging.SingleEmailMessage buildApprovalEmail(Customer__c cust, LoanRequest__c lr) {
        String customerName = cust.FirstName__c + ' ' + cust.LastName__c;
        String amount       = lr.LoanAmount__c != null ? lr.LoanAmount__c.format() : 'N/A';

        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new List<String>{ cust.Email__c });
        mail.setSubject(LoanRequestConstants.EMAIL_SUBJECT);
        mail.setPlainTextBody(
            String.format(LoanRequestConstants.EMAIL_BODY_TEMPLATE, new List<String>{ customerName, amount })
        );

        List<OrgWideEmailAddress> owas = [
            SELECT Id FROM OrgWideEmailAddress
            LIMIT 1
        ];
        if (!owas.isEmpty()) {
            mail.setOrgWideEmailAddressId(owas[0].Id);
        } else {
            mail.setReplyTo(LoanRequestConstants.EMAIL_REPLY_TO);
            mail.setSenderDisplayName('Bank Leumi');
        }

        return mail;
    }
}
