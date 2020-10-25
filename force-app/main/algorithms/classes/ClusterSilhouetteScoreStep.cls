/*
 * Calculates silhouette score for cluster job
 *
 * @author: Iskander Mukhamedgaliyev
 */
public with sharing class ClusterSilhouetteScoreStep extends ClusterIterableBase {
    public static Logger log = LogFactory.getLogger();
    private Double totalSilhouetteScore;
    private Integer sampleCount;
    private List<Id> sampleIds;

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
        ClusterAccessCheck.checkReadPermission(Schema.SObjectType.ClusterJobResult__c);
        //Populating updated cluster numbers into cached data points
        if (jobState.dataPoints != null && jobState.dataPoints.size() > 0 && jobState.dataPointsIdMap != null && jobState.dataPointsIdMap.size() > 0) {
            List<ClusterJobResult__c> existingResults = [SELECT Id, ClusterNumber__c from ClusterJobResult__c WHERE Id IN :jobState.dataPointsIdMap.keySet()];
            for (ClusterJobResult__c existingResult:existingResults) {
                Integer dpIndex = jobState.dataPointsIdMap.get(String.valueOf(existingResult.Id));
                if (dpIndex != null && dpIndex < jobState.dataPoints.size()) {
                    jobState.dataPoints[dpIndex].clusterIndex = Integer.valueOf(existingResult.ClusterNumber__c);
                }
            }
        }
    }

    protected override Object[] getRecords() {
        //Silhouette coefficient will be calculated for a small number of sample records
        ClusterKMeansJobState jobState = (ClusterKMeansJobState)this.runner.getJobState();
        if (jobState.dataPoints == null || jobState.dataPoints.size() == 0) {
            ClusterDataPoint[] dataPoints = ClusterDataHelper.getRandomDataPoints(this.sampleCount, jobState);
            this.sampleIds = new List<Id>();
            for (ClusterDataPoint dataPoint:dataPoints) {
                this.sampleIds.add(dataPoint.recordId);
            }
            return dataPoints;
        }
        return jobState.dataPoints;
    }    
    
    public override void processRecords(Database.BatchableContext bc, Object[] scope) {
        ClusterKMeansJobState jobState = (ClusterKMeansJobState)this.runner.getJobState();
        ClusterDataPoint[] sampleDataPoints;
        if (jobState.dataPoints == null || jobState.dataPoints.size() == 0) {
            //We have to load datapoints each time here as a workaround for "First error: Batchable instance is too big: clustan.ClusterSilhouetteScoreStep"
            //This happens if we store heavy long text data points in the jobState
            //Update: Apparently this is not helping so we cache data points in ClusterInitCentroidsStep
            //This condition is not called now
            sampleDataPoints = ClusterDataHelper.getDataPoints(this.sampleIds, jobState);
        }
        else { 
            sampleDataPoints = jobState.dataPoints;
        }
        ClusterDataPoint[] scopePoints = (ClusterDataPoint[])scope;
        ClusterModelWrapper model = jobState.model;
        for (ClusterDataPoint scopePoint:scopePoints) {
            //Calculating silhouette coefficient - https://en.wikipedia.org/wiki/Silhouette_(clustering)
            Integer currentClusterSize = 0;
            Double currentClusterDistance = ClusterDataHelper.calculateMeanDistanceToCluster(scopePoint, scopePoint.clusterIndex, this.runner, sampleDataPoints);
            Integer nearestClusterIndex = ClusterDataHelper.findNearestCluster(scopePoint, this.runner);
            Double nearestClusterDistance = ClusterDataHelper.calculateMeanDistanceToCluster(scopePoint, nearestClusterIndex, this.runner, sampleDataPoints);
            Double silhouetteScore = ClusterDataHelper.doublesEqual(currentClusterDistance, 0) || ClusterDataHelper.doublesEqual(nearestClusterDistance, 0) ?
                0 : (nearestClusterDistance - currentClusterDistance) / Math.max(currentClusterDistance, nearestClusterDistance);
            this.totalSilhouetteScore += silhouetteScore;
        }
    }

    public override void done(){
        log.debug('Silhouette score calculation complete, storing results');
        log.debug('Total silhouette score: ' + this.totalSilhouetteScore + ', samples count: ' + this.sampleCount);
        ClusterKMeansJobState jobState = (ClusterKMeansJobState)this.runner.getJobState();
        //TODO: Calculate silhouette for each cluster, probably add Score field to JobCluster object
        jobState.clusterJob.Score__c = this.totalSilhouetteScore / this.sampleCount;
        super.done();
    }
}