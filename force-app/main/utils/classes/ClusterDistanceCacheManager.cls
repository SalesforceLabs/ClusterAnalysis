/*
 * Caches pairwise distances for a limited number of objects
 *
 * @author: Iskander Mukhamedgaliyev
 */
public abstract with sharing class ClusterDistanceCacheManager {

    public abstract Double get(ClusterDataPoint objectA, ClusterDataPoint objectB);

    public abstract void set(ClusterDataPoint objectA, ClusterDataPoint objectB, Double value);

}