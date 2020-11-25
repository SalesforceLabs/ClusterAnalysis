/*
 * Controller ext for delete model VF page
 *
 * @author: Iskander Mukhamedgaliyev
 */
public with sharing class ClusterDeleteModelControllerExt {
    private ClusterModel__c record;
    public String batchJobId { get; set; }

    public ClusterDeleteModelControllerExt(ApexPages.StandardController stdController) {
        this.record = (ClusterModel__c)stdController.getRecord();
        this.batchJobId = '';
    }

    public PageReference deleteModel() {
        ClusterDeleteModelJobBatch deleteBatch = new ClusterDeleteModelJobBatch();
        List<Id> modelIdsToDelete = new List<Id>();
        modelIdsToDelete.add(this.record.Id);
        this.batchJobId = deleteBatch.executeBatch(modelIdsToDelete, null);
        return ApexPages.currentPage();
    }

}