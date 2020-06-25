/*
 * Controller for job details lightning component
 *
 * @author: Iskander Mukhamedgaliyev
 */
public with sharing class ClusterJobDetailsController {

    @AuraEnabled
    public static ClusterJobDetailsUiModel getJob(Id jobId) {
        ClusterAccessCheck.checkReadPermission(Schema.SObjectType.ClusterJob__c);
        //isAccessible permission is checked in ClusterAccessCheck.checkReadPermission above, exception is thrown in case of no access
        ClusterJob__c job = [SELECT Id, Name, JobName__c, ClusterModel__c, JobStatus__c,JobStatusText__c,ObjectName__c,StartDate__c,EndDate__c,NumberOfClusters__c,
                CreatedById, CreatedBy.Name, Score__c, CreatedDate,
                (SELECT Id, ClusterName__c, ClusterNumber__c FROM JobClusters__r ORDER BY ClusterNumber__c)
                FROM ClusterJob__c WHERE Id = :jobId];
        ClusterJobDetailsUiModel jobModel = new ClusterJobDetailsUiModel(job);
        jobModel.jobStateString = ClusterJobManager.loadJobState(jobId);
        jobModel.model = ClusterModelBuilderController.loadModel(job.ClusterModel__c);
        if (jobModel.status == ClusterConstants.JOBSTATUS_COMPLETED) {
            jobModel.numberOfRecords = 0;
            //isAccessible permission is checked in ClusterAccessCheck.checkReadPermission above, exception is thrown in case of no access
            List<AggregateResult> arList = [SELECT Cluster__c clusterId, count(Id) recordCount FROM ClusterJobResult__c WHERE ClusterJob__c=:jobId GROUP BY Cluster__c];
            Map<String, ClusterJobDetailsUiModel.ClusterJobCluster> clusters = new Map<String, ClusterJobDetailsUiModel.ClusterJobCluster>();
            for (ClusterJobDetailsUiModel.ClusterJobCluster cluster:jobModel.clusters) {
                clusters.put(String.valueOf(cluster.clusterId), cluster);
            }
            for (AggregateResult ar:arList) {
                ClusterJobDetailsUiModel.ClusterJobCluster cluster = clusters.get(String.valueOf(ar.get('clusterId')));
                if (cluster != null) {
                    cluster.recordCount = Integer.valueOf(ar.get('recordCount'));
                    jobModel.numberOfRecords += cluster.recordCount;
                }
            }
        }
        jobModel.maxGraphDataPoints = ClusterConstants.getTSNEPlotLimit();
        return jobModel;
    }

    public static ClusterDataPoint[] getDataPoints(Id jobId, Integer maxCount, Integer offset) {
        Integer count = ClusterConstants.getTSNEPlotLimit();
        if (offset > count) {
            return new List<ClusterDataPoint>();
        }
        if (offset + maxCount > count) {
            count = count - offset;
        }
        else {
            count = maxCount;
        }
        ClusterAccessCheck.checkReadPermission(Schema.SObjectType.ClusterJobResult__c);
        //isAccessible permission is checked in ClusterAccessCheck.checkReadPermission above, exception is thrown in case of no access
        List<ClusterJobResult__c> randomRecords = [SELECT Id, Cluster__c, Json__c, RecordId__c, RecordName__c, ClusterNumber__c, ClusterJob__c 
            FROM ClusterJobResult__c WHERE ClusterJob__c = :jobId WITH SECURITY_ENFORCED ORDER BY Random__c LIMIT :count OFFSET :offset];
        List<ClusterDataPoint> dataPoints = new List<ClusterDataPoint>();
        for (ClusterJobResult__c record:randomRecords) {
            ClusterDataPoint dp = new ClusterDataPoint(record, null);
            //We will parse json in javascript to save apex CPU time
            dp.valuesJson = record.Json__c;
            dataPoints.add(dp);
        }
        return dataPoints; 
    }

    @AuraEnabled
    public static String getDataPointsJson(Id jobId, Integer maxCount, Integer offset) {
        //We will load data points in batches to avoid heap size issues
        List<ClusterDataPoint> dataPoints = getDataPoints(jobId, maxCount, offset);
        //There is a weird bug with @AuraEnabled and Object[] json deserialization - it skips null items
        //So we will serialize manually here and deserialize in javascript controller until that is fixed
        //This is bad and consumes apex memory, but fixes the problem for now
        return JSON.serialize(dataPoints); 
    }

    @AuraEnabled
    public static ClusterJobDetailsUiModel cancelJob(Id jobId) {
        ClusterAccessCheck.checkCRUDPermission(Schema.SObjectType.ClusterJob__c);
        //CRUD permissions are checked in ClusterAccessCheck.checkCRUDPermission above, exception is thrown in case of no access
        ClusterJob__c job = [SELECT Id, Name, JobName__c, ClusterModel__c, JobStatus__c,JobStatusText__c,ObjectName__c,StartDate__c,EndDate__c,NumberOfClusters__c,
                CreatedById, CreatedBy.Name, Score__c FROM ClusterJob__c WHERE Id = :jobId];
        if (job.JobStatus__c == ClusterConstants.JOBSTATUS_NEW || job.JobStatus__c == ClusterConstants.JOBSTATUS_IN_PROGRESS) {
            job.JobStatus__c = ClusterConstants.JOBSTATUS_MARKED_FOR_CANCEL;
            job.JobStatusText__c = 'User requested to cancel this job';
            update job;
        }
        return getJob(jobId);
    }

    @AuraEnabled
    public static ClusterJobDetailsUiModel setJobName(Id jobId, String jobName) {
        ClusterAccessCheck.checkCRUDPermission(Schema.SObjectType.ClusterJob__c);
        //CRUD permissions are checked in ClusterAccessCheck.checkCRUDPermission above, exception is thrown in case of no access
        ClusterJob__c job = [SELECT Id, Name, JobName__c, ClusterModel__c, JobStatus__c,JobStatusText__c,ObjectName__c,StartDate__c,EndDate__c,NumberOfClusters__c,
                CreatedById, CreatedBy.Name, Score__c FROM ClusterJob__c WHERE Id = :jobId];
        job.JobName__c = jobName;
        update job;
        return getJob(jobId);     
    }

    @AuraEnabled
    public static ClusterResultDetailsUiModel getJobResultModel(Id jobResultId){
        ClusterAccessCheck.checkReadPermission(Schema.SObjectType.ClusterJobResult__c);
        List<ClusterJobResult__c> results = [SELECT Id, Name, Cluster__c, Cluster__r.ClusterName__c, Json__c, RecordId__c, RecordName__c, ClusterNumber__c, ClusterJob__c 
            FROM ClusterJobResult__c WHERE Id = :jobResultId WITH SECURITY_ENFORCED];
        
        ClusterJobResult__c result = results.get(0);
        ClusterJob__c job = ClusterJobManager.getJob(result.ClusterJob__c);
        
        ClusterJobState jobState = new ClusterJobState();
        jobState.model = ClusterModelBuilderController.loadModel(job.ClusterModel__c);

        ClusterSObjectProcessor objectProcessor = new ClusterSObjectProcessor(jobState);
        ClusterDataPoint dp = new ClusterDataPoint(result, objectProcessor);

        ClusterResultDetailsUiModel uiModel = new ClusterResultDetailsUiModel();
        uiModel.jobId = job.Id;
        uiModel.jobName = job.JobName__c;
        uiModel.jobStateString = ClusterJobManager.loadJobState(job.Id);
        uiModel.dataPoint = dp;
        uiModel.resultName = result.Name;
        uiModel.clusterId = result.Cluster__c;
        if (result.Cluster__r != null) {
            uiModel.clusterName = result.Cluster__r.ClusterName__c;
        }
        return uiModel; 
    }
}
