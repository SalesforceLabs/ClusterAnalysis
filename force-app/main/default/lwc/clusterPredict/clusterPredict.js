import { LightningElement, track, api } from 'lwc';
import { loadScript } from 'lightning/platformResourceLoader';
import getPredictUiModel from '@salesforce/apex/ClusterPredictController.getPredictUiModel';
import predict from '@salesforce/apex/ClusterPredictController.predict';
import clustanUtilsUrl from '@salesforce/resourceUrl/clustanUtils';

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
    @track displayMessage = '';
    @track uiModel;
    @track modelLoaded = false;
    @track predictCluster;
    @track predictModel;
    @track predictionLoaded = false;
    @track selectedModelId;
    @track similarityData;
    @track similarityValue;
    similarityColumns = columns;
    defaultSortDirection = 'asc';
    sortDirection = 'asc';
    sortedBy;
    error;

    get modelPickerVisible() {
        return this.modelLoaded && !this.uiModel.recordIdNeeded && !this.predictionLoaded;
    }

    get predictResultsVisible() {
        return this.predictionLoaded;
    }

    connectedCallback() {
        Promise.all([
            getPredictUiModel({
                recordId: this.recordId
            }),
            loadScript(this, clustanUtilsUrl + '/clustanUtils.js')
        ]).then(result => {
            this.uiModel = result[0];
            this.modelLoaded = true;
        })
        .catch((error) => {
            console.error(error);
            this.error = error;
            this.message = 'Error received: code' + error.errorCode + ', ' +
                'message ' + error;
        });
    }

    predictClick() {
        /*
        this.dispatchEvent(new ShowToastEvent({
            title: 'Success',
            message: 'some message here.',
            variant: 'success',
        }));
        */
        let jobOrModelId;
        let dpRecordId;
        if (this.uiModel.recordIdNeeded) {
            modelOrJobId = this.recordId;
            //TODO: provide record id
        }
        else {
            jobOrModelId = this.uiModel.jobId ? this.uiModel.jobId : this.selectedModelId;
            dpRecordId = this.recordId;
        }
        predict({
            recordId: dpRecordId,
            jobOrModelId: jobOrModelId
        })
        .then(result => {            
            this.predictCluster = result;
            this.predictCluster.jobState = JSON.parse(this.predictCluster.jobState);
            this.predictModel = this.predictCluster.jobState.model;
            clustanUtils.decompressDataPointValues(this.predictCluster.jobState, this.predictCluster.dataPoint);
            clustanUtils.decompressJobState(this.predictCluster.jobState);
            this.similarityValue = (100.0 - 100.0 * clustanUtils.gowerDistance(this.predictCluster.dataPoint.values, this.predictCluster.jobState.centroids[this.predictCluster.clusterIndex].values, this.predictCluster.jobState)).toFixed(2);
            let similarities = clustanUtils.calculateSimilarity(this.predictCluster.dataPoint.values, this.predictCluster.jobState.centroids[this.predictCluster.clusterIndex].values, this.predictCluster.jobState);
            this.similarityData = similarities
                .map((value, index) =>({ name: this.predictCluster.jobState.model.fields[index].name, similarity: value, weight: this.predictCluster.jobState.model.fields[index].weight}))
                .filter(item => item.similarity != null);
            this.predictionLoaded = true;
        })
        .catch((error) => {
            console.error(error);
            this.error = error;
            this.message = 'Error received: code' + error.errorCode + ', ' +
                'message ' + error.body.message;
        });
    }

    sortBy(field, reverse, primer) {
        const key = primer
            ? function(x) {
                  return primer(x[field]);
              }
            : function(x) {
                  return x[field];
              };

        return function(a, b) {
            a = key(a);
            b = key(b);
            return reverse * ((a > b) - (b > a));
        };
    }

    onHandleSort(event) {
        const { fieldName: sortedBy, sortDirection } = event.detail;
        const cloneData = [...this.similarityData];

        cloneData.sort(this.sortBy(sortedBy, sortDirection === 'asc' ? 1 : -1));
        this.similarityData = cloneData;
        this.sortDirection = sortDirection;
        this.sortedBy = sortedBy;
    }

    cancel() {
        this.dispatchEvent(new CustomEvent('close'));
    }
}