/*
 * Holds state of the current algorithm
 *
 * @author: Iskander Mukhamedgaliyev
 */
public virtual class ClusterJobState {
    public ClusterJobState() {

    }
    public ClusterModelWrapper model;
    public ClusterMinMaxValue[] minMaxValues;
    public Id currentJobId;
    public ClusterJob__c clusterJob;
    public ClusterJobCluster__c[] jobClusters;
    public Integer currentAlgorithmStep;
    public Integer totalIterationsCount;
    public Integer numRecords;
}
