public with sharing class ClusterPredictUiModel {
    public ClusterPredictUiModel() {
        models = new List<ClusterModelWrapper>();
    }
    @AuraEnabled
    public List<ClusterModelWrapper> models;    
    @AuraEnabled
    public String jobState;
    @AuraEnabled
    public ClusterDataPoint dataPoint;
    @AuraEnabled
    public Boolean recordIdNeeded;

}
