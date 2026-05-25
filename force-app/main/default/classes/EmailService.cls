/**
 * Service for building outbound email messages.
 * Declared without sharing to ensure email composition is not blocked by sharing rules.
 * Actual delivery is handled by the caller via Messaging.sendEmail() — keeping this class
 * free of DML/email-send logic makes it easy to unit-test in isolation.
 */
public without sharing class EmailService {

    /**
     * Builds a loan-approval email addressed to the given customer.
     * The caller is responsible for collecting these messages and sending them
     * in a single Messaging.sendEmail() call outside any loop.
     */
    public static Messaging.SingleEmailMessage buildApprovalEmail(
        Customer__c    cust,
        LoanRequest__c lr
    ) {
        String customerName = cust.FirstName__c + ' ' + cust.LastName__c;
        String loanAmount   = lr.LoanAmount__c != null
            ? lr.LoanAmount__c.format() + ' ₪'
            : 'לא צוין';

        String body =
            'שלום ' + customerName + ',\n\n' +
            'אנו שמחים לידע אותך כי בקשת ההלוואה שלך על סך ' + loanAmount + ' אושרה בהצלחה.\n\n' +
            'לפרטים נוספים ולתיאום פגישה עם יועץ, אנא פנה/י לסניף הקרוב אליך.\n\n' +
            'בברכה,\n' +
            'צוות בנק לאומי';

        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new List<String>{ cust.Email__c });
        mail.setReplyTo('noreply@bankleumi.co.il');
        mail.setSubject('בקשת ההלוואה שלך אושרה');
        mail.setPlainTextBody(body);
        return mail;
    }
}
