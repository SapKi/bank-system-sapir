/**
 * Service for writing AuditLog__c records.
 * Declared without sharing so that audit entries are always persisted,
 * regardless of the running user's sharing rules.
 * Note: without sharing does NOT bypass FLS — field-level access is still enforced.
 */
public without sharing class AuditLogService {

    /**
     * Builds an AuditLog__c record without performing DML.
     * Use this method in bulk loops — collect records, then insert once outside the loop.
     */
    public static AuditLog__c buildLog(
        Id     relatedId,
        String objectType,
        String eventType,
        String action,
        String severity,
        String oldVal,
        String newVal
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

    /**
     * Builds and immediately inserts a single AuditLog__c record.
     * Use this for one-off error logging inside catch blocks.
     */
    public static void log(
        Id     relatedId,
        String objectType,
        String eventType,
        String action,
        String severity,
        String oldVal,
        String newVal
    ) {
        try {
            insert buildLog(relatedId, objectType, eventType, action, severity, oldVal, newVal);
        } catch (DmlException e) {
            System.debug(LoggingLevel.ERROR, 'AuditLogService.log DML failed: ' + e.getMessage());
        }
    }
}
