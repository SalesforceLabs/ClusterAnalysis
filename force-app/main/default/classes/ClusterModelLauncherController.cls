public with sharing class ClusterModelLauncherController {
    public static Logger log = LogFactory.getLogger();

    @AuraEnabled
    public static ClusterModelLauncherUiModel loadModel(Id modelId) {
        ClusterModelLauncherUiModel uiModel = new ClusterModelLauncherUiModel();
        uiModel.model = ClusterModelBuilderController.loadModel(modelId);
        ClusterAlgorithmRunner runner = ClusterAlgorithmFactory.getRunner(uiModel.model);
        uiModel.parameters = runner.getParameters(uiModel.model);
        return uiModel;
    }

    @AuraEnabled
    public static string runModel(Id modelId, Map<String, Object> parameters){
        //TODO: consider runModel as a global api method in future versions
        ClusterModelWrapper model = ClusterModelBuilderController.loadModel(modelId);
        log.debug('Starting cluster model ' + model.name + ' with parameters ' + parameters);
        ClusterAlgorithmRunner runner = ClusterAlgorithmFactory.getRunner(model);
        model.parameters = parameters;
        //We will validate model and permissions one time here
        ClusterAlgorithmRunner.ModelValidationResult vr = runner.validateModel(model);
        if (!vr.isValid) {
            ClusterException ex = new ClusterException();
            ex.setMessage('Model validation failed. Error message(s): ' + String.join(vr.messages,'\n'));
            log.error(ex.getMessage(), ex);
            throw ex;
        }
        runner.init(model);
        runner.start();
        ClusterJobState state = runner.getJobState();
        return state.clusterJob.Id;
    }

    @AuraEnabled
    public static ClusterJobRunnerUiModel getModels(){
        ClusterAccessCheck.checkReadPermission(Schema.SObjectType.ClusterModel__c);
        List<ClusterModel__c> modelList = [SELECT Id, Name, Object__c, Algorithm__c, Filter__c, Parameters__c, SOQL__c , isCustomSoql__c, Description__c, NumberOfClusters__c 
            FROM ClusterModel__c WITH SECURITY_ENFORCED ORDER BY Object__c, Name];
        ClusterJobRunnerUiModel uiModel = new ClusterJobRunnerUiModel();
        uiModel.models = new List<ClusterModelWrapper>();
        for (ClusterModel__c model:modelList) {
            ClusterModelWrapper modelWrapper = new ClusterModelWrapper(model);
            uiModel.models.add(modelWrapper);
        }
        uiModel.parameters = new Map<String, List<ClusterAlgorithmParameter>>();
        for (UiSelectOption algorithm : ClusterAlgorithmFactory.getAlgorithmList()) {
            uiModel.parameters.put(algorithm.value, ClusterAlgorithmFactory.getRunner(algorithm.value).getParameters(null));
        }
        return uiModel;
    }
}
