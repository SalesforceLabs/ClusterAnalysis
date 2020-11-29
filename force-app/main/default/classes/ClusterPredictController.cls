/*
 * Controller for clusterPredict and clusterPredictResult (LWC)
 *
 * @author: Iskander Mukhamedgaliyev
 */
public with sharing class ClusterPredictController {

    public static final Integer SOSL_SEARCH_LIMIT = 50;
    public static Logger log = LogFactory.getLogger();

    @AuraEnabled(Cacheable = true)
    public static ClusterPredictUiModel getPredictUiModel(Id recordId) {
        String keyCode  = String.valueOf(recordId).subString(0,3);
        Schema.DescribeSObjectResult objectDescribe = ClusterUtils.findObjectDescByKeyCode(keyCode);
        ClusterPredictUiModel uiModel = new ClusterPredictUiModel();                
        if (objectDescribe != null) {
            String objectName = objectDescribe.getName();
            ClusterAccessCheck.checkReadPermission(Schema.SObjectType.ClusterModel__c);
            ClusterAccessCheck.checkReadPermission(Schema.SObjectType.ClusterJob__c);
            uiModel.models = new List<ClusterModelWrapper>();
            if (objectDescribe.getSObjectType() == ClusterModel__c.getSObjectType()) {
                ClusterModelWrapper model = ClusterModelBuilderController.loadModel(recordId);
                uiModel.models.add(model);
                uiModel.jobId = getLastCompletedJobId(model.modelId);
                if (uiModel.jobId == null) {
                    throw new ClusterException('This model doesn\'t have any completed jobs. Run this model first to use predict functionality');
                }
                uiModel.recordIdNeeded = true;
            }
            else if (objectDescribe.getSObjectType() == ClusterJob__c.getSObjectType()) {
                List<ClusterJob__c> jobs = [SELECT Id,ClusterModel__c FROM ClusterJob__c WHERE Id = :recordId AND JobStatus__c = :ClusterConstants.JOBSTATUS_COMPLETED  
                    WITH SECURITY_ENFORCED ORDER BY CreatedDate DESC LIMIT 1];
                if (jobs.size() == 1) {
                    uiModel.jobId = jobs[0].Id;
                    uiModel.models.add(ClusterModelBuilderController.loadModel(jobs[0].ClusterModel__c));
                }
                else {
                    throw new ClusterException('This job is not completed. Predict can only be used on completed jobs');
                }
                uiModel.recordIdNeeded = true;
            }
            else {
                List<ClusterModel__c> modelList = [SELECT Id, Name, Object__c, Algorithm__c, Filter__c, Parameters__c, SOQL__c , isCustomSoql__c, Description__c, NumberOfClusters__c 
                    FROM ClusterModel__c WHERE Object__c = :objectName WITH SECURITY_ENFORCED ORDER BY Object__c, Name];                
                
                for (ClusterModel__c model:modelList) {
                    ClusterModelWrapper modelWrapper = new ClusterModelWrapper(model);
                    uiModel.models.add(modelWrapper);
                }
                if (modelList.size() == 1) {
                    Id modelId = modelList[0].Id;
                    uiModel.jobId = getLastCompletedJobId(modelId);
                }
                uiModel.recordIdNeeded = false;
            }
            if (uiModel.models.size() > 0) {
                Schema.DescribeSObjectResult modelObjectDesc = ClusterUtils.findObjectDescByName(uiModel.models[0].objectName);
                if (modelObjectDesc != null) {
                    uiModel.modelObjectLabel = modelObjectDesc.getLabel();
                }
            }
        }
        return uiModel;
    }

    @AuraEnabled(Cacheable=true)
    public static List<ClusterLookupSearchResult> search(String searchTerm, List<String> selectedIds, Id jobOrModelId) {
        Id recordId;
        try {
            recordId = Id.valueOf(searchTerm);
        }
        catch (Exception ex) {
            recordId = null;
        }
        List<ClusterLookupSearchResult> results = new List<ClusterLookupSearchResult>();
        String keyCode = String.valueOf(jobOrModelId).subString(0,3);
        Schema.DescribeSObjectResult objectDescribe = ClusterUtils.findObjectDescByKeyCode(keyCode);
        if (objectDescribe != null) {
            String objectName = objectDescribe.getName();
            ClusterAccessCheck.checkReadPermission(Schema.SObjectType.ClusterModel__c);
            ClusterAccessCheck.checkReadPermission(Schema.SObjectType.ClusterJob__c);
            ClusterModelWrapper model;
            if (objectDescribe.getSObjectType() == ClusterModel__c.getSObjectType()) {
                model = ClusterModelBuilderController.loadModel(jobOrModelId);
            }
            else if (objectDescribe.getSObjectType() == ClusterJob__c.getSObjectType()) {
                List<ClusterJob__c> jobs = [SELECT Id,ClusterModel__c FROM ClusterJob__c WHERE Id = :jobOrModelId AND JobStatus__c = :ClusterConstants.JOBSTATUS_COMPLETED  
                    WITH SECURITY_ENFORCED ORDER BY CreatedDate DESC LIMIT 1];
                if (jobs.size() == 1) {
                    model = ClusterModelBuilderController.loadModel(jobs.get(0).ClusterModel__c);
                }
                else {
                    throw new ClusterException('This job is not completed. Predict can only be used on completed jobs');
                }
            }
            else {
                throw new ClusterException('Invalid model id passed: ' + jobOrModelId);
            }
            log.debug('Loaded model ' + model.name);
            List<String> accessErrors = ClusterAccessCheck.checkModelObjectAccessPermissions(model);
            if (accessErrors.size() > 0) {                
                throw new ClusterException('Cannot access model object: ' + String.join(accessErrors, '; '));
            }
            Schema.DescribeSObjectResult modelObjectDescribe = ClusterUtils.findObjectDescByName(model.objectName);
            String nameField = null;
            for (Schema.SObjectField field:modelObjectDescribe.fields.getMap().values()) {
                schema.DescribeFieldResult fieldDesc = field.getDescribe();
                if (fieldDesc.isNameField()) {
                    nameField = fieldDesc.getName();
                }
            }
            List<SObject> resultList;
            if (recordId != null) {
                String soqlQuery = 'SELECT Id';
                if (nameField != null) {
                    soqlQuery += ',' + nameField;
                }
                else {
                    nameField = 'Id';
                }
                soqlQuery += ' FROM ' + String.escapeSingleQuotes(model.objectName) + ' WHERE Id=\'' + String.valueOf(recordId) + '\'';
                log.debug('Executing search query: ' + soqlQuery);
                resultList = Database.query(soqlQuery);
            }
            else {
                String soslReturning = model.objectName + '(';
                if (nameField == null) {
                    soslReturning += 'Id)';
                    nameField = 'Id';
                }
                else {
                    soslReturning += 'Id,' + nameField + ')';
                }
                searchTerm = ClusterUtils.escapeSosl(searchTerm) + '*';
                String searchQuery='FIND\''+ searchTerm + '\'IN ALL FIELDS RETURNING ' + soslReturning + ' LIMIT ' + String.valueOf(SOSL_SEARCH_LIMIT);
                log.debug('Executing search query: ' + searchQuery);
                List<List<SObject>> searchList = search.query(searchQuery);
                resultList = searchList[0];
            }

            // Extract records & convert them into LookupSearchResult
            String objectIcon = ClusterUtils.getObjectIconName(model.objectName);
            for (SObject resultObject : resultList) {
                results.add(
                    new ClusterLookupSearchResult(
                        (Id)resultObject.get('Id'),
                        model.objectName,
                        objectIcon,
                        String.valueOf(resultObject.get(nameField)),
                        model.objectName
                    )
                );
            }
        }
        return results;
    }

    @AuraEnabled
    public static ClusterPredictUiModel.PredictJobCluster predict(Id recordId, Id jobOrModelId) {
        log.debug('Running prediction for record ' + recordId + ', jobOrModelId ' + jobOrModelId);
        Id jobId = getJobId(jobOrModelId);
        ClusterAlgorithmRunner runner = ClusterAlgorithmFactory.getRunnerFromJobId(jobId);
        ClusterDataPoint dataPoint = runner.getDataPoint(recordId);
        log.debug('Loaded datapoint: ' + JSON.serialize(dataPoint));
        Integer clusterIndex = runner.predict(dataPoint);
        ClusterJobCluster__c cluster = runner.getJobState().jobClusters[clusterIndex];
        ClusterPredictUiModel.PredictJobCluster predictCluster = new ClusterPredictUiModel.PredictJobCluster();
        predictCluster.clusterId = cluster.Id;
        predictCluster.clusterName = cluster.ClusterName__c;
        predictCluster.clusterNumber = cluster.ClusterNumber__c;
        predictCluster.clusterIndex = clusterIndex;
        predictCluster.dataPoint = dataPoint;
        predictCluster.jobState = ClusterJobManager.loadJobState(jobId);
        String[] clusterColors = ClusterConstants.getDefaultClusterColors();
        predictCluster.clusterColor = clusterColors[clusterIndex];
        return predictCluster;
    }

    @AuraEnabled
    public static List<ClusterDataPointNeighbor> findNearestNeighbors(Id recordId, Id jobOrModelId, Integer numNeighbors) {
        log.debug('Finding nearest neighbors for record ' + recordId + ', jobOrModelId ' + jobOrModelId);
        ClusterAccessCheck.checkCRUDPermission(Schema.SObjectType.ClusterJobNeighbor__c);
        Id jobId = getJobId(jobOrModelId);
        List<ClusterDataPointNeighbor> nearestNeighbors = null;
        List<ClusterJobNeighbor__c> neighbors = [SELECT Id, ClusterJob__c, ClusterJobResult__c, Distance__c, NeighborRecordId__c, RecordId__c 
            FROM ClusterJobNeighbor__c WHERE RecordId__c = :String.valueOf(recordId) AND ClusterJob__c = :jobId WITH SECURITY_ENFORCED];
        if (neighbors.size() > 0) {
            log.debug('Retrieved ' + neighbors.size() + ' previously calculated neighbors');
            nearestNeighbors = new List<ClusterDataPointNeighbor>();
            for (ClusterJobNeighbor__c neighbor:neighbors) {
                nearestNeighbors.add(new ClusterDataPointNeighbor(neighbor));
            }
        }
        else {
            log.debug('Previous calculations were not found. Starting nearest neighbor calculations async');
            findNearestNeighborsAsync(recordId, jobId, numNeighbors);
        }
        return nearestNeighbors;
    }

    @AuraEnabled
    public static List<ClusterDataPointNeighbor> pullNearestNeighbors(Id recordId, Id jobOrModelId, Integer numNeighbors) {
        log.debug('Pulling nearest neighbors for record ' + recordId + ', jobOrModelId ' + jobOrModelId);
        ClusterAccessCheck.checkCRUDPermission(Schema.SObjectType.ClusterJobNeighbor__c);
        Id jobId = getJobId(jobOrModelId);
        List<ClusterDataPointNeighbor> nearestNeighbors = null;
        List<ClusterJobNeighbor__c> neighbors = [SELECT Id, ClusterJob__c, ClusterJobResult__c, Distance__c, NeighborRecordId__c, RecordId__c 
            FROM ClusterJobNeighbor__c WHERE RecordId__c = :String.valueOf(recordId) AND ClusterJob__c = :jobId WITH SECURITY_ENFORCED];
        if (neighbors.size() > 0) {
            log.debug('Retrieved ' + neighbors.size() + ' previously calculated neighbors');
            nearestNeighbors = new List<ClusterDataPointNeighbor>();
            for (ClusterJobNeighbor__c neighbor:neighbors) {
                nearestNeighbors.add(new ClusterDataPointNeighbor(neighbor));
            }
        }
        else {
            log.debug('Previous calculations were not completed');
        }
        return nearestNeighbors;
    }

    @future
    public static void findNearestNeighborsAsync(Id recordId, Id jobId, Integer numNeighbors) {
        ClusterAccessCheck.checkCRUDPermission(Schema.SObjectType.ClusterJobNeighbor__c);
        ClusterAlgorithmRunner runner = ClusterAlgorithmFactory.getRunnerFromJobId(jobId);
        List<ClusterNeighbor> clusterNeighbors = runner.findNearestClusters(recordId, 3);
        List<Integer> nearestClusters = new List<Integer>();
        for (ClusterNeighbor cn:clusterNeighbors) {
            nearestClusters.add(cn.clusterIndex);
        }
        List<ClusterDataPointNeighbor> neighbors = runner.findNearestNeighbors(recordId, nearestClusters, numNeighbors);
        List<ClusterJobNeighbor__c> neighborRecords = new List<ClusterJobNeighbor__c>();
        for (ClusterDataPointNeighbor neighbor:neighbors) {
            ClusterJobNeighbor__c neighborRecord = new ClusterJobNeighbor__c();
            neighbor.populateNeighborRecord(neighborRecord);
        }
        insert neighborRecords;
    }

    private static Id getJobId(Id jobOrModelId) {
        Schema.DescribeSObjectResult modelDesc = ClusterModel__c.SObjectType.getDescribe();
        Schema.DescribeSObjectResult jobDesc = ClusterJob__c.SObjectType.getDescribe();
        String keyCode  = String.valueOf(jobOrModelId).subString(0,3);
        Id jobId;
        if (keyCode == modelDesc.getKeyPrefix()) {
            jobId = getLastCompletedJobId(jobOrModelId);
        }
        else if (keyCode == jobDesc.getKeyPrefix()) {
            jobId = jobOrModelId;
        }
        else {
            throw new ClusterException('Incorrect cluster job id ' + jobOrModelId);
        }
        return jobId;
    }

    public static Id getLastCompletedJobId(Id modelId){
        ClusterAccessCheck.checkReadPermission(Schema.SObjectType.ClusterJob__c);
        String jobState = null;
        List<ClusterJob__c> jobs = [SELECT Id FROM ClusterJob__c WHERE JobStatus__c = :ClusterConstants.JOBSTATUS_COMPLETED AND ClusterModel__c = :modelId 
            WITH SECURITY_ENFORCED ORDER BY CreatedDate DESC LIMIT 1];
        if (jobs.size() == 1) {
            return jobs.get(0).Id;
        }
        return null;
    }
    
}
