<template>
    <template if:true={isShowSpinner}>
        <lightning-spinner alternative-text="Loading" size="large"></lightning-spinner>
    </template>
    <lightning-card title="">
        <div class="slds-m-bottom_medium slds-grid slds-grid_align-spread slds-grid_vertical-align-center">
            <div class="slds-grid slds-grid_align-start slds-col">
                <!-- Stage filter dropdown -->
                <lightning-combobox
                    label="Stage"
                    options={stageOptions}
                    onchange={handleStageChange}
                    class="slds-m-right_small"
                    placeholder="All Stages"
                    variant="label-hidden"
                ></lightning-combobox>

                <!-- Associated To filter dropdown -->
                <lightning-button-icon
                    icon-name="utility:refresh"
                    alternative-text="Refresh"
                    class="slds-m-left_xx-small"
                    title="Refresh"
                    onclick={fetchProcessItemsByApplicationForm}
                ></lightning-button-icon>
            </div>
            <div class="slds-col_bump-left slds-m-right_medium">
                <lightning-button
                    label="Add Work Item"
                    icon-name="utility:add"
                    variant="brand"
                    onclick={handleAddWorkItem}
                >
                </lightning-button>
            </div>

            <!-- Search bar -->
            <div
                class="slds-form-element slds-m-bottom--medium slds-input-has-icon slds-input-has-icon_right slds-col"
                style="max-width: 300px"
            >
                <lightning-input
                    type="text"
                    placeholder="Search Work Items"
                    onchange={handleSearchInput}
                ></lightning-input>
            </div>
        </div>
        <!-- Document checklist Item Table -->
        <table class="slds-table slds-table_bordered slds-table_cell-buffer" role="grid">
            <thead>
                <tr>
                    <template for:each={columns} for:item="column" for:index="index">
                        <th scope="col" class="doc-name-col" key={column.label}>
                            <div class="slds-truncate">{column.label}</div>
                        </th>
                    </template>
                </tr>
            </thead>
            <tbody>
                <template for:each={processWorkItems} for:item="workItem" for:index="index">
                    <tr key={workItem.rowKey} data-id={workItem.id} class={workItem.rowClass}>
                        <td>
                            <div class="slds-truncate">{workItem.Process_Step__c}</div>
                        </td>
                        <td>
                            <div class="slds-truncate">{workItem.Name}</div>
                        </td>
                        <td>
                            <div class="slds-truncate">{workItem.Needed_By__c}</div>
                        </td>
                        <td><div class="slds-truncate">{workItem.Stage__c}</div></td>
                        <td>
                            <div class="slds-truncate">{workItem.Status__c}</div>
                        </td>
                        <td class="slds-cell-align-center">
                            <template if:true={workItem.isShowButton}>
                                <lightning-button
                                    variant="brand"
                                    label={workItem.actionName}
                                    data-index={index}
                                    data-action={workItem.action}
                                    onclick={handleActionClick}
                                ></lightning-button>
                            </template>
                            <template if:false={workItem.isShowButton}
                                ><div class="slds-truncate">{workItem.Action_Type__c}</div></template
                            >
                        </td>
                    </tr>
                </template>
            </tbody>
        </table>
    </lightning-card>
    <!-- Models  -->
    <template if:true={_showModal}>
        <c-general-modal modal={modal} onclose={hideModal} onyes={removeDocumentConfirm} onno={hideModal}>
            <span slot="content">
                <template if:true={isDocumentRemove}>
                    <div class="slds-modal__content slds-p-around_medium">
                        <p>Do you want to replace the document?</p>
                    </div>
                </template>
                <template if:true={isViewVersions}>
                    <div class="slds-modal__content slds-p-around_medium">
                        <c-document-version-view record-id={documentId}> </c-document-version-view>
                    </div>
                </template>
            </span>
        </c-general-modal>
    </template>
</template>



import { LightningElement, track, api, wire } from 'lwc';
import { loadStyle } from 'lightning/platformResourceLoader';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import fetchProcessItemsByAppForm from '@salesforce/apex/WorkflowItemTrackerLWCHelper.fetchProcessItemsByAppForm';
import fetchProcessItemsByApplicationForm from '@salesforce/apex/WorkflowItemTrackerLWCHelper.fetchProcessItemsByApplicationForm';
//import getCreditScore from '@salesforce/apex/WorkflowItemTrackerLWCHelper.getCreditScore';
import myCustomStyles from '@salesforce/resourceUrl/myCustomStyles'; // Assuming myCustomStyles is your static resource name
import { NavigationMixin } from 'lightning/navigation';

export default class WorkItemTracker extends NavigationMixin(LightningElement) {
    @api recordId;
    _workItems = [];
    _orgWorkItems = [];
    _showSpinner = false;
    @track workItemFilter = { stage: null };
    columns = [
        { label: 'Process Step', fieldName: 'name' },
        { label: 'Work Item', fieldName: 'website' },
        { label: 'Primary Owner', fieldName: 'phone' },
        { label: 'Needed By', fieldName: 'amount' },
        { label: 'Status', fieldName: 'Status' },
        { label: 'Actions', fieldName: 'closeAt' }
    ];

    // change dinamicly picklist values
    associatedToOptions = [
        { label: 'All', value: '' },
        { label: 'Application', value: 'Application' },
        { label: 'Business', value: 'Business' },
        { label: 'Personal', value: 'Personal' }
    ];
    // change dinamicly picklist values
    stageOptions = [
        { label: 'All Stages', value: '' },
        { label: 'Prospect', value: 'Prospect' },
        { label: 'Pre-screen', value: 'Pre-screen' },
        { label: 'Analyze CAM', value: 'Analyze CAM' },
        { label: 'Approvals', value: 'Approvals' },
        { label: 'Closing', value: 'Closing' },
        { label: 'Booked', value: 'Booked' }
    ];
    StatusOptions = [
        { label: 'No Document', value: 'No Document' },
        { label: 'isUploaded', value: 'isUploaded' },
        { label: 'Reviewed', value: 'Reviewed' },
        { label: 'Rejected', value: 'Rejected' }
    ];

    acceptedFormats = ['.pdf', '.png', '.jpg', '.jpeg', '.doc', '.docx'];

    _modal = {
        header: '',
        hasFooter: true,
        footer: {
            buttons: [
                {
                    label: 'Upload',
                    event: 'upload',
                    variant: 'brand',
                    class: 'slds-var-m-right_small',
                    disabled: true
                },
                { label: 'Cancel', event: 'cancel', variant: '', disabled: false }
            ]
        }
    };
    replaceDocumentModal = {
        header: 'Replace Document',
        hasFooter: true,
        footer: {
            buttons: [
                {
                    label: 'Yes',
                    event: 'yes',
                    variant: 'brand',
                    class: 'slds-var-m-right_small',
                    disabled: false
                },
                { label: 'No', event: 'no', variant: '', disabled: false }
            ]
        }
    };

    // getters
    get modal() {
        return this.modelToShow;
    }

    get processWorkItems() {
        return this._workItems;
    }
    get isShowSpinner() {
        return this._showSpinner;
    }
    @wire(fetchProcessItemsByAppForm, { appFormId: '$recordId' })
    fetchProcessItemsByAppForm({ error, data }) {
        if (error) {
            this.handelError(error);
            // TODO: Error handling
        } else if (data) {
            console.log('Work Items:', data);
            this.prepareWorkitems(data);
        }
    }

    async fetchProcessItemsByApplicationForm() {
        try {
            this.showSpinner();
            let result = await fetchProcessItemsByApplicationForm({ appFormId: this.recordId });
            this.prepareWorkitems(result);
        } catch (error) {
            this.handelError(error);
        }
        this.hideSpinner();
    }
    async getCreditScore() {
        try {
            this.showSpinner();
            let result = await getCreditScore({ appFormId: this.recordId });
            this.showSuccessToast(
                'Credit Score Success',
                'Credit Score has been updated successfully Credit Score:' + result
            );
        } catch (error) {
            this.handelError(error);
        }
        this.hideSpinner();
    }

    prepareWorkitems(data) {
        this._workItems = data.map((item) => ({
            ...item,
            rowKey: item.Id,
            isShowButton: item.Name.toLowerCase().includes('credit check'),
            action: 'CreditCheck',
            actionName: 'Run Integration'
        }));
        this._orgWorkItems = this._workItems;
        console.log('Work Items:', data);
    }

    filterDocuments() {
        this._workItems = [...this._orgWorkItems];
        this._workItems = [
            ...this._workItems.filter((record) => {
                let match = true;
                if (this.workItemFilter.stage) {
                    match = match && record.Stage__c === this.workItemFilter.stage;
                }
                if (this.workItemFilter.name) {
                    match = match && record.Name.toLowerCase().includes(this.workItemFilter.name);
                }
                return match;
            })
        ];
        console.log('filter Document ' + JSON.stringify(this.documents));
    }

    handleActionClick(event) {
        let action = event.target.dataset.action;
        let index = event.target.dataset.index;
        switch (action) {
            case 'CreditCheck':
                this.getCreditScore();
                break;
            default:
                break;
        }
    }
    // Filter Handleing methods
    handleStageChange(event) {
        let selectedStage = event.detail.value;
        this.workItemFilter.stage = !selectedStage || selectedStage.trim() === '' ? null : selectedStage;
        this.filterDocuments();
    }
    handleSearchInput(event) {
        let name = event.detail.value;
        this.workItemFilter.name = !name || name.trim() === '' ? null : name.toLowerCase();
        this.filterDocuments();
    }
    // LYF Hoook
    connectedCallback() {
        loadStyle(this, myCustomStyles)
            .then(() => {
                console.log('Custom styles loaded');
            })
            .catch((error) => {
                console.error('Error loading custom styles:', error);
            });
    }

    // Event Handlers
    handleAddWorkItem() {
        let newWorkItem = {
            Action_Type__c: null,
            Application_Form__c: this.recordId,
            Assign_To__c: '',
            Id: '',
            Loan_Amount__c: null,
            Name: '',
            Needed_By__c: '',
            Owner_Id__c: null,
            Process_Step__c: '',
            Stage__c: '',
            Status__c: 'New'
        };
        this._workItems = JSON.parse(JSON.stringify([...this._workItems, newWorkItem]));
    }

    // Toast Methods
    showErrorToast(title, message) {
        this.showToast('error', title, message);
    }

    showSuccessToast(title, message) {
        this.showToast('Success', title, message);
    }

    showWarningToast(title, message) {
        this.showToast('warning', title, message);
    }

    showToast(variant, title, message) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: title,
                message: message,
                variant: variant
            })
        );
    }

    handelError(error) {
        this.showErrorToast('Error', error);
        console.error('Error:', error);
    }
    //  spinner methods
    showSpinner() {
        this._showSpinner = true;
    }
    hideSpinner() {
        this._showSpinner = false;
    }
}
