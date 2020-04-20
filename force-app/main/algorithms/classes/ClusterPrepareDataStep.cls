/*
 * Prepare data algorithm step - populates ClusterJobResult__c and finds min and max values for each field
 *
 * @author: Iskander Mukhamedgaliyev
 */
public with sharing class ClusterPrepareDataStep extends ClusterBatchBase implements ClusterAlgorithmStep {

    public ClusterPrepareDataStep() {

    }

    public override void init(ClusterAlgorithmRunner runner) {
        ClusterBatchBase.log.debug('Starting prepare data step');
        super.init(runner);
        ClusterJobState jobState = this.runner.getJobState();
        jobState.minMaxValues = new ClusterMinMaxValue[jobState.model.fields.size()];
        jobState.numRecords = 0;
        for (Integer i = 0; i < jobState.minMaxValues.size(); i++) {
            jobState.minMaxValues[i] = new ClusterMinMaxValue();
        }
    }
    
    protected override Database.QueryLocator getBatchQueryLocator() {
        return Database.getQueryLocator(this.runner.getJobState().model.soql);
    }

    public override void processRecords(Database.BatchableContext bc, List<SObject> scope) {
        ClusterJobState jobState = this.runner.getJobState();
        ClusterModelWrapper model = jobState.model;
        ClusterMinMaxValue[] minMaxValues = jobState.minMaxValues;
        Integer length = model.fields.size();
        Object[] values = new Object[length];
        Integer scopeSize = scope.size();
        ClusterJobResult__c[] results = new ClusterJobResult__c[scopeSize];
        Integer sampleRecordSize = ClusterConstants.getSampleRecordSize(model);
        if (scopeSize > 0) {
            //Checking the access of the real object returned from the soql query. 
            //Somebody could provide a SOQL query from an object which is different from the model object
            //This is not allowed
            Schema.DescribeSObjectResult realDesc = scope.get(0).getSObjectType().getDescribe();
            ClusterAccessCheck.checkReadPermission(realDesc);
            if (model.objectName.toLowerCase() != realDesc.getName().toLowerCase()) {
                throw new ClusterException('The SOQL query object name (' + realDesc.getName() + ') is not the same as model object name (' + model.objectName + ')');
            }
        }
        for (Integer sindex = 0; sindex < scopeSize; sindex++){
            SObject record = scope[sindex];
            ClusterJobResult__c result = new ClusterJobResult__c();
            for (Integer i = 0; i < length; i++) {
                Object fieldValue = ClusterDataHelper.getSObjectFieldValue(record, model.fields[i]);
                values[i] = fieldValue;
                //Populating minMaxValues with min and max values for each field respectively
                //This is essential for distance calculations
                Integer compare = ClusterDataHelper.compareFieldValueAbs(minMaxValues[i].maxValue, fieldValue, model.fields[i]);
                if (compare < 0) {
                    //For text distances min and max values will contain string length
                    if (model.fields[i].distanceType == ClusterConstants.FIELDTYPE_TEXT) {
                        minMaxValues[i].maxValue = fieldValue == null ? 0 : String.valueOf(fieldValue).length();
                    }
                    else {
                        minMaxValues[i].maxValue = fieldValue;
                    }
                }
                compare = ClusterDataHelper.compareFieldValueAbs(minMaxValues[i].minValue, fieldValue, model.fields[i]);
                if (compare > 0 || (minMaxValues[i].minValue == null)) {
                    if (model.fields[i].distanceType == ClusterConstants.FIELDTYPE_TEXT) {
                        minMaxValues[i].minValue = fieldValue == null ? 0 : String.valueOf(fieldValue).length();
                    }
                    else {
                        minMaxValues[i].minValue = fieldValue;
                    }
                }
                if (model.fields[i].isIdField) {
                    result.RecordId__c = String.valueOf(fieldValue);
                }
                if (model.fields[i].isNameField) {
                    result.RecordName__c = String.valueOf(fieldValue);
                }                
            }            
            //Populating ClusterJobResult__c
            if ((result.RecordName__c == null) || (result.RecordName__c == '')) {
                result.RecordName__c = result.RecordId__c;
            }
            result.ClusterJob__c = jobState.clusterJob.Id;
            result.Json__c = JSON.serialize(values);
            result.Random__c = ClusterDataHelper.getRandomInt(0, sampleRecordSize); //Randomize record order
            results[sindex] = result;
        }
        ClusterBatchBase.log.debug('Inserting result records');
        //CRUD permissions on ClusterJobResult__c are checked in ClusterAccessCheck.checkCRUDPermission in ClusterAlgorithmRunner.start which is calling all ClusterAlgorithmStep implementors
        //exception is thrown there in case of no access
        //Checking the same in every processRecords is redundant
        insert results;
        jobState.numRecords += scopeSize;
    }

    public override void done(){
        ClusterKMeansJobState jobState = (ClusterKMeansJobState)runner.getJobState();
        ClusterModelWrapper model = jobState.model;
        if (jobState.numRecords == 0) {
            throw new ClusterException('Model SOQL query returned 0 records, interrupting the cluster job');
        }
        //precalculating delta (max-min)
        for (Integer i=0; i<model.fields.size(); i++) {
            if (model.fields[i].distanceType == ClusterConstants.FIELDTYPE_NUMERIC) {
                jobState.minMaxValues[i].delta = Double.valueOf(jobState.minMaxValues[i].maxValue) - Double.valueOf(jobState.minMaxValues[i].minValue);
            }
        }
        super.done();
    }
}
