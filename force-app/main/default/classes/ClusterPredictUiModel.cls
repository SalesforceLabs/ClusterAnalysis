public with sharing class ClusterPredictUiModel {
    public class PredictJobCluster {
        @AuraEnabled
        public Id clusterId;
        @AuraEnabled
        public String clusterNumber;
        @AuraEnabled
        public String clusterName;
        @AuraEnabled
        public Integer clusterIndex;
        @AuraEnabled
        public ClusterDataPoint dataPoint;
        @AuraEnabled
        public String jobState;
    }
    public ClusterPredictUiModel() {
        models = new List<ClusterModelWrapper>();
    }
    @AuraEnabled
    public List<ClusterModelWrapper> models;    
    @AuraEnabled
    public Id jobId;
    @AuraEnabled
    public ClusterDataPoint dataPoint;
    @AuraEnabled
    public Boolean recordIdNeeded;

}
