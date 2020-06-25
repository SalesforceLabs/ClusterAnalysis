/*
 * Prepare data algorithm step - populates ClusterJobResult__c and finds min and max values for each field
 *
 * @author: Iskander Mukhamedgaliyev
 */
public with sharing class ClusterPrepareDataStep extends ClusterBatchBase implements ClusterAlgorithmStep {
    private static final Integer RANDOM_SIZE = 1000000;

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
        ClusterSObjectProcessor objectProcessor = new ClusterSObjectProcessor(jobState);

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
            ClusterDataPoint dataPoint = objectProcessor.processSObject(record);
            //Populating ClusterJobResult__c
            result.RecordId__c = dataPoint.externalId;
            result.RecordName__c = dataPoint.recordName;            
            result.ClusterJob__c = jobState.clusterJob.Id;
            result.Json__c = JSON.serialize(dataPoint.values);
            result.Random__c = ClusterDataHelper.getRandomInt(0, RANDOM_SIZE); //Randomize record order
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
        ClusterSObjectProcessor objectProcessor = new ClusterSObjectProcessor(jobState);
        objectProcessor.processTotals();        
        super.done();
    }
}
