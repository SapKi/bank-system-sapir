// Selector layer — owns SOQL against CustomNotificationType (standard platform object).
public with sharing class NotificationTypeSelector {

    public static String getIdByDeveloperName(String developerName) {
        if (String.isBlank(developerName)) return null;
        List<CustomNotificationType> results = [
            SELECT Id FROM CustomNotificationType
            WHERE DeveloperName = :developerName
            LIMIT 1
        ];
        return results.isEmpty() ? null : results[0].Id;
    }
}
