import { LightningElement, track, api } from 'lwc';
import getPredictUiModel from '@salesforce/apex/ClusterPredictController.getPredictUiModel';
import getModelJobState from '@salesforce/apex/ClusterPredictController.getModelJobState';

export default class ClusterPredict extends LightningElement {
    @api recordId;
    @track displayMessage = '';
    @track uiModel;
    @track modelLoaded = false;
    error;

    connectedCallback() {
        console.log('connectedCallback');
        getPredictUiModel({
            recordId: this.recordId
        })
        .then(result => {
            this.uiModel = result;
            this.modelLoaded = true;
        })
        .catch((error) => {
            console.error(error);
            this.error = error;
            this.message = 'Error received: code' + error.errorCode + ', ' +
                'message ' + error.body.message;
        });
    }

    predict() {
        this.dispatchEvent(new ShowToastEvent({
            title: 'Success',
            message: 'some message here.',
            variant: 'success',
        }));
        this.dispatchEvent(new CustomEvent('close'));
    }

    cancel() {
        this.dispatchEvent(new CustomEvent('close'));
    }
}