/*
 * Calculates silhouette score for cluster job
 *
 * @author: Iskander Mukhamedgaliyev
 */
public with sharing class ClusterSilhouetteScoreStep extends ClusterIterableBase {
    public static Logger log = LogFactory.getLogger();
    private Double totalSilhouetteScore;
    private Integer sampleCount;

    public ClusterSilhouetteScoreStep() {

    }

    public ClusterSilhouetteScoreStep(Integer batchSize) {
        super(batchSize);
    }

    public override void init(ClusterAlgorithmRunner runner) {
        log.debug('Starting Silhouette score calculation step');
        super.init(runner);
        this.totalSilhouetteScore = 0;
        ClusterKMeansJobState jobState = (ClusterKMeansJobState)this.runner.getJobState();
        this.sampleCount = Math.min(ClusterConstants.getSampleRecordSize(jobState.model), jobState.numRecords);        
    }

    protected override Object[] getRecords() {
        //Silhouette coefficient will be calculated for a small number of sample records
        ClusterKMeansJobState jobState = (ClusterKMeansJobState)this.runner.getJobState();
        if (jobState.dataPoints == null || jobState.dataPoints.size() == 0) {
            return ClusterDataHelper.getRandomDataPoints(this.sampleCount, jobState);
        }
        return jobState.dataPoints;
    }    
    
    public override void processRecords(Database.BatchableContext bc, Object[] scope) {
        ClusterDataPoint[] scopePoints = (ClusterDataPoint[])scope;
        ClusterKMeansJobState jobState = (ClusterKMeansJobState)this.runner.getJobState();
        ClusterModelWrapper model = jobState.model;
        for (ClusterDataPoint scopePoint:scopePoints) {
            //Calculating silhouette coefficient - https://en.wikipedia.org/wiki/Silhouette_(clustering)
            Integer currentClusterSize = 0;
            Double currentClusterDistance = ClusterDataHelper.calculateMeanDistanceToCluster(scopePoint, scopePoint.clusterIndex, this.runner);
            Integer nearestClusterIndex = ClusterDataHelper.findNearestCluster(scopePoint, this.runner);
            Double nearestClusterDistance = ClusterDataHelper.calculateMeanDistanceToCluster(scopePoint, nearestClusterIndex, this.runner);
            Double silhouetteScore = ClusterDataHelper.doublesEqual(currentClusterDistance, 0) || ClusterDataHelper.doublesEqual(nearestClusterDistance, 0) ?
                0 : (nearestClusterDistance - currentClusterDistance) / Math.max(currentClusterDistance, nearestClusterDistance);
            this.totalSilhouetteScore += silhouetteScore;
        }
    }

    public override void done(){
        log.debug('Silhouette score calculation complete, storing results');
        ClusterKMeansJobState jobState = (ClusterKMeansJobState)this.runner.getJobState();
        //TODO: Calculate silhouette for each cluster, probably add Score field to JobCluster object
        jobState.clusterJob.Score__c = this.totalSilhouetteScore / this.sampleCount;
        super.done();
    }
}