/*
 * Caches pairwise distances for a limited number of objects
 *
 * @author: Iskander Mukhamedgaliyev
 */
public with sharing class ClusterDistanceCacheManager {
    Integer matrixSize;
    Double[] distanceCache;
    public ClusterDistanceCacheManager(Integer numberOfObjects) {
        this.matrixSize = numberOfObjects;
        this.distanceCache = new Double[this.matrixSize * this.matrixSize];
    }

    public Double get(Integer x, Integer y) {
        return this.distanceCache[y * this.matrixSize + x];
    }

    public void set(Integer x, Integer y, Double value) {
        this.distanceCache[y * this.matrixSize + x] = value;
        this.distanceCache[x * this.matrixSize + y] = value;
    }
}