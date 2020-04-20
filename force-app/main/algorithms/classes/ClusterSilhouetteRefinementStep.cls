/*
 * This is a second level algorithm step - reassigns data points to other clusters if needed after first level clusterization is completed
 *
 * @author: Iskander Mukhamedgaliyev
 */
public with sharing class ClusterSilhouetteRefinementStep extends ClusterIterableBase {
    public static Logger log = LogFactory.getLogger();

    public ClusterSilhouetteRefinementStep() {

    }

    public ClusterSilhouetteRefinementStep(Integer batchSize) {
        super(batchSize);
    }

    public override void init(ClusterAlgorithmRunner runner) {
        log.debug('Starting Silhouette refinement step');
        super.init(runner);
        ClusterKMeansJobState jobState = (ClusterKMeansJobState)runner.getJobState();
    }

    protected override Object[] getRecords() {
        return ((ClusterKMeansJobState)this.runner.getJobState()).dataPoints;
    }    
    
    public override void processRecords(Database.BatchableContext bc, Object[] scope) {
        ClusterDataPoint[] scopePoints = (ClusterDataPoint[])scope;
        ClusterKMeansJobState jobState = (ClusterKMeansJobState)this.runner.getJobState();
        ClusterModelWrapper model = jobState.model;
        for (ClusterDataPoint scopePoint:scopePoints) {
            Integer currentClusterSize = 0;
            //Calculate mean distance to current cluster
            Double currentClusterDistance = ClusterDataHelper.calculateMeanDistanceToCluster(scopePoint, scopePoint.clusterIndex, this.runner);
            //Find nearest cluster
            Integer nearestClusterIndex = ClusterDataHelper.findNearestCluster(scopePoint, this.runner);
            //Calculate mean distance to the nearest cluster
            Double nearestClusterDistance = ClusterDataHelper.calculateMeanDistanceToCluster(scopePoint, nearestClusterIndex, this.runner);
            //if distance to the nearest cluster is less reassign current data point to this cluster
            if (nearestClusterDistance < currentClusterDistance) {
                ClusterDataPoint realDP = jobState.dataPoints[jobState.dataPointsIdMap.get(scopePoint.recordId)];
                log.debug('Reassigning data point ' + realDP.recordId + ' from cluster ' + realDP.clusterIndex + ' to cluster ' + nearestClusterIndex);
                realDP.clusterIndex = nearestClusterIndex;
            }
        }
    }

    public override void done(){
        ClusterKMeansJobState jobState = (ClusterKMeansJobState)this.runner.getJobState();
        //TODO: consider recalculating centroids
        super.done();
    }
}