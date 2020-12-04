import { LightningElement, track, api } from 'lwc';
import getNearestNeighbors from '@salesforce/apex/ClusterPredictController.getNearestNeighbors';
import pullNearestNeighbors from '@salesforce/apex/ClusterPredictController.pullNearestNeighbors';
import search from '@salesforce/apex/ClusterPredictController.search';
import clustanUtils from 'c/clustanUtils';
import { NavigationMixin } from 'lightning/navigation';

export default class ClusterNearestNeighbors extends LightningElement {
    @api recordId;
    @api jobOrModel;
    @api numNeighbors;
    @api headerLabel;
    @track recordLookupVisible;
    @track errorMessage = '';
    @track uiModel;
    @track spinnerVisible = true;
    @track lookupSelection = [];
    lookupRecordId;
    @track recordSearchLabel;
    @track resultsLoaded = false;
    @track resultColumnCssClass;
    @track containerDivStyle = "";
    pollingCount = 0;

    connectedCallback() {
        this.recordSearchLabel = 'Search';
        this.pollingCount = 0;
        if (!this.numNeighbors) {
            this.numNeighbors = 15;
        }
        if (this.jobOrModel) {
            this.lookupRecordId = this.recordId;
        }
        else {
            this.jobOrModel = this.recordId;
        }
        this.recordLookupVisible = (!this.lookupRecordId);
        if (this.recordLookupVisible) {
            this.containerDivStyle = "";
            this.resultColumnCssClass = "predict-neighbors__col slds-col slds-medium-size_6-of-12 slds-large-size_4-of-12 slds-size_1-of-1";
        }
        else {
            this.containerDivStyle = "max-height: 600px";
            this.resultColumnCssClass = "predict-neighbors__col slds-col slds-size_1-of-1";
        }
        this.callGetModel(false);
    }

    get predictResultsVisible() {
        return this.uiModel != null && (this.uiModel.nearestNeighbors != null);
    }

    callGetModel(validate) {
        if (validate && !this.validate()) return;
        this.resultsLoaded = false;
        this.pollingCount = 0;
        this.spinnerVisible = true;
        getNearestNeighbors({
            recordId: this.lookupRecordId,
            jobOrModel: this.jobOrModel,
            numNeighbors: this.numNeighbors
        }).then(result => {
            this.spinnerVisible = false;
            this.uiModel = result;
            this.recordSearchLabel = `Search ${this.uiModel.modelObjectLabel}`;
            this.setPolling();
        })
        .catch((error) => {
            this.handleError(error);
        });
    }

    validate() {        
        if (!this.lookupRecordId) {
            this.handleError('Record id or name is required');
            return false;
        }
        if (!this.numNeighbors || (this.numNeighbors<1) || (this.numNeighbors>50)) {
            this.handleError('Incorrect neighbors count, should be between 1 and 50');
            return false;
        }
        return true;        
    }

    callPullModel() {
        this.spinnerVisible = true;
        pullNearestNeighbors({
            recordId: this.lookupRecordId,
            jobOrModel: this.jobOrModel,
            numNeighbors: this.numNeighbors
        }).then(result => {
            this.spinnerVisible = false;
            this.uiModel = result;
            this.setPolling();
        })
        .catch((error) => {
            this.handleError(error);
        });
    }

    setPolling() {
        if (!this.lookupRecordId) return;
        let MAX_POLLING_COUNT = 12; //we will poll for 2 mins max
        if (this.uiModel.nearestNeighbors == null || this.uiModel.nearestNeighbors.length == 0) {
            this.pollingCount++;
            if (this.pollingCount < MAX_POLLING_COUNT) {
                this.spinnerVisible = true;
                setTimeout(() => {
                    this.callPullModel();
                }, 10000);
            }
            else if (this.pollingCount == MAX_POLLING_COUNT) {
                this.handleError('Could not find similar records');
            }
        }
        else {
            this.preprocessResults();
            this.resultsLoaded = true;
            this.spinnerVisible = false;
        }
    }

    preprocessResults() {
        this.uiModel.nearestNeighbors.forEach(nn => {
            if (nn.neighborDataPoint && nn.neighborDataPoint.clusterIndex >=0) nn.clusterColor = this.uiModel.clusterColors[nn.neighborDataPoint.clusterIndex];
            nn.similarity = ((1.0 - nn.distance) * 100.0).toFixed(2) + '%';
        });
        this.uiModel.jobState = JSON.parse(this.uiModel.jobState);

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

    handleNumNeighborsChange(event) {
        this.numNeighbors = event.detail.value;
    }

    handleFindClick(event) {
        this.callGetModel(true);
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