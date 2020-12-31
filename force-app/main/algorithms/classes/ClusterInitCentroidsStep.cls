/*
 * Initializes centroids using k-means++ algorithm and loads sample random records for K-Medoids
 *
 * @author: Iskander Mukhamedgaliyev
 */
public with sharing class ClusterInitCentroidsStep extends ClusterIterableBase {
    Boolean cacheRecords;
    public static Logger log = LogFactory.getLogger();

    public ClusterInitCentroidsStep() {

    }

    public ClusterInitCentroidsStep(Boolean loadInMemory) {
        this.cacheRecords = loadInMemory;
    }

    public override void init(ClusterAlgorithmRunner runner) {
        log.debug('Starting init centroids step');
        super.init(runner);
        ClusterKMeansJobState jobState = (ClusterKMeansJobState)this.runner.getJobState();

        this.batchSize = jobState.model.hasLongTextFields() ? ClusterConstants.getInitCentroidStepLongTextBatchSize() : ClusterConstants.getInitCentroidStepBatchSize();
        log.debug('ClusterInitCentroidsStep batch size is ' + this.batchSize);

        jobState.sampleResultsIds = new List<Id>();
        jobState.centroids = new List<ClusterDataPoint>();
        jobState.dataPoints = new List<ClusterDataPoint>();
        jobState.dataPointsIdMap = new Map<String, Integer>();
        this.initSampleRecords();
        this.runner.initializeDistanceCache();
        log.debug('Finished initializing cache, current heap size: ' + Limits.getHeapSize());

        //Select first centroid randomly
        Integer centroidIndex = ClusterDataHelper.getRandomInt(0, jobState.dataPoints.size() - 1);
        jobState.centroids.add(jobState.dataPoints[centroidIndex]);        
    }

    private void initSampleRecords() {
        log.debug('Retrieving random records from db');
        ClusterKMeansJobState jobState = (ClusterKMeansJobState)this.runner.getJobState();
        Integer count = Math.min(ClusterConstants.getSampleRecordSize(jobState.model), jobState.numRecords);
        ClusterAccessCheck.checkCRUDPermission(Schema.SObjectType.ClusterJobResult__c);
        //isAccessible permission is checked in ClusterAccessCheck.checkReadPermission, exception is thrown in case of no access
        List<ClusterJobResult__c> randomRecords = [SELECT Id, Cluster__c, Json__c, Json2__c, Json3__c, Json4__c, Json5__c, RecordId__c, RecordName__c, ClusterNumber__c, ClusterJob__c FROM ClusterJobResult__c WHERE ClusterJob__c = :jobState.clusterJob.Id ORDER BY Random__c LIMIT :count];
        ClusterModelWrapper model = jobState.model;

        log.debug('Initializing ' + randomRecords.size() + ' sample records');
        ClusterSObjectProcessor objectProcessor = this.runner.getSObjectProcessor();

        // Iterate over the records
        Integer index = 0;
        for (SObject record:randomRecords)
        {
            jobState.sampleResultsIds.add(record.Id);
            ClusterDataPoint dp = this.createDataPoint((ClusterJobResult__c)record, objectProcessor);
            jobState.dataPoints.add(dp);
            dp.index = index;
            if (this.cacheRecords) {
                jobState.dataPointsIdMap.put(dp.recordId, index);
            }
            index++;
        }

        log.debug('Finished initializing sample records, current heap size: ' + Limits.getHeapSize());

    }

    protected override Object[] getRecords() {
        ClusterKMeansJobState jobState = (ClusterKMeansJobState)this.runner.getJobState();
        //First centroid was initialized randomly, this selects remaining n-1 centroids
        Integer[] clusterIndices = new Integer[jobState.model.numberOfClusters - 1];
        for (Integer i=0; i<jobState.model.numberOfClusters - 1; i++) {
            clusterIndices[i] = i + 1;
        }
        return clusterIndices;        
    }

    public override void processRecords(Database.BatchableContext bc, Object[] scope) {
        ClusterKMeansJobState jobState = (ClusterKMeansJobState)this.runner.getJobState();
        ClusterModelWrapper model = jobState.model;
        for (Integer i = 0; i<scope.size(); i++) {
            Integer centroidIndex = (Integer)scope[i];
            log.debug('Initializing centroid ' + centroidIndex);
            Double maxDistance = 0;
            Integer maxCentroid = 0;
            for (Integer dpIndex = 0; dpIndex < jobState.dataPoints.size(); dpIndex++) {
                log.debug('Processing datapoint ' + dpIndex);
                //Compute distance from current data point to each selected centroid
                //And choose the minimum distance
                Double minDistance = this.runner.calculateDPDistance(jobState.dataPoints[dpIndex], jobState.centroids[0]);
                Boolean isCentroid = false;
                for (Integer cIndex = 1; cIndex < jobState.centroids.size(); cIndex++){
                    if (jobState.centroids[cIndex].recordId == jobState.dataPoints[dpIndex].recordId) {
                        isCentroid = true;
                        break;
                    }
                    Double distance = this.runner.calculateDPDistance(jobState.dataPoints[dpIndex], jobState.centroids[cIndex]);
                    minDistance = Math.min(minDistance, distance);
                }
                if (!isCentroid && (minDistance > maxDistance)) {
                    maxDistance = minDistance;
                    maxCentroid = dpIndex;
                }
            }
            //Select data point with maximum distance as next centroid
            //we will not calculate probabilities as per k-means++ to save Apex CPU time
            //dp with maximum distance has more chances to become a centroid anyways
            jobState.centroids.add(jobState.dataPoints[maxCentroid]);
        }

        log.debug('Finished initializing centroids, current heap size: ' + Limits.getHeapSize());

    }

    private ClusterDataPoint createDataPoint(ClusterJobResult__c resultRecord, ClusterSObjectProcessor objectProcessor) {
        ClusterDataPoint dp = new ClusterDataPoint();
        dp.recordId = resultRecord.Id;
        dp.externalId = resultRecord.RecordId__c;
        dp.values = (Object[])objectProcessor.parseValuesFromJson(ClusterDataHelper.getClusterJobResultValues(resultRecord));
        return dp;
    }

    public override void done() {
        ClusterKMeansJobState jobState = (ClusterKMeansJobState)this.runner.getJobState();
        //Initializing nearest centroids
        jobState.nearestCentroids = new Integer[jobState.centroids.size()];

        if (!this.cacheRecords) {
            //Clear the data point cache
            //For K-Medoids we will cache records in memory
            //Since we are using CLARA algorithm the number of records should fit in 12M heap (async mode)
            //For K-Means we will also cache because there are some heap issues in SilhouetteScore step with LongText when we initialize cache there
            jobState.dataPoints = null;
        }
        log.debug('Init centroids step finished');
        log.debug('initial centroids: ' + jobState.centroids);        
        super.done();
    }

}