/*
 * PAM (K-medoids) data assignment step - assign sample data points to the nearest medoids
 *
 * @author: Iskander Mukhamedgaliyev
 */
public with sharing class ClusterPAMDataAssignmentStep extends ClusterIterableBase {
    public ClusterPAMDataAssignmentStep() {

    }

    public ClusterPAMDataAssignmentStep(Integer batchSize) {
        super(batchSize);
    }

    public override void init(ClusterAlgorithmRunner runner) {
        ClusterIterableBase.log.debug('Starting PAM data assignment step');
        super.init(runner);
        ClusterKMeansJobState jobState = (ClusterKMeansJobState)runner.getJobState();
        for (Integer i=0; i < jobState.centroids.size(); i++) {
            jobState.centroids[i].cost = 0;
        }
    }

    protected override Object[] getRecords() {
        return ((ClusterKMeansJobState)this.runner.getJobState()).dataPoints;
    }

    public override void processRecords(Database.BatchableContext bc, Object[] scope) {
        ClusterDataPoint[] dataPoints = (ClusterDataPoint[])scope;
        ClusterKMeansJobState jobState = (ClusterKMeansJobState)this.runner.getJobState();
        ClusterModelWrapper model = jobState.model;
        Integer scopeSize = scope.size();
        List<ClusterDataPoint> centroids = jobState.centroids;
        Integer centroidSize = centroids.size();
        //Initializing costs
        Double[] centroidCosts = new Double[centroidSize];
        for (Integer i=0; i < centroidSize; i++) {
            centroidCosts[i] = 0;
        }
        Object[] currentObject;
        Map<Id, Integer> reassignedRecords = new Map<Id, Integer>();
        for (Integer sindex = 0; sindex < scopeSize; sindex++){
            ClusterDataPoint currentRecord = dataPoints[sindex];
            //ClusterDataHelper.normalizeObject(currentObject, jobState);
            //Calculating min distance to centroids
            Integer nearestCentroidIndex = -1;
            Integer prevNearestCentroidIndex = -1;
            Boolean isCentroid = false;
            Integer centroidIndex;
            Double minDistance = ClusterDataHelper.DOUBLE_MAX_VALUE;
            Double prevMinDistance = ClusterDataHelper.DOUBLE_MAX_VALUE;
            for (Integer cindex = 0; cindex < centroidSize; cindex++) {
                Boolean isCurrentCentroid = centroids[cindex].recordId == currentRecord.recordId;
                isCentroid = isCentroid || isCurrentCentroid;
                if (isCurrentCentroid) {
                    currentRecord.clusterIndex = null;
                    centroidIndex = cindex;
                }
                Double distance = Math.abs(this.runner.calculateDPDistance(currentRecord, centroids[cindex]));
                if (distance < minDistance) {
                    prevMinDistance = minDistance;
                    prevNearestCentroidIndex = nearestCentroidIndex;
                    minDistance = distance;
                    nearestCentroidIndex = cindex;
                }
                else if (distance < prevMinDistance) {
                    prevMinDistance = distance;
                    prevNearestCentroidIndex = cindex;
                }
            }
            if (!isCentroid) {
                //Reassigning to another cluster if needed
                if (currentRecord.clusterIndex != nearestCentroidIndex) {
                    currentRecord.clusterIndex = nearestCentroidIndex;
                    reassignedRecords.put(currentRecord.recordId, nearestCentroidIndex);
                    jobState.hasAssignmentChanged = true;
                    ClusterIterableBase.log.debug('Reassigning ' + currentRecord + ' to cluster ' + nearestCentroidIndex);
                }
                centroidCosts[nearestCentroidIndex] += minDistance;
            }
            else {
                //If current dp is a centroid store the nearest centroid
                jobState.nearestCentroids[centroidIndex] = prevNearestCentroidIndex;
            }
        }        
        //Aggregating cost for each centroid/medoid
        //Since batches run serially in Apex we don't need to lock/synchronize jobState
        for (Integer i=0; i < centroidSize; i++) {
            jobState.centroids[i].cost += centroidCosts[i];
        }
        //Populating new clusters to data points
        for (Integer i=0; i < jobState.dataPoints.size(); i++) {
            Integer newClusterIndex = reassignedRecords.get(jobState.dataPoints[i].recordId);
            if (newClusterIndex != null) {
                jobState.dataPoints[i].clusterIndex = newClusterIndex;
            }
        }
    }
}