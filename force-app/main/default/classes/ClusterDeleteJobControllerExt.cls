/*
 * Controller ext for delete job VF page
 *
 * @author: Iskander Mukhamedgaliyev
 */
public with sharing class ClusterDeleteJobControllerExt {
    private ClusterJob__c record;
    public String batchJobId { get; set; }

    public ClusterDeleteJobControllerExt(ApexPages.StandardController stdController) {
        this.record = (ClusterJob__c)stdController.getRecord();
        this.batchJobId = '';
    }

    public PageReference deleteJob() {
        ClusterDeleteModelJobBatch deleteBatch = new ClusterDeleteModelJobBatch();
        List<Id> jobIdsToDelete = new List<Id>();
        jobIdsToDelete.add(this.record.Id);
        this.batchJobId = deleteBatch.executeBatch(null, jobIdsToDelete);
        return ApexPages.currentPage();
    }

}