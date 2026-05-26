import { LightningElement, track, wire } from 'lwc';
import { publish, MessageContext } from 'lightning/messageService';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import FIRST_NAME from '@salesforce/schema/Customer__c.FirstName__c';
import LAST_NAME  from '@salesforce/schema/Customer__c.LastName__c';
import LOAN_REQUEST_CHANNEL from '@salesforce/messageChannel/LoanRequestChannel__c';
import saveLoanRequest from '@salesforce/apex/LoanRequestFormController.saveLoanRequest';
import { LOAN_STATUS_OPTIONS, DEFAULT_LOAN_STATUS } from 'c/loanRequestConstants';

export default class LoanRequestForm extends LightningElement {
    @track customerId = null;
    @track loanAmount = null;
    @track loanStatus = DEFAULT_LOAN_STATUS;
    @track isLoading  = false;

    @wire(MessageContext)
    messageContext;

    // Reactively fetches FirstName__c / LastName__c whenever customerId changes.
    @wire(getRecord, { recordId: '$customerId', fields: [FIRST_NAME, LAST_NAME] })
    customerRecord;

    get customerName() {
        if (!this.customerRecord?.data) return '';
        const first = getFieldValue(this.customerRecord.data, FIRST_NAME) ?? '';
        const last  = getFieldValue(this.customerRecord.data, LAST_NAME)  ?? '';
        return `${first} ${last}`.trim();
    }

    // Display FirstName__c + LastName__c in the dropdown instead of the auto-number Name field
    get displayInfo() {
        return {
            primaryField:     'FirstName__c',
            additionalFields: ['LastName__c']
        };
    }

    // Match search input against FirstName__c and LastName__c
    get matchingInfo() {
        return {
            primaryField:     { fieldPath: 'FirstName__c' },
            additionalFields: [{ fieldPath: 'LastName__c' }]
        };
    }

    get statusOptions() {
        return LOAN_STATUS_OPTIONS;
    }

    handleCustomerChange(event) {
        this.customerId = event.detail.recordId ?? null;
    }

    handleInputChange(event) {
        const field = event.target.dataset.id;
        this[field] = event.detail.value;
    }

    handleSave() {
        if (!this.isFormValid()) return;
        this.isLoading = true;

        saveLoanRequest({
            customerId: this.customerId,
            loanAmount: parseFloat(this.loanAmount),
            loanStatus: this.loanStatus
        })
        .then(record => {
            publish(this.messageContext, LOAN_REQUEST_CHANNEL, {
                recordId:     record.Id,
                customerName: this.customerName,
                loanAmount:   parseFloat(this.loanAmount),
                loanStatus:   this.loanStatus
            });
            this.showToast('Success', 'Loan request saved successfully.', 'success');
            this.handleReset();
        })
        .catch(error => {
            this.showToast(
                'Error saving loan request',
                error?.body?.message ?? 'An unexpected error occurred.',
                'error'
            );
        })
        .finally(() => {
            this.isLoading = false;
        });
    }

    handleReset() {
        this.customerId = null;
        this.loanAmount = null;
        this.loanStatus = DEFAULT_LOAN_STATUS;
        const picker = this.template.querySelector('lightning-record-picker');
        if (picker) picker.clearSelection();
        this.template
            .querySelectorAll('lightning-input, lightning-combobox')
            .forEach(el => el.setCustomValidity(''));
    }

    isFormValid() {
        const fields = [
            ...this.template.querySelectorAll(
                'lightning-record-picker, lightning-input, lightning-combobox'
            )
        ];
        return fields.reduce((valid, f) => f.reportValidity() && valid, true);
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
