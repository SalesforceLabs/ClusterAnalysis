import { LightningElement, track, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import clustanUtils from 'c/clustanUtils';

export default class ClusterDataPointDetails extends NavigationMixin(LightningElement) {
    @api clusterDataPoint;
    @api jobState;
    @api clusterColor;
    @api showRecordName;
    @track objectValues;
    @track clusterColorCss;
    @track externalUrl;

    connectedCallback() {
        this.rebind();
    }

    rebind() {
        this.externalUrl = '#';
        let dataPoint = this.clusterDataPoint;
        let jobState = this.jobState;
        if (dataPoint == null || jobState == null) {
            return;
        }
        let model = jobState.model;
        let dpValues = dataPoint.values;
        let objectValues = dpValues.map((cv,index) => { return { 
            name: model.fields[index].displayLabel ? model.fields[index].displayLabel : model.fields[index].name, value: clustanUtils.convertDataPointValue(index, cv, jobState)
        } });
        this.objectValues = objectValues;
        this.clusterColorCss = 'background-color: ' + this.clusterColor;
        this[NavigationMixin.GenerateUrl](this.getRecordPageNavigationDetails(this.clusterDataPoint.externalId)).then(url => {
            this.externalUrl = url;
        });
    }

    handleLinkClick(event) {
        event.preventDefault();
        this[NavigationMixin.Navigate](this.getRecordPageNavigationDetails(this.clusterDataPoint.externalId));
    }

    getRecordPageNavigationDetails(recordId) {
        return {
            type: 'standard__recordPage',
            attributes: {
                recordId: recordId,
                actionName: 'view',
            }
        }
    }
}