public with sharing class ClusterJobOutputStep extends ClusterBatchBase implements ClusterAlgorithmStep {
    public static Logger log = LogFactory.getLogger();
    
    @TestVisible
    private Boolean skipFieldNameCheck = false; //To enable updates to standard fields for unit test
    Map<String, Schema.DisplayType> outputFieldTypes;

    public ClusterJobOutputStep() {
        
    }

    public override void init(ClusterAlgorithmRunner runner) {
        log.debug('Starting result output step');
        ClusterKMeansJobState jobState = (ClusterKMeansJobState)runner.getJobState();
        ClusterModelWrapper model = jobState.model;
        Schema.DescribeSObjectResult[] descResult = Schema.describeSObjects(new String[] { model.objectName });
        System.assertNotEquals(descResult.size(), 0, 'Cannot find object ' + model.objectName + ' in the describe result');
        this.outputFieldTypes = new Map<String, Schema.DisplayType>();
        Map<String,Schema.SObjectField> fieldsMap = descResult[0].fields.getMap();
        for (ClusterModelFieldWrapper field:model.fields) {
            SObjectField sof = fieldsMap.get(field.name);
            DescribeFieldResult fd = sof == null ? null : sof.getDescribe();
            if (fd != null) {
                if (field.distanceType == ClusterConstants.FIELDTYPE_OUTPUT && (!fd.isUpdateable() || !fd.isAccessible())) {
                    throw new ClusterException('Current user dosn\'t have permissions to update field ' + fd.getName());
                }
                this.outputFieldTypes.put(field.name, fd.getType());
            }
        }
        super.init(runner);
    }
    
    protected override Database.QueryLocator getBatchQueryLocator() {
        return Database.getQueryLocator(this.runner.getJobState().model.soql);
    }

    public override void processRecords(Database.BatchableContext bc, List<SObject> scope) {
        ClusterKMeansJobState jobState = (ClusterKMeansJobState)this.runner.getJobState();
        ClusterModelWrapper model = jobState.model;
        Integer length = model.fields.size();
        Object[] values = new Object[length];
        Integer scopeSize = scope.size();
        List<String> ids = new List<String>();
        String idFieldName = 'id';
        for (Integer sindex = 0; sindex < scopeSize; sindex++){
            SObject record = scope[sindex];
            for (Integer i = 0; i < length; i++) {
                if (model.fields[i].isIdField) {
                    ids.add(String.valueOf(record.get(model.fields[i].name)));
                    idFieldName = model.fields[i].name;
                }
            }
        }
        log.debug('Retrieving cluster job results for ' + ids.size() + ' records');
        //CRUD permissions on ClusterJobResult__c are checked in ClusterAccessCheck.checkCRUDPermission in ClusterAlgorithmRunner.start which is calling all ClusterAlgorithmStep implementors
        //exception is thrown there in case of no access
        //Checking the same in every processRecords is redundant
        List<ClusterJobResult__c> results = [SELECT Id, Cluster__c, Json__c, RecordId__c, RecordName__c, ClusterNumber__c, ClusterJob__c FROM ClusterJobResult__c WHERE ClusterJob__c = :jobState.clusterJob.Id AND RecordId__c IN :ids LIMIT :scope.size()];
        Map<String, ClusterJobResult__c> resultsMap = new Map<String, ClusterJobResult__c>();
        //Building map for faster lookup
        for (ClusterJobResult__c result:results) {
            resultsMap.put(result.RecordId__c, result);
        }
        Map<Id, SObject> updateMap = new Map<Id, SObject>();
        for (Integer sindex = 0; sindex < scopeSize; sindex++){
            SObject record = scope[sindex];
            for (Integer i = 0; i < length; i++) {
                if (model.fields[i].distanceType == ClusterConstants.FIELDTYPE_OUTPUT) {
                    //Update only if field name starts with clusternumber
                    if (model.fields[i].name.toLowerCase().startsWith('clusternumber') || this.skipFieldNameCheck) {
                        ClusterJobResult__c result = resultsMap.get(String.valueOf(record.get(idFieldName)));
                        if (result != null) {
                            Schema.DisplayType fieldType = this.outputFieldTypes.get(model.fields[i].name);
                            if (fieldType != null) {
                                Object fieldValue;
                                if (fieldType == Schema.DisplayType.DOUBLE) {
                                    fieldValue = Double.valueOf(result.ClusterNumber__c);
                                }
                                else if (fieldType == Schema.DisplayType.INTEGER) {
                                    fieldValue = Integer.valueOf(result.ClusterNumber__c);
                                }
                                else if (fieldType == Schema.DisplayType.STRING) {
                                    fieldValue = String.valueOf(result.ClusterNumber__c);
                                }
                                record.put(model.fields[i].name, fieldValue);
                                updateMap.put(record.Id, record);
                            }
                        }
                        else {
                            log.debug('Cluster result was not found for record with id ' + record.get(idFieldName));
                        }
                    }
                }
            }
        }
        if (updateMap.size() > 0) {
            log.debug('updating ' + updateMap.size() + ' records');
            //Update permissions are checked in ClusterAccessCheck.checkModelObjectAccessPermissions
            //which is called from ClusterAlgorithmRunner.validateModel
            update updateMap.values();
        }
    }
}