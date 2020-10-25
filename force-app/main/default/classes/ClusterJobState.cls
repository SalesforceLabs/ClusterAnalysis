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

    public virtual void loadFromMap(Map<String, Object> stateValues) {
        this.numRecords = (Integer)stateValues.get('numRecords');
        this.totalIterationsCount = (Integer)stateValues.get('totalIterationsCount');
        this.currentAlgorithmStep = (Integer)stateValues.get('currentAlgorithmStep');
        this.model = new ClusterModelWrapper();
        this.model.loadFromMap((Map<String, Object>)stateValues.get('currentAlgorithmStep'));
        Object[] minMaxList = (Object[])stateValues.get('minMaxValues');
        this.minMaxValues = new List<ClusterMinMaxValue>();
        if (minMaxList != null) {
            for (Object minMax:minMaxList) {
                ClusterMinMaxValue mmv = new ClusterMinMaxValue();
                mmv.loadFromMap((Map<String, Object>)minMax);
                this.minMaxValues.add(mmv);
            }
        }
        Map<String, Object> clusterJobValues = (Map<String, Object>)stateValues.get('clusterJob');
        this.clusterJob = ClusterJobManager.getJob(Id.valueOf((String)clusterJobValues.get('Id')));
        this.jobClusters = ClusterJobManager.getJobClusters(this.clusterJob.Id);
    }
}