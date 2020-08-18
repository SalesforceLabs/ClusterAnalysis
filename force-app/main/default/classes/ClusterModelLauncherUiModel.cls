public with sharing class ClusterModelLauncherUiModel {
    public ClusterModelLauncherUiModel() {

    }
    @AuraEnabled
    public ClusterModelWrapper model;
    @AuraEnabled
    public ClusterAlgorithmParameter[] parameters;

}