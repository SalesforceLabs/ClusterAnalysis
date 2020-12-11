public with sharing class ClusterPredictKNNUiModel {
    @AuraEnabled
    public Id jobId;
    @AuraEnabled
    public ClusterModelWrapper model;
    @AuraEnabled
    public String modelObjectLabel;
    @AuraEnabled
    public String jobState;
    @AuraEnabled
    public List<ClusterDataPointNeighbor> nearestNeighbors;
    @AuraEnabled
    public String[] clusterColors;
}
