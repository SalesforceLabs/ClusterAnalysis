public with sharing class ClusterPredictController {
    @AuraEnabled    
    public static ClusterPredictUiModel getPredictUiModel(Id recordId) {
        String keyCode  = String.valueOf(recordId).subString(0,3);
        String objectName = null;
        Schema.DescribeSObjectResult objectDescribe = null;
        ClusterPredictUiModel uiModel = new ClusterPredictUiModel();

        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();
        for (Schema.SObjectType objectInstance : gd.values())
        {
            objectDescribe = objectInstance.getDescribe();
            if(objectDescribe.getKeyPrefix() == keyCode)
            {
                objectName = objectDescribe.getName();                
                break;
            }
        }
        if (objectName != null) {
            ClusterAccessCheck.checkReadPermission(Schema.SObjectType.ClusterModel__c);
            ClusterAccessCheck.checkReadPermission(Schema.SObjectType.ClusterJob__c);
            uiModel.models = new List<ClusterModelWrapper>();
            if (objectDescribe.getSObjectType() == ClusterModel__c.getSObjectType()) {
                ClusterModelWrapper model = ClusterModelBuilderController.loadModel(recordId);
                uiModel.models.add(model);
                uiModel.jobState = getModelJobState(model.modelId);
                if (uiModel.jobState == null) {
                    throw new ClusterException('This model doesn\'t have any completed jobs. Run this model first to use predict functionality');
                }
                uiModel.recordIdNeeded = true;
            }
            else if (objectDescribe.getSObjectType() == ClusterJob__c.getSObjectType()) {
                List<ClusterJob__c> jobs = [SELECT Id,ClusterModel__c FROM ClusterJob__c WHERE Id = :recordId AND JobStatus__c = :ClusterConstants.JOBSTATUS_COMPLETED  
                    WITH SECURITY_ENFORCED ORDER BY CreatedDate DESC LIMIT 1];
                if (jobs.size() == 1) {
                    uiModel.jobState = ClusterJobManager.loadJobState(jobs[0].Id);
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
                    uiModel.jobState = getModelJobState(modelId);
                }
                uiModel.recordIdNeeded = false;
            }
        }
        return uiModel;
    }

    @AuraEnabled
    public static string getModelJobState(Id modelId){
        ClusterAccessCheck.checkReadPermission(Schema.SObjectType.ClusterJob__c);
        String jobState = null;
        List<ClusterJob__c> jobs = [SELECT Id FROM ClusterJob__c WHERE JobStatus__c = :ClusterConstants.JOBSTATUS_COMPLETED AND ClusterModel__c = :modelId 
            WITH SECURITY_ENFORCED ORDER BY CreatedDate DESC LIMIT 1];
        if (jobs.size() == 1) {
            jobState = ClusterJobManager.loadJobState(jobs[0].Id);
        }
        return jobState;
    }
}
