/*
 * UI model for Cluster result details
 *
 * @author: Iskander Mukhamedgaliyev
 */
public with sharing class ClusterResultDetailsUiModel {
    public ClusterResultDetailsUiModel() {

    }
    @AuraEnabled
    public String jobStateString;
    @AuraEnabled
    public ClusterDataPoint dataPoint;
    @AuraEnabled
    public String resultName;
    @AuraEnabled
    public Id jobId;
    @AuraEnabled
    public String jobName;
    @AuraEnabled
    public Id clusterId;
    @AuraEnabled
    public String clusterName;
}
