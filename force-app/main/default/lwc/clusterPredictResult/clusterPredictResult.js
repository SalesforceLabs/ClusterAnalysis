import { LightningElement, track, api } from 'lwc';
import predict from '@salesforce/apex/ClusterPredictController.predict';
import clustanUtils from 'c/clustanUtils';
import { NavigationMixin } from 'lightning/navigation';

export default class ClusterPredictResult extends NavigationMixin(LightningElement) {
    @api recordId;
    @api jobOrModel;
    @api hideHeader = false;
    @api headerLabel = 'Cluster Predictions';
    @track predictCluster;
    @track predictModel;
    @track predictionLoaded = false;
    @track errorMessage = '';
    @track similarityData;
    @track similarityValue;
    @track spinnerVisible = true;
    @track clusterPageUrl = '#';
    pollingCount = 0;
    timeoutHandle = null;

    connectedCallback() {
        this.pollingCount = 0;
        if (this.recordId && this.jobOrModel) {
            predict({
                    recordId: this.recordId,
                    jobOrModel: this.jobOrModel,
                    isPolling: false
                })
            .then(result => {
                this.predictCallback(result);
            })
            .catch((error) => {
                this.handleError(error);
            });
        }
        else {
            this.handleError('Model or record are required for prediction');
        }
    }

    disconnectedCallback() {
        if (this.timeoutHandle) {
            clearTimeout(this.timeoutHandle);
        }
    }

    renderedCallback() {
        if (this.predictionLoaded) {
            let clusterbox = this.template.querySelector('div.clusterbox');
            if (clusterbox)
                clusterbox.style.backgroundColor = this.predictCluster.clusterColor;
        }
    }

    @api
    getPrediction() {
        return this.predictCluster;
    }

    @api
    predict() {
        if (this.recordId && this.jobOrModel) {
            this.spinnerVisible = true;
            return predict({
                recordId: this.recordId,
                jobOrModel: this.jobOrModel,
                isPolling: this.pollingCount > 0
            })
            .then(result => {
                this.predictCallback(result);
            })
            .catch((error) => {
                this.handleError(error);
            });
        }
        else {
            return null;
        }
    }

    predictCallback(result) {
        this.predictCluster = result;
        if (this.predictCluster.clusterIndex == -1 || this.predictCluster.predictionResult == null) {
            this.setPolling();
            return;
        }
        this.pollingCount = 0;
        this.spinnerVisible = false;
        this.predictCluster.jobState = JSON.parse(this.predictCluster.jobState);
        this.predictModel = this.predictCluster.jobState.model;
        clustanUtils.decompressDataPointValues(this.predictCluster.jobState, this.predictCluster.dataPoint.values);
        clustanUtils.decompressJobState(this.predictCluster.jobState);
        this.predictCluster.predictionResult.fieldPredictions.forEach(fieldPrediction => {
            fieldPrediction.fieldValuePredictions.forEach(fvp => {
                fvp.probabilityText = (100.0 * fvp.probability).toFixed(2) 
                if (fieldPrediction.isNumeric) {
                    fvp.valueText = Number(fvp.value).toLocaleString();
                }
                else {
                    fvp.valueText = fvp.value;
                }
            });
        });
        
        this.predictionLoaded = true;
        this[NavigationMixin.GenerateUrl](this.getClusterPageNavigationDetails(this.predictCluster.clusterId)).then(url => {
            this.clusterPageUrl = url;
        });
    }

    setPolling() {
        this.timeoutHandle = null;
        if (!this.recordId) return;
        let MAX_POLLING_COUNT = 12; //we will poll for 2 mins max
        this.pollingCount++;
        if (this.pollingCount < MAX_POLLING_COUNT) {
            this.spinnerVisible = true;
            this.timeoutHandle = setTimeout(() => {
                this.predict();
            }, 10000);
        }
        else if (this.pollingCount == MAX_POLLING_COUNT) {
            this.handleError('Could not get prediction. Try reloading the page in few minutes');
        }
    }

    get hasFieldPredictions() {
        return this.predictionLoaded && (this.predictCluster.predictionResult.fieldPredictions && this.predictCluster.predictionResult.fieldPredictions.length > 0);
    }

    handleClusterLinkClick(event) {
        event.preventDefault();
        this[NavigationMixin.Navigate](this.getClusterPageNavigationDetails(this.predictCluster.clusterId));
    }

    getClusterPageNavigationDetails(clusterId) {
        return {
            type: 'standard__recordPage',
            attributes: {
                recordId: clusterId,
                actionName: 'view',
            }
        }
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