import { LightningElement, track, wire } from 'lwc';
import { subscribe, unsubscribe, MessageContext, APPLICATION_SCOPE } from 'lightning/messageService';
import LOAN_REQUEST_CHANNEL from '@salesforce/messageChannel/LoanRequestChannel__c';
import getRecentLoanRequests from '@salesforce/apex/LoanRequestFormController.getRecentLoanRequests';
import getLoanRequest from '@salesforce/apex/LoanRequestFormController.getLoanRequest';
import {
    STATUS_BADGE_CLASSES,
    LOAN_REQUEST_OBJECT_API,
    CURRENCY_CODE,
    DATE_LOCALE
} from 'c/loanRequestConstants';

const MAX_DISPLAY = 5;

export default class LoanRequestSummary extends LightningElement {
    @track loanRequests = [];
    @track isLoading    = true;
    _subscription       = null;

    @wire(MessageContext)
    messageContext;

    connectedCallback() {
        this._subscription = subscribe(
            this.messageContext,
            LOAN_REQUEST_CHANNEL,
            (message) => this.handleMessage(message),
            { scope: APPLICATION_SCOPE }
        );
        this.loadRecentRequests();
    }

    disconnectedCallback() {
        unsubscribe(this._subscription);
        this._subscription = null;
    }

    loadRecentRequests() {
        this.isLoading = true;
        getRecentLoanRequests()
            .then(records => {
                this.loanRequests = records.map(r => this.mapRecord(r));
            })
            .catch(error => {
                console.error('LoanRequestSummary – load failed:', error);
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    handleMessage(message) {
        // Optimistic prepend — show immediately from LMS payload
        const optimistic = {
            recordId:        message.recordId,
            customerName:    message.customerName,
            loanStatus:      message.loanStatus,
            formattedAmount: this.formatAmount(message.loanAmount),
            statusBadgeClass: STATUS_BADGE_CLASSES[message.loanStatus] ?? 'status-badge',
            recordUrl:       `/lightning/r/${LOAN_REQUEST_OBJECT_API}/${message.recordId}/view`,
            createdDate:     ''
        };
        this.loanRequests = [optimistic, ...this.loanRequests].slice(0, MAX_DISPLAY);

        // Then refresh that specific record with authoritative Salesforce data
        getLoanRequest({ recordId: message.recordId })
            .then(record => {
                this.loanRequests = this.loanRequests.map(req =>
                    req.recordId === record.Id ? this.mapRecord(record) : req
                );
            })
            .catch(error => {
                console.error('LoanRequestSummary – record refresh failed:', error);
            });
    }

    mapRecord(record) {
        const firstName = record.Customer__r?.FirstName__c ?? '';
        const lastName  = record.Customer__r?.LastName__c  ?? '';
        const name      = `${firstName} ${lastName}`.trim() || '—';

        return {
            recordId:        record.Id,
            customerName:    name,
            loanStatus:      record.LoanStatus__c,
            formattedAmount: this.formatAmount(record.LoanAmount__c),
            statusBadgeClass: STATUS_BADGE_CLASSES[record.LoanStatus__c] ?? 'status-badge',
            recordUrl:       `/lightning/r/${LOAN_REQUEST_OBJECT_API}/${record.Id}/view`,
            createdDate:     record.CreatedDate
                ? new Date(record.CreatedDate).toLocaleString(DATE_LOCALE, {
                      year:   'numeric',
                      month:  'short',
                      day:    'numeric',
                      hour:   '2-digit',
                      minute: '2-digit'
                  })
                : ''
        };
    }

    formatAmount(amount) {
        if (amount == null) return '—';
        return new Intl.NumberFormat(DATE_LOCALE, {
            style:                 'currency',
            currency:              CURRENCY_CODE,
            minimumFractionDigits: 0,
            maximumFractionDigits: 2
        }).format(amount);
    }

    get hasRequests() {
        return this.loanRequests.length > 0;
    }

    get showEmptyState() {
        return !this.isLoading && this.loanRequests.length === 0;
    }
}
