trigger ClusterJobResultBeforeDelete on ClusterJobResult__c (before delete) {
    if (Trigger.isBefore && Trigger.isDelete) {
        ClusterJobManager.deleteNearestNeighborsFromResults(Trigger.old);
    }
}