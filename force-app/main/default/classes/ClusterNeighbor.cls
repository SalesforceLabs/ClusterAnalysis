/*
 * Represents a neighbor cluster
 *
 * @author: Iskander Mukhamedgaliyev
 */
public with sharing class ClusterNeighbor implements Comparable {
    public Double distance;
    public Integer clusterIndex;

    public ClusterNeighbor() {

    }

    public ClusterNeighbor(Integer clusterIdx, Double dist) {
        this.clusterIndex = clusterIdx;
        this.distance = dist;
    }

    /**
     * Allow to sort neighbors
     */
    public Integer compareTo(Object compareTo) {
        ClusterNeighbor other = (ClusterNeighbor) compareTo;
        return ClusterDataHelper.compareDoubles(this.distance, other.distance);
    }
}
