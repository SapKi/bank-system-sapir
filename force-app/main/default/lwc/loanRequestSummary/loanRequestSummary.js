import { LightningElement, track, wire } from 'lwc';
import { subscribe, unsubscribe, MessageContext, APPLICATION_SCOPE } from 'lightning/messageService';
import LOAN_REQUEST_CHANNEL from '@salesforce/messageChannel/LoanRequestChannel__c';
import getLoanRequest from '@salesforce/apex/LoanRequestFormController.getLoanRequest';
import {
    STATUS_BADGE_CLASSES,
    LOAN_REQUEST_OBJECT_API,
    CURRENCY_CODE,
    DATE_LOCALE
} from 'c/loanRequestConstants';

export default class LoanRequestSummary extends LightningElement {
    @track loanData  = null;
    @track isLoading = false;
    _subscription    = null;

    @wire(MessageContext)
    messageContext;

    connectedCallback() {
        // APPLICATION_SCOPE allows receiving messages from any component on the page,
        // regardless of whether a shared parent exists.
        this._subscription = subscribe(
            this.messageContext,
            LOAN_REQUEST_CHANNEL,
            (message) => this.handleMessage(message),
            { scope: APPLICATION_SCOPE }
        );
    }

    disconnectedCallback() {
        unsubscribe(this._subscription);
        this._subscription = null;
    }

    handleMessage(message) {
        // Optimistic update — show data immediately from the LMS message
        this.loanData = {
            recordId:     message.recordId,
            customerName: message.customerName,
            loanAmount:   message.loanAmount,
            loanStatus:   message.loanStatus,
            createdDate:  null
        };
        // Then refresh with authoritative data from Salesforce
        this.refreshFromSalesforce(message.recordId);
    }

    refreshFromSalesforce(recordId) {
        this.isLoading = true;
        getLoanRequest({ recordId })
            .then(record => {
                const customerName = record.Customer__r
                    ? `${record.Customer__r.FirstName__c ?? ''} ${record.Customer__r.LastName__c ?? ''}`.trim()
                    : (this.loanData?.customerName ?? '—');

                this.loanData = {
                    recordId:     record.Id,
                    customerName: customerName || '—',
                    loanAmount:   record.LoanAmount__c,
                    loanStatus:   record.LoanStatus__c,
                    createdDate:  record.CreatedDate
                        ? new Date(record.CreatedDate).toLocaleString(DATE_LOCALE, {
                              year:   'numeric',
                              month:  'short',
                              day:    'numeric',
                              hour:   '2-digit',
                              minute: '2-digit'
                          })
                        : null
                };
            })
            .catch(error => {
                console.error('LoanRequestSummary – Salesforce refresh failed:', error);
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    get hasData() {
        return this.loanData !== null;
    }

    get showEmptyState() {
        return !this.isLoading && !this.loanData;
    }

    get formattedAmount() {
        const amount = this.loanData?.loanAmount;
        if (amount == null) return '—';
        return new Intl.NumberFormat(DATE_LOCALE, {
            style:                 'currency',
            currency:              CURRENCY_CODE,
            minimumFractionDigits: 0,
            maximumFractionDigits: 2
        }).format(amount);
    }

    get recordUrl() {
        return this.loanData?.recordId
            ? `/lightning/r/${LOAN_REQUEST_OBJECT_API}/${this.loanData.recordId}/view`
            : '#';
    }

    get statusBadgeClass() {
        return STATUS_BADGE_CLASSES[this.loanData?.loanStatus] ?? 'status-badge';
    }
}
