/*
 * CRUD operations for cluster job
 *
 * @author: Iskander Mukhamedgaliyev
 */
public with sharing class ClusterJobManager {
    public static final String JOBSTATENAME = 'JobState';
    public static ClusterJob__c createJob(String jobName, ClusterModelWrapper model) {
        ClusterAccessCheck.checkCreatePermission(Schema.SObjectType.ClusterJob__c);
        ClusterJob__c job = new ClusterJob__c();
        job.ClusterModel__c = model.modelId;
        job.ObjectName__c = model.objectName;
        job.NumberOfClusters__c = model.numberOfClusters;
        job.JobName__c = jobName;
        job.JobStatus__c = ClusterConstants.JOBSTATUS_NEW;
        job.StartDate__c = Datetime.now();
        //Create permission is checked in ClusterAccessCheck.checkCreatePermission, exception is thrown in case of no access
        insert job;
        return job;
    }

    public static List<ClusterJobCluster__c> createJobClusters(ClusterJob__c job){
        ClusterAccessCheck.checkCreatePermission(Schema.SObjectType.ClusterJobCluster__c);
        List<ClusterJobCluster__c> clusters = new List<ClusterJobCluster__c>();
        if ((job.NumberOfClusters__c == null) || (job.NumberOfClusters__c < 1)) {
            return clusters;
        }
        for (Integer i = 0; i<job.NumberOfClusters__c; i++){
            ClusterJobCluster__c cluster = new ClusterJobCluster__c();
            cluster.ClusterJob__c = job.Id;
            cluster.ClusterNumber__c = String.valueOf(i);
            cluster.ClusterName__c = 'Cluster ' + String.valueOf(i);
            clusters.add(cluster);
        }
        //Create permission is checked in ClusterAccessCheck.checkCreatePermission, exception is thrown in case of no access
        insert clusters;        
        return clusters;
    }

    public static ClusterJob__c getJob(Id jobId) {
        ClusterAccessCheck.checkReadPermission(Schema.SObjectType.ClusterJob__c);
        //isAccessible permission is checked in ClusterAccessCheck.checkReadPermission, exception is thrown in case of no access
        return [SELECT Id, JobName__c, ClusterModel__c, NumberOfClusters__c, ObjectName__c, JobStatus__c, JobStatusText__c, StartDate__c, EndDate__c, InternalJobId__c, Score__c 
            FROM ClusterJob__c WHERE Id = :jobId WITH SECURITY_ENFORCED];
    }

    public static List<ClusterJobCluster__c> getJobClusters(Id jobId) {
        List<ClusterJobCluster__c> clusters = [SELECT Id, Name, ClusterJob__c, ClusterNumber__c, ClusterName__c  FROM ClusterJobCluster__c WHERE ClusterJob__c=:jobId WITH SECURITY_ENFORCED];
        return clusters;
    }

    public static void saveJobState(ClusterJobState state, String status, String statusText) {
        //Checking CRUD permissions on ClusterJob__c and Attachment
        ClusterAccessCheck.checkUpdatePermission(Schema.SObjectType.ClusterJob__c);
        ClusterAccessCheck.checkCRUDPermission(Schema.SObjectType.Attachment);
        String jobState = JSON.serialize(state);
        //Check FLS
        Boolean hasFLS = true;
        if (Schema.SObjectType.ClusterJob__c.fields.JobStatus__c.isUpdateable()) {
            state.clusterJob.JobStatus__c = status;
        }
        else {
            hasFLS = false;
        }
        if (Schema.SObjectType.ClusterJob__c.fields.InternalJobId__c.isUpdateable()) {
            state.clusterJob.InternalJobId__c = state.currentJobId;
        } 
        else {
            hasFLS = false;
        }
        if (Schema.SObjectType.ClusterJob__c.fields.JobStatus__c.isUpdateable()) {
            state.clusterJob.JobStatus__c = status;
        }
        else {
            hasFLS = false;
        }
        if (Schema.SObjectType.ClusterJob__c.fields.JobStatusText__c.isUpdateable()) {
            state.clusterJob.JobStatusText__c = statusText;
        } 
        else {
            hasFLS = false;
        }
        if (status == ClusterConstants.JOBSTATUS_COMPLETED) {
            if (Schema.SObjectType.ClusterJob__c.fields.EndDate__c.isUpdateable()) {
                state.clusterJob.EndDate__c = Datetime.now();
            } 
            else {
                hasFLS = false;
            }
        }
        if (!hasFLS) {
            throw new ClusterException('Current user doesn\'t have access to some fields in ClusterJob__c');
        }
        ClusterJob__c currentJob = getJob(state.clusterJob.Id);
        if (currentJob.JobStatus__c == ClusterConstants.JOBSTATUS_MARKED_FOR_CANCEL && status != ClusterConstants.JOBSTATUS_CANCELLED) {
            state.clusterJob = currentJob;
        }
        else {
            if (Schema.SObjectType.ClusterJob__c.isUpdateable()) {
                update state.clusterJob;
            }
        }
        //CRUD permissions are checked above
        List<Attachment> currentAttachments = [SELECT Id, ParentId, Body, BodyLength, Name FROM Attachment WHERE ParentId = :state.clusterJob.Id AND Name=:JOBSTATENAME LIMIT 1 FOR UPDATE];
        Attachment attach;
        hasFLS = true;
        if (currentAttachments.size() == 0) {
            attach = new Attachment();
            if (Schema.SObjectType.Attachment.fields.ParentId.isCreateable()) {
                attach.ParentId = state.clusterJob.Id;
            } 
            else {
                hasFLS = false;
            }
            if (Schema.SObjectType.Attachment.fields.Name.isCreateable()) {
                attach.Name = JOBSTATENAME;
            } 
            else {
                hasFLS = false;
            }
            if (Schema.SObjectType.Attachment.fields.Body.isCreateable()) {
                attach.Body = Blob.valueOf(jobState);
            } 
            else {
                hasFLS = false;
            }
            if (hasFLS && Schema.SObjectType.Attachment.isCreateable()) {
                //CRUD permissions are checked above
                insert attach;            
            }
        }
        else {
            attach = currentAttachments[0];
            if (Schema.SObjectType.Attachment.fields.Body.isUpdateable()) {
                attach.Body = Blob.valueOf(jobState);
            } 
            else {
                hasFLS = false;
            }
            if (hasFLS && Schema.SObjectType.Attachment.isUpdateable()) {
                //CRUD permissions are checked above
                update attach;
            }
        }
        if (!hasFLS) {
            throw new ClusterException('Current user doesn\'t have access to some fields in Attachment');
        }
    }

    public static String loadJobState(Id clusterJobId) {
        ClusterAccessCheck.checkReadPermission(Schema.SObjectType.Attachment);
        //isAccessible permission is checked in ClusterAccessCheck.checkReadPermission, exception is thrown in case of no access
        List<Attachment> currentAttachments = [SELECT Id, ParentId, Body, BodyLength, Name FROM Attachment WHERE ParentId = :clusterJobId AND Name=:JOBSTATENAME LIMIT 1];
        if (currentAttachments.size() > 0) {
            return currentAttachments[0].Body.toString();
        }
        else {
            return null;
        }
    }

    public static void deleteClusterAttachments(List<ClusterJobCluster__c> clusters) {
        ClusterAccessCheck.checkCRUDPermission(Schema.SObjectType.Attachment);        
        List<Id> clusterIds = new List<Id>();
        for(ClusterJobCluster__c cluster:clusters) {
            clusterIds.add(cluster.Id);
        }
        if (clusterIds.size() > 0) {
            //CRUD permissions are checked in ClusterAccessCheck.checkCRUDPermission, exception is thrown in case of no access
            List<Attachment> attachments = [SELECT Id FROM Attachment WHERE ParentId IN :clusterIds];
            if (attachments.size() > 0) {
                delete attachments;
            }
        }
    }

}