/*
 * Implements index based distance cache
 *
 * @author: Iskander Mukhamedgaliyev
 */
public with sharing class ClusterIndexDistanceCacheManager extends ClusterDistanceCacheManager {
    Integer matrixSize;
    Double[] distanceCache;
    public ClusterIndexDistanceCacheManager(Integer numberOfObjects) {
        this.matrixSize = numberOfObjects;
        this.distanceCache = new Double[this.matrixSize * this.matrixSize];
    }

    public override Double get(ClusterDataPoint objectA, ClusterDataPoint objectB) {
        if (objectA.index != null && objectB.index != null) {
            return this.distanceCache[objectB.index * this.matrixSize + objectA.index];
        }
        return null;
    }

    public override void set(ClusterDataPoint objectA, ClusterDataPoint objectB, Double value) {
        this.distanceCache[objectB.index * this.matrixSize + objectA.index] = value;
        this.distanceCache[objectA.index * this.matrixSize + objectB.index] = value;
    }
}
