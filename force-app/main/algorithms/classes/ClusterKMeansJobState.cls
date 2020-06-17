/*
 * State of K-Means algorithm
 *
 * @author: Iskander Mukhamedgaliyev
 */
public with sharing class ClusterKMeansJobState extends ClusterJobState {
    public List<ClusterDataPoint> centroids;
    public List<ClusterDataPoint> dataPoints;
    public Map<String, Integer> dataPointsIdMap;
    public Boolean hasAssignmentChanged;
    public Boolean hasSwapped;
    public List<Id> sampleResultsIds;
    public Integer iterationsCount;
    public ClusterKMeansJobState() {
        this.centroids = new List<ClusterDataPoint>();
        this.hasAssignmentChanged = false;
        this.hasSwapped = false;
        this.iterationsCount = 0;
    }
}
