/*
 * Controller for clusterPredict and clusterPredictResult (LWC)
 *
 * @author: Iskander Mukhamedgaliyev
 */
public with sharing class ClusterPredictController {
    public class ClusterModelJob {
        public ClusterModelWrapper model;
        public Id jobId;
    }

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
    public static ClusterPredictUiModel.PredictResultModel predict(Id recordId, String jobOrModel, Boolean isPolling) {
        log.debug('Running prediction for record: ' + recordId + ', jobOrModel: ' + jobOrModel);
        ClusterModelJob modelJob = getModelJob(jobOrModel);
        Id jobId = modelJob.jobId;
        ClusterAlgorithmRunner runner = ClusterAlgorithmFactory.getRunnerFromJobId(jobId);
        //Checking if nearest neighbors were calculated previously
        Integer nCount = [SELECT COUNT() FROM ClusterJobNeighbor__c WHERE RecordId__c = :String.valueOf(recordId) AND ClusterJob__c = :jobId WITH SECURITY_ENFORCED LIMIT 1];
        ClusterPredictUiModel.PredictResultModel predictResult = new ClusterPredictUiModel.PredictResultModel();
        predictResult.clusterIndex = -1;
        predictResult.predictionResult = null;
        //If yes or if in test mode - run prediction
        if (nCount == 1 || (Test.isRunningTest() && !isPolling)) {            
            //TODO: getDataPoint is very expensive for the sync mode
            //we should save the source data point as job result in async mode and use load
            ClusterDataPoint dataPoint = runner.getDataPoint(recordId); 
            ClusterPredictionResult predictionResult = runner.predict(dataPoint);
            Integer clusterIndex = predictionResult.clusterIndex;
            ClusterJobCluster__c cluster = runner.getJobState().jobClusters[clusterIndex];
            predictResult.clusterId = cluster.Id;
            predictResult.clusterName = cluster.ClusterName__c;
            predictResult.clusterNumber = cluster.ClusterNumber__c;
            predictResult.clusterIndex = clusterIndex;
            predictResult.dataPoint = dataPoint;
            predictResult.predictionResult = predictionResult;
            predictResult.jobState = ClusterJobManager.loadJobState(jobId);
            String[] clusterColors = ClusterConstants.getDefaultClusterColors();
            predictResult.clusterColor = clusterColors[clusterIndex];
        }
        else if (!isPolling) {
            //If no and not polling - let's find nearest neighbors first
            log.debug('Previous calculations were not found. Starting nearest neighbor calculations');
            findNearestNeighborsAsync(recordId, jobId, ClusterConstants.MAX_NEIGHBORS);
        }
        return predictResult;
    }

    @AuraEnabled
    public static ClusterPredictKNNUiModel getNearestNeighbors(Id recordId, String jobOrModel, Integer numNeighbors) {
        ClusterModelJob modelJob = getModelJob(jobOrModel);
        Id jobId = modelJob.jobId;
        log.debug('Finding nearest neighbors for record ' + recordId + ', jobId ' + jobId);
        ClusterAccessCheck.checkCRUDPermission(Schema.SObjectType.ClusterJobNeighbor__c);
        ClusterPredictKNNUiModel uiModel = new ClusterPredictKNNUiModel();
        ClusterAlgorithmRunner runner = ClusterAlgorithmFactory.getRunnerFromJobId(jobId);
        ClusterKMeansJobState jobState = (ClusterKMeansJobState)runner.getJobState();
        List<ClusterDataPointNeighbor> nearestNeighbors = null;
        if (recordId != null) {
            nearestNeighbors = runner.getNearestNeighborsFromDb(recordId, jobId, numNeighbors);
            if (nearestNeighbors == null || nearestNeighbors.size() == 0) {
                log.debug('Previous calculations were not found. Starting nearest neighbor calculations');
                if (Test.isRunningTest()) {
                    //Use sync call in test mode                
                    nearestNeighbors = findNearestNeighbors(recordId, jobId, numNeighbors);
                }
                else {
                    findNearestNeighborsAsync(recordId, jobId, numNeighbors);
                }
            }
            else {
                log.debug('Retrieved ' + nearestNeighbors.size() + ' nearest neighbors from db for ' + recordId + ', jobId ' + jobId);
                uiModel.jobState = ClusterJobManager.loadJobState(jobId);
                uiModel.clusterColors = ClusterConstants.getDefaultClusterColors();
            }
        }
        uiModel.jobId = modelJob.jobId;
        uiModel.model = modelJob.model;
        uiModel.nearestNeighbors = nearestNeighbors;
        Schema.DescribeSObjectResult modelObjectDesc = ClusterUtils.findObjectDescByName(uiModel.model.objectName);
        if (modelObjectDesc != null) {
            uiModel.modelObjectLabel = modelObjectDesc.getLabel();
        }
        return uiModel;
    }

    @AuraEnabled
    public static ClusterPredictKNNUiModel pullNearestNeighbors(Id recordId, String jobOrModel, Integer numNeighbors) {
        ClusterModelJob modelJob = getModelJob(jobOrModel);
        Id jobId = modelJob.jobId;
        log.debug('Pulling nearest neighbors for record ' + recordId + ', jobId ' + jobId);
        ClusterAccessCheck.checkCRUDPermission(Schema.SObjectType.ClusterJobNeighbor__c);
        ClusterPredictKNNUiModel uiModel = new ClusterPredictKNNUiModel();
        ClusterAlgorithmRunner runner = ClusterAlgorithmFactory.getRunnerFromJobId(jobId);
        List<ClusterDataPointNeighbor> nearestNeighbors = runner.getNearestNeighborsFromDb(recordId, jobId, numNeighbors);
        if (nearestNeighbors == null || nearestNeighbors.size() == 0) {
            log.debug('Previous calculations were not completed');
        }
        else {
            log.debug('Retrieved ' + nearestNeighbors.size() + ' nearest neighbors from db for ' + recordId + ', jobId ' + jobId);
            //uiModel.dataPoint = runner.getDataPoint(recordId);
            uiModel.jobState = ClusterJobManager.loadJobState(jobId);
            uiModel.clusterColors = ClusterConstants.getDefaultClusterColors();
        }
        uiModel.nearestNeighbors = nearestNeighbors;
        uiModel.jobId = modelJob.jobId;
        uiModel.model = modelJob.model;
        Schema.DescribeSObjectResult modelObjectDesc = ClusterUtils.findObjectDescByName(uiModel.model.objectName);
        if (modelObjectDesc != null) {
            uiModel.modelObjectLabel = modelObjectDesc.getLabel();
        }
        return uiModel;
    }

    @future
    public static void findNearestNeighborsAsync(Id recordId, Id jobId, Integer numNeighbors) {
        log.debug('Starting @future findNearestNeighborsAsync for record id: ' + recordId);
        findNearestNeighbors(recordId, jobId, numNeighbors);
    }

    public static List<ClusterDataPointNeighbor> findNearestNeighbors(Id recordId, Id jobId, Integer numNeighbors) {
        try {
            log.debug('Starting k nearest neighbor calculations for record id: ' + recordId);
            ClusterAccessCheck.checkCRUDPermission(Schema.SObjectType.ClusterJobNeighbor__c);
            ClusterAlgorithmRunner runner = ClusterAlgorithmFactory.getRunnerFromJobId(jobId);
            List<ClusterDataPointNeighbor> neighbors = runner.findNearestNeighbors(recordId, numNeighbors);
            return neighbors;
        }
        catch (Exception ex) {
            log.error('Error hapenned during nearest neighbor calculations: ', ex);
            throw ex;
        }
    }

    public static ClusterModelJob getModelJob(String jobOrModel) {
        ClusterAccessCheck.checkReadPermission(Schema.SObjectType.ClusterModelField__c);
        Id jobOrModelId;
        ClusterModelJob modelJob = new ClusterModelJob();
        Boolean isjobOrModelId = false;
        try {
            jobOrModelId = Id.valueOf(jobOrModel);
            isjobOrModelId = true;    
        }
        catch (Exception ex) {
            
        }
        if (isjobOrModelId) {
            Schema.DescribeSObjectResult modelDesc = ClusterModel__c.SObjectType.getDescribe();
            Schema.DescribeSObjectResult jobDesc = ClusterJob__c.SObjectType.getDescribe();
            String keyCode  = String.valueOf(jobOrModelId).subString(0,3);
            if (keyCode == modelDesc.getKeyPrefix()) {
                modelJob.model = ClusterModelBuilderController.loadModel(jobOrModelId);
                modelJob.jobId = getLastCompletedJobId(jobOrModelId);
                if (modelJob.jobId == null) {
                    throw new ClusterException('This model doesn\'t have any completed jobs. Run this model first to use predict functionality');
                }
            }
            else if (keyCode == jobDesc.getKeyPrefix()) {
                modelJob.jobId = jobOrModelId;
                List<ClusterJob__c> jobs = [SELECT Id, ClusterModel__c FROM ClusterJob__c WHERE Id = :jobOrModelId AND JobStatus__c = :ClusterConstants.JOBSTATUS_COMPLETED  
                    WITH SECURITY_ENFORCED ORDER BY CreatedDate DESC LIMIT 1];
                if (jobs.size() == 1) {
                    modelJob.model = ClusterModelBuilderController.loadModel(jobs.get(0).ClusterModel__c);
                }
                else {
                    throw new ClusterException('This cluster job is not completed. Run this model first to use predict functionality');
                }            
            }
            else {
                throw new ClusterException('Incorrect cluster job id ' + jobOrModelId);
            }
        }
        else {
            List<ClusterModel__c> models = [SELECT Id, Name, Object__c, Algorithm__c, Filter__c, Parameters__c, SOQL__c , isCustomSoql__c, Description__c, NumberOfClusters__c,
                (SELECT Id, Name, FieldName__c, Model__c, ObjectName__c, DistanceType__c, Weight__c, RelationName__c, Language__c FROM ClusterModelFields__r)
                FROM ClusterModel__c WHERE Name = :jobOrModel WITH SECURITY_ENFORCED];
            if (models.size() == 0) {
                throw new ClusterException('Cannot find model with name ' + jobOrModel);
            }
            modelJob.model = new ClusterModelWrapper(models.get(0));
            modelJob.jobId = getLastCompletedJobId(modelJob.model.modelId);
        }
        return modelJob;
    }

    private static Id getJobId(Id jobOrModelId) {
        Schema.DescribeSObjectResult modelDesc = ClusterModel__c.SObjectType.getDescribe();
        Schema.DescribeSObjectResult jobDesc = ClusterJob__c.SObjectType.getDescribe();
        String keyCode  = String.valueOf(jobOrModelId).subString(0,3);
        Id jobId = null;
        if (keyCode == modelDesc.getKeyPrefix()) {
            jobId = getLastCompletedJobId(jobOrModelId);
            if (jobId == null) {
                throw new ClusterException('This model doesn\'t have any completed jobs. Run this model first to use predict functionality');
            }
        }
        else if (keyCode == jobDesc.getKeyPrefix()) {
            jobId = jobOrModelId;
            Integer jobCount = [SELECT Count() FROM ClusterJob__c WHERE Id = :jobOrModelId AND JobStatus__c = :ClusterConstants.JOBSTATUS_COMPLETED  
                WITH SECURITY_ENFORCED LIMIT 1];
            if (jobCount == 1) {
                jobId = jobOrModelId;
            }
            else {
                throw new ClusterException('This cluster job is not completed. Run this model first to use predict functionality');
            }            
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
