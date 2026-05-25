# Bank Leumi — Salesforce Home Assignment
## Part B: Apex Trigger on LoanRequest__c

---

## Overview

This project implements a Salesforce Apex trigger on the `LoanRequest__c` object that handles three business requirements:

1. **High-Value Alert** — Creates a manager Task when a loan request exceeds 250,000.
2. **Approval Email** — Sends an email to the customer when the loan status changes to `Approved`.
3. **Audit Logging** — Writes an `AuditLog__c` record for every status change.

---

## Architecture

The implementation follows a strict layered architecture where each class has a single responsibility:

```
LoanRequestTrigger
    └── LoanRequestTriggerHandler       Business Logic    (with sharing)
            ├── CustomerSelector        Data Access       (with sharing)
            ├── AuditLogService         Audit Layer       (without sharing)
            ├── EmailService            Messaging Layer   (without sharing)
            └── LoanRequestConstants    Constants         (single source of truth)
```

### Layer Responsibilities

| Class | Sharing | Responsibility |
|---|---|---|
| `LoanRequestTrigger` | — | Thin trigger — delegates to handler, contains no logic |
| `LoanRequestTriggerHandler` | `with sharing` | Orchestrates all business logic; enforces sharing rules |
| `CustomerSelector` | `with sharing` | Owns all SOQL queries against `Customer__c` |
| `AuditLogService` | `without sharing` | Writes `AuditLog__c` records; must always succeed regardless of user permissions |
| `EmailService` | `without sharing` | Builds `Messaging.SingleEmailMessage` objects for outbound email |
| `LoanRequestConstants` | — | Single source of truth for all configurable values and string literals |

---

## File Structure

```
force-app/main/default/
├── triggers/
│   └── LoanRequestTrigger.trigger
└── classes/
    ├── LoanRequestConstants.cls
    ├── LoanRequestTriggerHandler.cls
    ├── CustomerSelector.cls
    ├── AuditLogService.cls
    ├── EmailService.cls
    └── LoanRequestTriggerHandler_Test.cls
```

---

## Design Decisions

### Recursion Guard
`LoanRequestTriggerHandler` uses a `private static Boolean alreadyRun` flag. When the handler updates `AlertSent__c = true` on high-value records, this re-fires the `after update` trigger. The flag causes the second invocation to return immediately, preventing infinite recursion and duplicate Tasks.

### Bulk-Safe Patterns
All code is written to handle batches of up to 200 records without hitting governor limits:
- **No SOQL inside loops** — `CustomerSelector.getByIds()` runs once before the loop; results are stored in a `Map<Id, Customer__c>` for O(1) access per record.
- **No DML inside loops** — Tasks, `AuditLog__c` records, and `LoanRequest__c` flag updates are collected in lists and flushed in a single DML statement outside the loop.
- **No email send inside loops** — All `Messaging.SingleEmailMessage` objects are collected in a list and sent in a single `Messaging.sendEmail()` call, counting as one email invocation regardless of batch size.

### `with sharing` vs `without sharing`

| Class | Decision | Reason |
|---|---|---|
| `LoanRequestTriggerHandler` | `with sharing` | Business logic must respect record-level security |
| `CustomerSelector` | `with sharing` | Queries must respect the running user's visibility |
| `AuditLogService` | `without sharing` | Audit entries must always be written, even if the user cannot see `AuditLog__c` records |
| `EmailService` | `without sharing` | Email composition must not be blocked by sharing rules |

> **Note:** `without sharing` removes Sharing Rule restrictions only. Field-Level Security (FLS) is still enforced. The `CustomerSelector` uses `WITH SECURITY_ENFORCED` in SOQL to explicitly enforce FLS on every query.

### Exception Handling
The trigger never blocks a record save due to secondary failures:
- Email send failures are caught and logged via `System.debug` — the record save proceeds.
- DML failures on Tasks or AuditLog records are caught, logged, and do not propagate.
- Null checks guard every external reference (`Customer__c`, `AssignedManager__c`, `Email__c`) before use.

### Constants Layer
All configurable values — status picklist values, thresholds, Task configuration, email metadata, and audit action/severity strings — are defined once in `LoanRequestConstants`. No magic strings or numbers appear anywhere else in the codebase.

---

## Objects and Fields

| Object | Fields Used |
|---|---|
| `LoanRequest__c` | `LoanAmount__c`, `LoanStatus__c`, `AlertSent__c`, `Customer__c`, `AssignedManager__c` |
| `Customer__c` | `FirstName__c`, `LastName__c`, `Email__c` |
| `AuditLog__c` | `RelatedId__c`, `ObjectType__c`, `EventType__c`, `Action__c`, `Severity__c`, `OldValue__c`, `NewValue__c`, `PerformedBy__c`, `Timestamp__c` |

---

## Test Coverage

`LoanRequestTriggerHandler_Test` targets ≥ 95% coverage across 7 test methods:

| Test Method | Scenario |
|---|---|
| `testHighValueAlert_TaskCreated` | `LoanAmount__c` > 250,000 → Task created, `AlertSent__c` set to `true` |
| `testHighValueAlert_NoDuplicate` | `AlertSent__c` already `true` → no duplicate Task created |
| `testStatusApproved_EmailSent` | Status → `Approved` → one email invocation confirmed |
| `testStatusChange_AuditLogCreated` | Status change → `AuditLog__c` with correct field values |
| `testBulkInsert_200Records` | 200 records inserted and updated — no governor limit exceptions |
| `testNullCustomer_NoException` | `Customer__c` = null — trigger does not throw `NullPointerException` |
| `testNullManager_NoTask` | `AssignedManager__c` = null — no Task created, `WARN` AuditLog written instead |

All test data is built in `@TestSetup`. No `seeAllData=true`. No hardcoded Ids.

---

## Deployment

```bash
# Deploy all metadata to the scratch org
sf project deploy start --target-org my-scratch-org

# Run all tests
sf apex run test --target-org my-scratch-org --code-coverage --result-format human
```

---

## Performance Notes

- **Indexing:** Adding a custom index on `LoanStatus__c` and `LoanAmount__c` improves query performance in high-volume production orgs where these fields appear in SOQL `WHERE` clauses.
- **Queueable vs Future:** If an external integration is added (e.g., notifying a core banking system), `Queueable` Apex is preferred over `@future` because it supports non-primitive parameters, job chaining, and monitoring via `AsyncApexJob`. `@future` only accepts primitives and cannot be chained.
