/*
 * Batch apex class which deletes cluster models or jobs
 *
 * @author: Iskander Mukhamedgaliyev
 */
public with sharing class ClusterDeleteModelJobBatch implements Database.Batchable<sObject>, Database.Stateful {
    public static Logger log = LogFactory.getLogger();
    private List<Id> jobIdsToDelete;
    private List<Id> modelIdsToDelete;

    public ClusterDeleteModelJobBatch() {
    }   
    
    public virtual String executeBatch(List<Id> modelIdsToDelete, List<Id> jobIdsToDelete){
        Integer batchSize = Test.isRunningTest() ? ClusterConstants.TEST_BATCH_SIZE : ClusterConstants.getBatchSize();
        this.modelIdsToDelete = modelIdsToDelete;
        ClusterAccessCheck.checkCRUDPermission(Schema.sObjectType.ClusterJob__c);
        ClusterAccessCheck.checkCRUDPermission(Schema.sObjectType.ClusterJobCluster__c);
        ClusterAccessCheck.checkCRUDPermission(Schema.sObjectType.ClusterJobResult__c);
        if (jobIdsToDelete == null || jobIdsToDelete.size() == 0) {
            ClusterAccessCheck.checkCRUDPermission(Schema.sObjectType.ClusterModel__c);
            ClusterAccessCheck.checkCRUDPermission(Schema.sObjectType.ClusterModelField__c);
            List<ClusterJob__c> jobs = [SELECT Id, JobStatus__c, JobStatusText__c FROM ClusterJob__c WHERE ClusterModel__c IN :modelIdsToDelete];
            this.jobIdsToDelete = new List<Id>();
            for (ClusterJob__c job: jobs) {
                this.jobIdsToDelete.add(job.Id);
                job.JobStatus__c = ClusterConstants.JOBSTATUS_MARKED_FOR_CANCEL;
                job.JobStatusText__c = 'Delete operation is in progress';
            }
            update jobs;
        }
        else {
            List<ClusterJob__c> jobs = [SELECT Id, JobStatus__c FROM ClusterJob__c WHERE Id IN :jobIdsToDelete];
            for (ClusterJob__c job: jobs) {
                job.JobStatus__c = ClusterConstants.JOBSTATUS_MARKED_FOR_CANCEL;
            }
            update jobs;
            this.jobIdsToDelete = jobIdsToDelete;
        }        
        String jobId = Database.executeBatch(this, batchSize);
        log.debug('Started delete batch job: ' + jobId);
        return jobId;
    }

    private Database.QueryLocator getBatchQueryLocator() {
        ClusterAccessCheck.checkCRUDPermission(Schema.sObjectType.ClusterJob__c);
        ClusterAccessCheck.checkFLSReadPermission(Schema.sObjectType.ClusterJobResult__c.fields.ClusterJob__c);
        return Database.getQueryLocator([SELECT Id FROM ClusterJobResult__c WHERE ClusterJob__c IN :this.jobIdsToDelete]);
    }

    public virtual Database.QueryLocator start(Database.BatchableContext bc) {
        Database.QueryLocator query = this.getBatchQueryLocator();
        log.debug('Entering batch start, processing soql query: ' + query.getQuery());
        return query;
    }

    public virtual void execute(Database.BatchableContext bc, List<ClusterJobResult__c> scope) {
        log.debug('Entering execute, deleting ' + scope.size() + ' records');
        try {
            //We check permissions in executeBatch, but let's check again here and below
            if (Schema.sObjectType.ClusterJobResult__c.isAccessible() && Schema.sObjectType.ClusterJobResult__c.isDeletable()) {
                delete scope;
            }
        }
        catch (Exception ex) {
            log.error('Exception caught while deleting ' + scope.size() + ' records', ex);
            throw ex; 
        }
    }

    public virtual void finish(Database.BatchableContext bc){
        ClusterAccessCheck.checkFLSReadPermission(Schema.sObjectType.ClusterJobCluster__c.fields.ClusterJob__c);
        if (Schema.sObjectType.ClusterJobCluster__c.isAccessible() && Schema.sObjectType.ClusterJobCluster__c.isDeletable()) {
            List<ClusterJobCluster__c> clustersToDelete = [SELECT Id FROM ClusterJobCluster__c WHERE ClusterJob__c IN :this.jobIdsToDelete];
            if (clustersToDelete.size() > 0) {
                log.debug('Deleting ' + clustersToDelete.size() + ' clusters');
                delete clustersToDelete;
            }
        }
        if (this.jobIdsToDelete.size() > 0) {
            if (Schema.sObjectType.ClusterJob__c.isAccessible() && Schema.sObjectType.ClusterJob__c.isDeletable()) {
                log.debug('Deleting ' + this.jobIdsToDelete.size() + ' jobs');
                ClusterAccessCheck.checkFLSReadPermission(Schema.sObjectType.ClusterJob__c.fields.Id);
                List<ClusterJob__c> jobsToDelete = [SELECT Id FROM ClusterJob__c WHERE Id IN :this.jobIdsToDelete];
                delete jobsToDelete;
            }
        }
        if (this.modelIdsToDelete != null && this.modelIdsToDelete.size() > 0) {
            if (Schema.sObjectType.ClusterModelField__c.isAccessible() && Schema.sObjectType.ClusterModelField__c.isDeletable() 
                && Schema.sObjectType.ClusterModel__c.isAccessible() && Schema.sObjectType.ClusterModel__c.isDeletable() 
                && Schema.sObjectType.ClusterModelField__c.fields.Model__c.isAccessible()) {
                List<ClusterModelField__c> fieldsToDelete = [SELECT Id FROM ClusterModelField__c WHERE Model__c IN :this.modelIdsToDelete];
                if (fieldsToDelete.size() > 0) {
                    if (Schema.sObjectType.ClusterModelField__c.isAccessible() && Schema.sObjectType.ClusterModelField__c.isDeletable()) {
                        log.debug('Deleting ' + fieldsToDelete.size() + ' model fields');
                        delete fieldsToDelete;
                    }
                }
                List<ClusterModel__c> modelsToDelete = [SELECT Id FROM ClusterModel__c WHERE Id IN :this.modelIdsToDelete];
                if (modelsToDelete.size() > 0) {
                    if (Schema.sObjectType.ClusterModel__c.isAccessible() && Schema.sObjectType.ClusterModel__c.isDeletable()) {
                        log.debug('Deleting ' + modelIdsToDelete.size() + ' models');
                        delete modelsToDelete;
                    }
                }
            }
        }
    }    

}
