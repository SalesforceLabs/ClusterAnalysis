import { LightningElement, track, api } from 'lwc';
import getPredictUiModel from '@salesforce/apex/ClusterPredictController.getPredictUiModel';
import search from '@salesforce/apex/ClusterPredictController.search';

const columns = [
    { label: 'Name', fieldName: 'name' },
    {
        label: 'Similarity',
        fieldName: 'similarity',
        type: 'percent',
        sortable: true,
        cellAttributes: { alignment: 'left' },
    },
    {
        label: 'Weight',
        fieldName: 'weight',
        type: 'percent',
        sortable: true,
        cellAttributes: { alignment: 'left' },
    },
];

export default class ClusterPredict extends LightningElement {
    @api recordId;
    @track errorMessage = '';
    @track uiModel;
    @track modelLoaded = false;
    @track jobOrModelId;
    @track dpRecordId;
    @track predictionLoaded = false;
    @track selectedModelId;
    @track lookupRecordId;
    @track lookupSelection = [];
    @track spinnerVisible = true;

    get modelPickerVisible() {
        return this.modelLoaded && !this.uiModel.recordIdNeeded && !this.predictionLoaded;
    }

    get recordLookupVisible() {
        return this.modelLoaded && this.uiModel.recordIdNeeded && !this.predictionLoaded;
    }

    get predictResultsVisible() {
        return this.predictionLoaded;
    }

    connectedCallback() {
        getPredictUiModel({
                recordId: this.recordId
        }).then(result => {
            this.spinnerVisible = false;
            this.uiModel = result;
            if (this.uiModel.models && this.uiModel.models.length > 0) {
                this.selectedModelId = this.uiModel.models[0].modelId;
            }
            this.modelLoaded = true;
        })
        .catch((error) => {
            this.handleError(error);
        });
    }

    handleModelSelect(event) {
        this.selectedModelId = event.detail.name;
    }

    handleLookupSearch(event) {
        this.errorMessage = '';
        const target = event.target;
        this.lookupRecordId = null;
        event.detail.jobOrModelId = this.recordId;
        // Call Apex endpoint to search for records and pass results to the lookup
        search(event.detail)
            .then((results) => {
                target.setSearchResults(results);
            })
            .catch((error) => {
                this.handleError(error);;
            });
    }

    handleLookupSelectionChange(event) {
        if (event.detail && event.detail.length > 0) {
            this.lookupRecordId = event.detail[0];
        }
    }

    predictClick() {
        this.errorMessage = '';
        if (this.uiModel.recordIdNeeded) {
            this.jobOrModelId = this.recordId;
            this.dpRecordId = this.lookupRecordId;
        }
        else {
            this.jobOrModelId = this.uiModel.jobId ? this.uiModel.jobId : this.selectedModelId;
            this.dpRecordId = this.recordId;
        }
        this.predictionLoaded = true;        
    }

    cancel() {
        this.dispatchEvent(new CustomEvent('close'));
    }

    handleError(error) {
        this.spinnerVisible = false;
        console.error(error);
        if (error.body && error.body.message) {
            this.errorMessage = error.body.message;
        }
        else if (error.message) {
            this.errorMessage = error.message;
        }
        else if (typeof error === 'string' || error instanceof String) {
            this.errorMessage = error;
        }
        else {
            this.errorMessage = JSON.stringify(error);
        }
    }
}