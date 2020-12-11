/*
 * Models for clusterPredict and clusterPredictResult (LWC)
 *
 * @author: Iskander Mukhamedgaliyev
 */
public with sharing class ClusterPredictUiModel {
    public class PredictResultModel {
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
        @AuraEnabled
        public String clusterColor;
        @AuraEnabled
        public ClusterPredictionResult predictionResult;
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
    @AuraEnabled
    public String modelObjectLabel;

}
