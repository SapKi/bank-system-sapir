import { LightningElement, track, wire } from 'lwc';
import { publish, MessageContext } from 'lightning/messageService';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import LOAN_REQUEST_CHANNEL from '@salesforce/messageChannel/LoanRequestChannel__c';
import saveLoanRequest from '@salesforce/apex/LoanRequestFormController.saveLoanRequest';
import { LOAN_STATUS_OPTIONS, DEFAULT_LOAN_STATUS } from 'c/loanRequestConstants';

export default class LoanRequestForm extends LightningElement {
    @track customerName = '';
    @track loanAmount   = null;
    @track loanStatus   = DEFAULT_LOAN_STATUS;
    @track isLoading    = false;

    @wire(MessageContext)
    messageContext;

    get statusOptions() {
        return LOAN_STATUS_OPTIONS;
    }

    handleInputChange(event) {
        const field = event.target.dataset.id;
        this[field] = event.detail.value;
    }

    handleSave() {
        if (!this.isFormValid()) return;
        this.isLoading = true;

        saveLoanRequest({
            customerName: this.customerName,
            loanAmount:   parseFloat(this.loanAmount),
            loanStatus:   this.loanStatus
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
        this.customerName = '';
        this.loanAmount   = null;
        this.loanStatus   = DEFAULT_LOAN_STATUS;
        this.template
            .querySelectorAll('lightning-input, lightning-combobox')
            .forEach(el => el.setCustomValidity(''));
    }

    isFormValid() {
        const fields = [
            ...this.template.querySelectorAll('lightning-input, lightning-combobox')
        ];
        return fields.reduce((valid, f) => f.reportValidity() && valid, true);
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
