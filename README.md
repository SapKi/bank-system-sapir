# Bank Leumi — Salesforce Home Assignment

---

## Demo — Quick Start Guide

### Org Details

| | |
|---|---|
| Org URL | `https://power-velocity-9198-dev-ed.scratch.my.salesforce.com` |
| Scratch Org Alias | `my-scratch-org-2` |

### Demo Users

| Role | Name | Username | Password |
|---|---|---|---|
| System Admin | User User | `test-9l5mddq5jg5q@example.com` | `7rb]ikecrzOvt` |
| Bank Clerk | Yael Clerk | `yael.clerk.1779796569252@bankleumi-demo.com` | `BankLeumi@2025` |
| Branch Manager | David Manager | `david.manager.1779794406447@bankleumi-demo.com` | `BankLeumi@2025` |

> To run both sessions simultaneously: use a regular browser window for one user and an Incognito window for the other.

---

### Full Demo Walkthrough

**Step 1 — Setup**
- Open a regular window and log in as **Yael Clerk** (bank clerk)
- Open an Incognito window and log in as **David Manager** (branch manager)

**Step 2 — Create a Customer and Loan Request (as Yael)**
1. App Launcher → **Customers** → **New**
2. Fill in: First Name, Last Name, Email (use a real address to receive the approval email)
3. Save → App Launcher → **Loan Requests** → **New**
4. Select the customer you just created, enter an amount **above 250,000**, set **David Manager** as Assigned Manager
5. Save

**Step 3 — Manager Receives the Alert (as David)**
- App Launcher → **Tasks** → a new Task appears: **"High-Value Loan Request — Manager Approval Required"**
  - Priority: High
  - Due Date: 3 days from today
  - Related To: the loan request Yael created

**Step 4 — Approve the Request and Trigger the Email (as David)**
1. Open the loan request from the Task
2. Edit → change **Loan Status** to **Approved** → Save
3. An approval email is automatically sent to the customer's email address
4. App Launcher → **Audit Logs** → a new entry appears with Action: `StatusChanged`, OldValue: `Draft`, NewValue: `Approved`

---

### LoanApproval__c — Why You Won't See a Record in the Demo

`LoanApproval__c` is **not** created when status changes to `Approved`. It is created only when status changes to **`Submitted`**, representing a submission to the external core banking system for approval.

The full production flow is:

```
Draft → Submitted  →  LoanApproval__c created + HTTP POST to external system
                   ↓
              External system processes the loan and calls back via Webhook
                   ↓
              LoanApproval__c updated to Approved / Rejected
                   ↓
              LoanRequest__c status set to Approved → approval email sent to customer
```

In this demo we skipped directly to `Approved` because there is no real external server. In a Production environment you would also see a `LoanApproval__c` record with `ApprovalStatus = Approved` and a populated `ReceivedResponse__c` timestamp.

---

### Security Note

The `BankLeumiStaff` Permission Set assigned to Yael and David uses `viewAllRecords = true` to allow smooth navigation during the demo. In a Production environment, Sharing Rules and a Role Hierarchy would be configured so that each clerk sees only their own records, and only the assigned manager receives alerts for the requests they are responsible for.

---

## Table of Contents

1. [Project Overview](#project-overview)
2. [Data Model](#data-model)
3. [Architecture](#architecture)
4. [Layer Responsibilities](#layer-responsibilities)
5. [Design Decisions](#design-decisions)
6. [Integration Flow](#integration-flow)
7. [Security](#security)
8. [Test Coverage](#test-coverage)
9. [Deployment](#deployment)
10. [Governor Limit Notes](#governor-limit-notes)

---

## Project Overview

This project implements a production-grade Salesforce CRM extension for loan request processing. It covers the full lifecycle of a `LoanRequest__c` record — from high-value alerting and status change auditing through asynchronous external system integration and inbound webhook callback processing.

Key capabilities:
- **High-Value Alert** — creates a manager Task when a loan amount exceeds 250,000; logs WARN if no manager is assigned.
- **Status Change Audit** — writes an `AuditLog__c` record for every status transition on any loan.
- **Approval Email** — sends a personalised email to the customer when status reaches `Approved`.
- **External Integration** — when status reaches `Submitted`, dispatches a Queueable Apex job that POSTs to the core banking system via Named Credential; retries up to 3 times with dead-letter logging.
- **Webhook Callback** — exposes a REST endpoint that receives approval decisions from the external system; validates every incoming request with HMAC-SHA256 before processing.

---

## Data Model

### Customer__c

| Field | Type | Notes |
|---|---|---|
| `FirstName__c` | Text(50) | |
| `LastName__c` | Text(50) | Required |
| `Email__c` | Email | Used for approval notifications |
| `Phone__c` | Phone | |
| `NationalId__c` | Text(20) | Unique |
| `DateOfBirth__c` | Date | |
| `RiskLevel__c` | Picklist | Low / Medium (default) / High |
| `CustomerNumber__c` | AutoNumber | `CUST-{0000}` |
| `Status__c` | Picklist | Active / Inactive |

### LoanRequest__c

| Field | Type | Notes |
|---|---|---|
| `Customer__c` | Lookup → Customer__c | |
| `AssignedManager__c` | Lookup → User | Required for high-value Task creation |
| `LoanAmount__c` | Currency | Threshold at 250,000 |
| `LoanType__c` | Picklist | Personal / Mortgage / Business / Auto |
| `TermMonths__c` | Number | |
| `InterestRate__c` | Percent | |
| `LoanStatus__c` | Picklist | Draft → In Review → Submitted → Approved / Rejected |
| `LoanNumber__c` | AutoNumber | `LOAN-{00000}` |
| `SubmittedDate__c` | DateTime | |
| `AlertSent__c` | Checkbox | Prevents duplicate high-value Tasks |

### AuditLog__c (Sharing: Private)

| Field | Type | Notes |
|---|---|---|
| `RelatedId__c` | Text | Id of the triggering record as a string |
| `ObjectType__c` | Text | e.g. `LoanRequest__c` |
| `EventType__c` | Text | `DATA_CHANGE` or `INTEGRATION` |
| `Action__c` | Text | e.g. `StatusChanged`, `WebhookReceived` |
| `Severity__c` | Text | `INFO` / `WARN` / `ERROR` |
| `OldValue__c` | Text | Previous state |
| `NewValue__c` | Text | New state or error message |
| `PerformedBy__c` | Text | `UserInfo.getUserId()` at write time |
| `Timestamp__c` | DateTime | |
| `IPAddress__c` | Text(45) | Reserved for UI controllers |

### LoanApproval__c (Sharing: Controlled by Parent)

Master-Detail child of `LoanRequest__c`.

| Field | Type | Notes |
|---|---|---|
| `LoanRequest__c` | Master-Detail | Parent |
| `ExternalRefId__c` | Text(100) | Unique external reference from core banking system |
| `ApprovalStatus__c` | Picklist | Pending (default) / Approved / Rejected |
| `RejectionReason__c` | LongTextArea | Populated on rejection |
| `SentToExternal__c` | DateTime | Timestamp of outbound submission |
| `ReceivedResponse__c` | DateTime | Timestamp of inbound callback |

---

## Architecture

```
Trigger
  └── TriggerDispatcher                   Routing Layer
          └── LoanRequestTriggerHandler   Business Logic     (with sharing)
                  │
                  ├── CustomerSelector    Selector Layer     (with sharing)
                  ├── LoanApprovalSelector                   (with sharing)
                  ├── LoanApprovalService Service Layer      (without sharing)
                  ├── AuditLogService     Audit Layer        (without sharing)
                  ├── EmailService        Messaging Layer    (without sharing)
                  └── LoanRequestConstants                   Constants

Async Integration
  └── LoanApprovalQueueable               Queueable Apex     (implements Queueable, AllowsCallouts)
          ├── LoanApprovalSelector
          ├── LoanApprovalService
          └── AuditLogService

Inbound Webhook
  └── LoanApprovalWebhook                 REST Resource      (@RestResource, without sharing)
          ├── LoanApprovalSelector
          ├── LoanApprovalService
          └── AuditLogService

Shared Infrastructure
  ├── ITriggerHandler                     Interface          (trigger contract)
  ├── TriggerDispatcher                   Dispatcher         (event router)
  └── LoanRequestConstants                Constants          (single source of truth)
```

---

## Layer Responsibilities

| Class | Sharing | Responsibility |
|---|---|---|
| `LoanRequestTrigger` | — | One-liner trigger; delegates to `TriggerDispatcher`. Contains no logic. |
| `ITriggerHandler` | — | Interface contract: `afterInsert` / `afterUpdate`. Decouples triggers from handler implementations. |
| `TriggerDispatcher` | — | Routes `Trigger.*` context flags to the correct interface method. Adding a new object trigger requires only a new `ITriggerHandler` — this class never changes. |
| `LoanRequestTriggerHandler` | `with sharing` | Implements `ITriggerHandler`. Orchestrates all business logic for `LoanRequest__c`. Enforces sharing rules. |
| `CustomerSelector` | `with sharing` | Owns all SOQL against `Customer__c`. Returns typed maps for O(1) access. |
| `LoanApprovalSelector` | `with sharing` | Owns all SOQL against `LoanApproval__c`. Look up by Id set or by `ExternalRefId__c`. |
| `LoanApprovalService` | `without sharing` | Owns all DML against `LoanApproval__c`. Called from trigger, async job, and REST resource — must write regardless of sharing context. |
| `AuditLogService` | `without sharing` | Provides `buildLog()` (returns record, no DML) for bulk collection and `log()` (build + insert immediately) for catch blocks. Audit writes must always succeed. |
| `EmailService` | `without sharing` | Composes `Messaging.SingleEmailMessage` objects. Email composition must not be blocked by sharing rules. |
| `LoanApprovalQueueable` | — | Async HTTP integration. Accepts a `List<Id>` of approval IDs and processes all of them in one job execution. Re-enqueues only failed IDs on retry. |
| `LoanApprovalWebhook` | `without sharing` | `@RestResource` endpoint. Validates HMAC-SHA256 signature, updates `LoanApproval__c` via service, writes audit log. |
| `LoanRequestConstants` | — | Single source of truth for all configurable values — picklist values, thresholds, email templates, integration endpoints, audit action/severity strings. Zero magic strings or numbers elsewhere. |

---

## Design Decisions

### Trigger Framework — `ITriggerHandler` + `TriggerDispatcher`

The trigger is a single line:
```apex
trigger LoanRequestTrigger on LoanRequest__c (after insert, after update) {
    TriggerDispatcher.run(new LoanRequestTriggerHandler());
}
```

`TriggerDispatcher` reads `Trigger.isAfter`, `Trigger.isInsert`, etc. and calls the correct interface method. Adding a trigger on a new object requires only a new `ITriggerHandler` implementation — no changes to shared infrastructure.

```
LoanRequestTrigger
    → TriggerDispatcher.run(new LoanRequestTriggerHandler())
        → handler.afterInsert(Trigger.new)          [on insert]
        → handler.afterUpdate(Trigger.new, oldMap)  [on update]
```

> **Why not before-triggers?** The current requirements (Task creation, email, audit, integration dispatch) are all post-save operations. Before-trigger support can be added to `ITriggerHandler` without breaking existing handlers.

### Recursion Guard

`LoanRequestTriggerHandler` holds a `private static Boolean alreadyRun` flag. When `handleHighValueAlert` updates `AlertSent__c = true` on matched records, this re-fires the `after update` trigger. The flag causes the second invocation to return immediately, preventing infinite recursion and duplicate Tasks.

A `try/finally` block resets the flag after every top-level execution, so a legitimate user-initiated update following the insert is still processed:

```
insert LoanRequest  →  alreadyRun = false → runs all logic
  └── update AlertSent__c  →  alreadyRun = true → returns immediately
  └── alreadyRun reset to false  (finally block)

update LoanRequest  →  alreadyRun = false → runs all logic  ✓
```

### Bulk-Safe Patterns

All code handles batches of up to 200 records without hitting governor limits:

- **No SOQL inside loops** — `CustomerSelector.getByIds()` and `LoanApprovalSelector.getByIds()` run once; results are stored in `Map<Id, T>` for O(1) per-record access.
- **No DML inside loops** — Tasks, `AuditLog__c` records, `LoanApproval__c` records, and `LoanRequest__c` flag updates are collected in lists and flushed in a single DML call outside the loop.
- **No email send inside loops** — all `Messaging.SingleEmailMessage` objects are collected and sent in a single `Messaging.sendEmail()` call regardless of batch size.
- **Single Queueable enqueue** — `handleIntegration` inserts all `LoanApproval__c` records in one DML call and enqueues **one** `LoanApprovalQueueable` with a `List<Id>`, regardless of how many loans were submitted. This avoids the 50-enqueued-jobs-per-transaction governor limit.

### Selector Layer

Every SOQL query is owned by a dedicated Selector class. No inline SOQL appears in handlers, services, or REST resources.

| Selector | Queries |
|---|---|
| `CustomerSelector` | `Customer__c` by Id set |
| `LoanApprovalSelector` | `LoanApproval__c` by Id set or by `ExternalRefId__c` |

This pattern makes queries easy to find, test, and optimise. Indexes and query hints are added in one place.

### Service Layer

All DML against `LoanApproval__c` is routed through `LoanApprovalService`. This prevents `update approval` and `insert approvals` from appearing in trigger handlers, Queueable jobs, and REST resources simultaneously. Future additions — validation, event publishing, extra audit logging — are made once in the service, not in every caller.

Similarly, all `AuditLog__c` writes go through `AuditLogService`. No class other than these two services issues DML to their respective objects.

### `with sharing` vs `without sharing`

| Class | Decision | Reason |
|---|---|---|
| `LoanRequestTriggerHandler` | `with sharing` | Business logic must respect record-level security |
| `CustomerSelector` | `with sharing` | Queries must respect the running user's visibility |
| `LoanApprovalSelector` | `with sharing` | Same rationale |
| `LoanApprovalService` | `without sharing` | Approval records must be written from triggers, async jobs, and REST contexts regardless of who owns the record |
| `AuditLogService` | `without sharing` | Audit entries must always be written even if the user cannot access `AuditLog__c` records |
| `EmailService` | `without sharing` | Email composition must not be blocked by sharing rules |
| `LoanApprovalWebhook` | `without sharing` | REST resource called by an external system — record updates must not depend on the API user's sharing |

> **FLS:** `with sharing` enforces record sharing rules, not Field-Level Security. FLS enforcement belongs in UI-facing Aura/LWC controllers, not internal trigger data reads. Selectors therefore omit `WITH SECURITY_ENFORCED`.

### Constants Layer

Every configurable value — picklist string, numeric threshold, email template, API endpoint, audit action/severity — is declared once in `LoanRequestConstants`. Changing the high-value threshold, retry count, or email body text requires editing a single line.

The email body is a `String.format`-style template (`{0}` = customer name, `{1}` = amount); `EmailService.buildApprovalEmail` calls `String.format(LoanRequestConstants.EMAIL_BODY_TEMPLATE, ...)`.

### Exception Handling

The trigger never blocks a record save due to secondary failures:
- Email failures are caught and `System.debug`-logged.
- Task / AuditLog DML failures are caught, logged to `AuditLog__c` where possible, and do not propagate.
- `LoanApprovalService.insertApprovals` failures in `handleIntegration` are caught; an ERROR AuditLog is written and the Queueable enqueue is skipped (the loan save still succeeds).
- Every external reference (`Customer__c`, `AssignedManager__c`, `Email__c`, `ExternalRefId__c`) is null-checked before use.

---

## Integration Flow

```
LoanRequest__c status → Submitted
        │
        ▼
LoanRequestTriggerHandler.handleIntegration()
        │  bulk-inserts LoanApproval__c (all in one DML)
        │  enqueues ONE LoanApprovalQueueable(List<Id>, attempt=1)
        │
        ▼
LoanApprovalQueueable.execute()
        │  queries approvals via LoanApprovalSelector.getByIds()
        │  for each approval: HTTP POST → callout:LoanCoreAPI/loans/submit
        │  bulk-updates successful approvals via LoanApprovalService
        │  on failure:
        │    attempt < MAX_RETRY_ATTEMPTS  →  re-enqueue(failedIds, attempt+1)
        │    attempt = MAX_RETRY_ATTEMPTS  →  ERROR AuditLog (dead letter)
        │
        ▼
External system processes loan, calls back:
POST /services/apexrest/loan-approval-webhook/

        ▼
LoanApprovalWebhook.handleWebhook()
        │  verifies HMAC-SHA256 signature (→ 401 if invalid)
        │  looks up LoanApproval__c via LoanApprovalSelector.getByExternalRefId()
        │  updates ApprovalStatus__c / RejectionReason__c via LoanApprovalService
        │  writes INFO AuditLog
        └  returns 200 {"status":"ok"}
```

### Retry Logic

| Attempt | Behaviour |
|---|---|
| 1–2 | Re-enqueue with `failedIds` only; successful approvals are not retried |
| 3 (MAX) | ERROR AuditLog written per failed approval (dead letter) |

Platform job pacing between enqueue and execution provides implicit backoff. Retry scope is minimal: only IDs that failed on the previous attempt are re-enqueued.

---

## Security

### HMAC-SHA256 Signature Validation

Every inbound webhook request must include an `X-Signature-SHA256` header containing the HMAC-SHA256 hex digest of the raw request body, keyed with `WEBHOOK_SECRET`. The webhook rejects requests without the header or with a mismatched digest with HTTP 401 before any data is read.

```apex
Blob hmac = Crypto.generateMac(
    LoanRequestConstants.WEBHOOK_HMAC_ALGORITHM,  // 'hmacSHA256'
    Blob.valueOf(requestBody),
    Blob.valueOf(LoanRequestConstants.WEBHOOK_SECRET)
);
String expected = EncodingUtil.convertToHex(hmac);
return expected.equalsIgnoreCase(receivedSignature);
```

> **Production note:** `WEBHOOK_SECRET` is declared in `LoanRequestConstants` with a placeholder value. In production this value must be loaded from a Custom Metadata Type (`WebhookSettings__mdt`) or a Custom Setting so it can be rotated per environment without a code deployment.

### Named Credentials

Outbound HTTP calls use `callout:LoanCoreAPI` (a Named Credential), keeping the endpoint URL and any authentication headers out of Apex code entirely. Changing the target URL or rotating credentials requires only an org configuration change — no code deployment.

### Sharing Model

See the [Sharing Decisions table](#with-sharing-vs-without-sharing) above. `AuditLog__c` has `sharingModel=Private` so no user sees another user's audit records via reports or list views.

---

## Test Coverage

### `LoanRequestTriggerHandler_Test` (7 methods)

| Method | Scenario |
|---|---|
| `testHighValueAlert_TaskCreated` | Amount > 250,000, manager assigned → Task created, `AlertSent__c = true` |
| `testHighValueAlert_NoDuplicate` | `AlertSent__c` already true → no Task created |
| `testStatusApproved_EmailSent` | Status → Approved → exactly one email invocation |
| `testStatusChange_AuditLogCreated` | Status Draft → In Review → `AuditLog__c` with correct old/new/severity values |
| `testBulkInsert_200Records` | 200 records inserted and updated → no governor limit exceptions, 200 AuditLogs |
| `testNullCustomer_NoException` | `Customer__c` = null → no `NullPointerException` from trigger code |
| `testNullManager_NoTask` | `AssignedManager__c` = null, high-value loan → no Task, WARN AuditLog written |

### `LoanApprovalQueueable_Test` (3 methods)

| Method | Scenario |
|---|---|
| `testSuccess_UpdatesApprovalAndLogsInfo` | 200 response → `ExternalRefId__c` set, `ReceivedResponse__c` populated, INFO AuditLog |
| `testFailureAtMaxRetries_LogsDeadLetter` | 500 response at `MAX_RETRY_ATTEMPTS` → ERROR dead-letter AuditLog |
| `testRetryBoundary_MaxAttemptIsExclusive` | Constant boundary assertion — `MAX_RETRY_ATTEMPTS` is a valid positive threshold |

> Salesforce test context executes chained Queueable jobs synchronously and limits chains to one level. End-to-end retry chain testing is therefore platform-constrained; the dead-letter test covers the critical failure path.

### `LoanApprovalWebhook_Test` (5 methods)

| Method | Scenario |
|---|---|
| `testApprovedWebhook_UpdatesStatusAndLogsInfo` | Valid signature + Approved → HTTP 200, status updated, INFO AuditLog |
| `testRejectedWebhook_SetsRejectionReason` | Valid signature + Rejected → `RejectionReason__c` populated |
| `testInvalidSignature_Returns401` | Tampered signature → HTTP 401, no data change |
| `testMissingSignature_Returns401` | Missing header → HTTP 401, no data change |
| `testUnknownReferenceId_Returns404` | Unknown `referenceId` → HTTP 404 |

**Overall: 18 / 18 tests pass. 100% pass rate.**

All test data is built in `@TestSetup`. No `seeAllData=true`. No hardcoded Ids. Loan amounts in setup methods are below the 250,000 threshold to avoid noise from the high-value alert path.

---

## Deployment

```bash
# Authenticate dev hub and create scratch org (one-time)
sf org login web --alias my-dev-org --set-default-dev-hub
sf org create scratch --definition-file config/project-scratch-def.json --alias my-scratch-org --duration-days 30

# Deploy all metadata
sf project deploy start --target-org my-scratch-org

# Run all tests with coverage
sf apex run test --target-org my-scratch-org --test-level RunLocalTests \
  --code-coverage --result-format human --synchronous

# Open the org
sf org open --target-org my-scratch-org
```

---

## Governor Limit Notes

| Concern | Design Response |
|---|---|
| SOQL per transaction (200) | All queries run once via Selector classes; results stored in Maps for O(1) loop access |
| DML per transaction (150) | One DML call per operation type, outside all loops |
| Email invocations (10) | One `Messaging.sendEmail()` call per trigger execution regardless of batch size |
| Enqueued jobs per transaction (50) | `handleIntegration` enqueues exactly ONE job regardless of how many loans change to Submitted |
| HTTP callouts per Queueable (100) | `LoanApprovalQueueable` processes up to 100 approvals per execution; for volumes above 100, the job can be extended to chain itself with the remaining IDs |
| Heap size (6 MB sync / 12 MB async) | No large string or collection accumulation; serialised payloads are per-record JSON objects |
| Queueable retry depth | Retry chain is bounded by `MAX_RETRY_ATTEMPTS` (default 3); re-enqueue scope shrinks to only failed IDs on each attempt |
