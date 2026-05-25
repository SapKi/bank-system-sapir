// without sharing — audit logs must always be written regardless of the running user's sharing rules
public without sharing class AuditLogService {

    // Builds an AuditLog__c without DML — collect in a list and insert once outside any loop
    public static AuditLog__c buildLog(
        Id relatedId, String objectType, String eventType,
        String action, String severity, String oldVal, String newVal
    ) {
        return new AuditLog__c(
            RelatedId__c   = relatedId != null ? String.valueOf(relatedId) : null,
            ObjectType__c  = objectType,
            EventType__c   = eventType,
            Action__c      = action,
            Severity__c    = severity,
            OldValue__c    = oldVal,
            NewValue__c    = newVal,
            PerformedBy__c = UserInfo.getUserId(),
            Timestamp__c   = DateTime.now()
        );
    }

    // Builds and immediately inserts one log — use only in catch blocks, not inside loops
    public static void log(
        Id relatedId, String objectType, String eventType,
        String action, String severity, String oldVal, String newVal
    ) {
        try {
            insert buildLog(relatedId, objectType, eventType, action, severity, oldVal, newVal);
        } catch (DmlException e) {
            System.debug(LoggingLevel.ERROR, 'AuditLogService.log failed: ' + e.getMessage());
        }
    }
}
