/*
 * Centroid data assignment algorithm step - populates ClusterJobResult__c and finds min and max values for each field
 *
 * @author: Iskander Mukhamedgaliyev
 */
public with sharing class ClusterCentroidDataAssignmentStep extends ClusterBatchBase implements ClusterAlgorithmStep {

    Integer[] clusterAttachmentSizes;
    transient List<Id> sampleResultsIds;
    Boolean updateResults = false;
    Boolean storeAssignments = false;
    Boolean useSampleIds = false;
    Boolean useDistanceToCluster = false;

    public ClusterCentroidDataAssignmentStep(Boolean updateResults, Boolean storeAssignments, Boolean useSampelIds, Boolean useDistanceToCluster) {
        this.updateResults = updateResults;
        this.storeAssignments = storeAssignments;
        this.useSampleIds = useSampleIds;
        this.useDistanceToCluster = useDistanceToCluster;
        //Checking CRUD permissions
        ClusterAccessCheck.checkCRUDPermission(Schema.SObjectType.ClusterJobResult__c);
    }

    public override void init(ClusterAlgorithmRunner runner) {
        ClusterBatchBase.log.debug('Starting data assignment step');
        super.init(runner);
        ClusterKMeansJobState jobState = (ClusterKMeansJobState)runner.getJobState();
        clusterAttachmentSizes = new Integer[jobState.model.numberOfClusters];
        for (Integer i=0; i < clusterAttachmentSizes.size(); i++) {
            clusterAttachmentSizes[i] = 0;
        }
        ClusterJobManager.deleteClusterAttachments(jobState.clusterJob.JobClusters__r);
        jobState.hasAssignmentChanged = false;
        this.sampleResultsIds = jobState.sampleResultsIds;
    }
    
    protected override Database.QueryLocator getBatchQueryLocator() {
        ClusterKMeansJobState jobState = (ClusterKMeansJobState)runner.getJobState();
        //CRUD permissions are checked in ClusterAccessCheck.checkCRUDPermission in the constructor above (for performance reasons), exception is thrown in case of no access
        if (this.useSampleIds && this.sampleResultsIds != null && this.sampleResultsIds.size() > 0) {
            return Database.getQueryLocator([SELECT Id, Cluster__c, Json__c, Json2__c, Json3__c, Json4__c, Json5__c, RecordId__c, RecordName__c, ClusterNumber__c, ClusterJob__c, DistanceToCluster__c FROM ClusterJobResult__c WHERE Id IN :sampleResultsIds]);
        }
        else {
            return Database.getQueryLocator([SELECT Id, Cluster__c, Json__c, Json2__c, Json3__c, Json4__c, Json5__c, RecordId__c, RecordName__c, ClusterNumber__c, ClusterJob__c, DistanceToCluster__c FROM ClusterJobResult__c WHERE ClusterJob__c = :jobState.clusterJob.Id]);
        }
    }

    public override void processRecords(Database.BatchableContext bc, List<SObject> scope) {        
        ClusterKMeansJobState jobState = (ClusterKMeansJobState)this.runner.getJobState();
        ClusterModelWrapper model = jobState.model;
        ClusterMinMaxValue[] minMaxValues = jobState.minMaxValues;
        Integer length = model.fields.size();
        Integer scopeSize = scope.size();
        List<ClusterDataPoint> centroids = jobState.centroids;
        Integer centroidSize = centroids.size();
        Object[] currentObject;
        ClusterSObjectProcessor objectProcessor = this.runner.getSObjectProcessor();
        List<ClusterJobResult__c> updatedResults = new List<ClusterJobResult__c>();
        for (Integer sindex = 0; sindex < scopeSize; sindex++){
            ClusterBatchBase.log.debug('Processing record ' + sindex);
            ClusterJobResult__c currentRecord = (ClusterJobResult__c)scope[sindex];
            ClusterDataPoint currentDataPoint = objectProcessor.createDataPointFromResult(currentRecord);
            //ClusterDataHelper.normalizeObject(currentObject, jobState);
            //Calculating min distance to centroids
            Integer nearestCentroidIndex = 0;
            Integer previousCentroidIndex = 0;
            Double minDistance = this.runner.calculateDPDistance(currentDataPoint, centroids[nearestCentroidIndex]);
            for (Integer cindex = 1; cindex < centroidSize; cindex++) {
                Double distance = this.runner.calculateDPDistance(currentDataPoint, centroids[cindex]);
                if (Math.abs(distance) < Math.abs(minDistance)) {
                    minDistance = distance;
                    nearestCentroidIndex = cindex;
                    previousCentroidIndex = nearestCentroidIndex;
                }
            }
            //We found closest and second closest centroids to the current data point
            //Normally we should reassign current data point to nearestCentroidIndex
            //But if useDistanceToCluster option is enabled we will calculate mean distances to all data points from these 2 clusters
            //And choose the one with minimum mean distance to reassign
            if (this.useDistanceToCluster) {
                //Calculate mean distance to the current nearest cluster found in previous step
                Double currentClusterDistance = ClusterDataHelper.calculateMeanDistanceToCluster(currentDataPoint, nearestCentroidIndex, this.runner);
                //Calculate mean distance to the second nearest cluster 
                Double nearestClusterDistance = ClusterDataHelper.calculateMeanDistanceToCluster(currentDataPoint, previousCentroidIndex, this.runner);
                //if distance to the nearest cluster is less reassign current data point to this cluster
                if (nearestClusterDistance < currentClusterDistance) {
                    nearestCentroidIndex = previousCentroidIndex;
                }
            }
            //Reassigning to another cluster if needed
            if (currentRecord.ClusterNumber__c != nearestCentroidIndex) {
                currentRecord.ClusterNumber__c = nearestCentroidIndex;
                currentRecord.Cluster__c = jobState.jobClusters[nearestCentroidIndex].Id;
                currentRecord.DistanceToCluster__c = Decimal.valueOf(minDistance);
                if (this.updateResults) {
                    //CRUD permissions are checked in ClusterAccessCheck.checkCRUDPermission in the constructor above (for performance reasons), exception is thrown in case of no access
                    updatedResults.add(currentRecord);
                }
                jobState.hasAssignmentChanged = true;
            }
        }
        if (this.updateResults) {
            //CRUD permissions are checked in ClusterAccessCheck.checkCRUDPermission in the constructor above (for performance reasons), exception is thrown in case of no access
            update updatedResults;
        }
    }

    public override void done(){
        this.clusterAttachmentSizes = null;
        super.done();
    }
}