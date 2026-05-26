public class LoanRequestConstants {

    // ── Loan Status Picklist Values ──────────────────────────────────────────────
    public static final String STATUS_DRAFT     = 'Draft';
    public static final String STATUS_IN_REVIEW = 'In Review';
    public static final String STATUS_SUBMITTED = 'Submitted';
    public static final String STATUS_APPROVED  = 'Approved';
    public static final String STATUS_REJECTED  = 'Rejected';

    // ── Loan Approval Status Picklist Values ─────────────────────────────────────
    public static final String APPROVAL_STATUS_PENDING   = 'Pending';
    public static final String APPROVAL_STATUS_APPROVED  = 'Approved';
    public static final String APPROVAL_STATUS_REJECTED  = 'Rejected';

    // ── Business Rules ───────────────────────────────────────────────────────────
    public static final Decimal HIGH_VALUE_THRESHOLD = 250000;

    // ── Task Configuration ───────────────────────────────────────────────────────
    public static final String  TASK_SUBJECT   = 'High-Value Loan Request — Manager Approval Required';
    public static final String  TASK_PRIORITY  = 'High';
    public static final String  TASK_STATUS    = 'Not Started';
    public static final Integer TASK_DUE_DAYS  = 3;

    // ── Email Configuration ──────────────────────────────────────────────────────
    public static final String EMAIL_SUBJECT  = 'Your Loan Request Has Been Approved';
    public static final String EMAIL_REPLY_TO = 'noreply@bankleumi.co.il';

    // ── Integration Configuration ────────────────────────────────────────────────
    public static final Integer MAX_RETRY_ATTEMPTS    = 3;
    public static final String  LOAN_CORE_ENDPOINT    = 'callout:LoanCoreAPI/loans/submit';
    // WEBHOOK_SECRET must be rotated per environment via a Custom Metadata record in production
    public static final String  WEBHOOK_SECRET        = 'change-me-in-production';
    public static final String  WEBHOOK_HMAC_ALGORITHM = 'hmacSHA256';

    // ── Audit Log — Event Types ──────────────────────────────────────────────────
    public static final String EVENT_DATA_CHANGE = 'DATA_CHANGE';
    public static final String EVENT_INTEGRATION = 'INTEGRATION';

    // ── Audit Log — Object Types ─────────────────────────────────────────────────
    public static final String OBJ_LOAN_REQUEST = 'LoanRequest__c';

    // ── Audit Log — Actions ──────────────────────────────────────────────────────
    public static final String ACTION_STATUS_CHANGED         = 'StatusChanged';
    public static final String ACTION_HIGH_VALUE_NO_MANAGER  = 'HighValueNoManager';
    public static final String ACTION_TASK_INSERT_FAILED     = 'TaskInsertFailed';
    public static final String ACTION_ALERT_FLAG_FAILED      = 'AlertFlagUpdateFailed';
    public static final String ACTION_EMAIL_SKIPPED          = 'EmailSkipped';
    public static final String ACTION_INTEGRATION_SENT       = 'IntegrationSent';
    public static final String ACTION_INTEGRATION_FAILED     = 'IntegrationFailed';
    public static final String ACTION_WEBHOOK_RECEIVED       = 'WebhookReceived';
    public static final String ACTION_WEBHOOK_FAILED         = 'WebhookFailed';

    // ── Audit Log — Severities ───────────────────────────────────────────────────
    public static final String SEVERITY_INFO  = 'INFO';
    public static final String SEVERITY_WARN  = 'WARN';
    public static final String SEVERITY_ERROR = 'ERROR';
}
