/*
 * Implements record id based distance cache
 *
 * @author: Iskander Mukhamedgaliyev
 */
public with sharing class ClusterRecordIdDistanceCacheManager extends ClusterDistanceCacheManager {

    Integer cacheSize;
    Map<String, Double> distanceCache;

    public ClusterRecordIdDistanceCacheManager(Integer numberOfObjects) {
        this.cacheSize = numberOfObjects;
        this.distanceCache = new Map<String, Double>();        
    }

    private String getCacheKey(String a, String b) {
        if (a > b) {
            return b + a;
        }
        return a + b;
    }

    public override Double get(ClusterDataPoint objectA, ClusterDataPoint objectB) {
        return this.distanceCache.get(this.getCacheKey(objectA.recordId, ObjectB.recordId));
    }

    public override void set(ClusterDataPoint objectA, ClusterDataPoint objectB, Double value) {
        if (this.distanceCache.size() < this.cacheSize) {
            this.distanceCache.put(this.getCacheKey(objectA.recordId, objectB.recordId), value);
        }
    }

}
