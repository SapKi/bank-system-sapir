/** Shared constants for the loanRequestForm / loanRequestSummary LWC pair. */

export const DEFAULT_LOAN_STATUS = 'Draft';

export const LOAN_STATUS_OPTIONS = [
    { label: 'Draft',     value: 'Draft'     },
    { label: 'In Review', value: 'In Review' },
    { label: 'Submitted', value: 'Submitted' },
    { label: 'Approved',  value: 'Approved'  },
    { label: 'Rejected',  value: 'Rejected'  }
];

// Maps each LoanStatus__c picklist value to its CSS badge class
export const STATUS_BADGE_CLASSES = {
    'Draft':     'status-badge status-draft',
    'In Review': 'status-badge status-review',
    'Submitted': 'status-badge status-submitted',
    'Approved':  'status-badge status-approved',
    'Rejected':  'status-badge status-rejected'
};

export const LOAN_REQUEST_OBJECT_API = 'LoanRequest__c';

export const CURRENCY_CODE = 'USD';
export const DATE_LOCALE   = 'en-US';
