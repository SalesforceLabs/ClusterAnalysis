/*
 * UI model for job details lightning component
 *
 * @author: Iskander Mukhamedgaliyev
 */
public with sharing class ClusterJobDetailsUiModel {
    public class ClusterJobCluster {
        @AuraEnabled
        public Id clusterId;
        @AuraEnabled
        public String clusterNumber;
        @AuraEnabled
        public String clusterName;
        @AuraEnabled
        public Integer recordCount;
    }
    public ClusterJobDetailsUiModel() {

    }

    public ClusterJobDetailsUiModel(ClusterJob__c clusterJob) {
        this.jobId = clusterJob.Id;
        this.name = clusterJob.Name;
        this.objectName = clusterJob.ObjectName__c;
        this.status = clusterJob.JobStatus__c;
        this.startDate = clusterJob.StartDate__c == null ? '' : clusterJob.StartDate__c.format();
        this.endDate = clusterJob.EndDate__c == null ? '' : clusterJob.EndDate__c.format();
        this.clusters = new List<ClusterJobCluster>();
        this.statusText = clusterJob.JobStatusText__c;        
        this.numberOfClusters = Integer.valueOf(clusterJob.NumberOfClusters__c);
        this.createdById = clusterJob.CreatedById;
        this.createdByName = clusterJob.CreatedBy.Name + ', ' + clusterJob.CreatedDate.format();
        this.jobName = clusterJob.JobName__c;
        this.score = clusterJob.Score__c;
        for (ClusterJobCluster__c jobCluster:clusterJob.JobClusters__r) {
            ClusterJobCluster clusterWrapper = new ClusterJobCluster();
            clusterWrapper.clusterId = jobCluster.Id;
            clusterWrapper.clusterName = jobCluster.ClusterName__c;
            if (clusterWrapper.clusterName == null) clusterWrapper.clusterName = 'Cluster ' + jobCluster.ClusterNumber__c;
            clusterWrapper.clusterNumber = jobCluster.ClusterNumber__c;
            this.clusters.add(clusterWrapper);
        }
    }

    @AuraEnabled
    public Id jobId;
    @AuraEnabled
    public Id createdById;
    @AuraEnabled
    public String createdByName;
    @AuraEnabled
    public String name;
    @AuraEnabled
    public String jobName;
    @AuraEnabled
    public String objectName;
    @AuraEnabled
    public String status;
    @AuraEnabled
    public String statusText;
    @AuraEnabled
    public String jobStateString;
    @AuraEnabled
    public String startDate;
    @AuraEnabled
    public String endDate;
    @AuraEnabled
    public Integer numberOfClusters;
    @AuraEnabled
    public ClusterModelWrapper model;
    @AuraEnabled
    public Integer numberOfRecords;
    @AuraEnabled
    public Double score;
    @AuraEnabled
    public Integer maxGraphDataPoints;
    @AuraEnabled
    public List<ClusterJobCluster> clusters;
    @AuraEnabled
    public String[] clusterColors;
}