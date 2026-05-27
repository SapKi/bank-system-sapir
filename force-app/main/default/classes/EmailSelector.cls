// Selector layer — owns SOQL against email platform objects.
public with sharing class EmailSelector {

    public static String getOrgWideEmailAddressId() {
        List<OrgWideEmailAddress> owas = [SELECT Id FROM OrgWideEmailAddress LIMIT 1];
        return owas.isEmpty() ? null : owas[0].Id;
    }
}
