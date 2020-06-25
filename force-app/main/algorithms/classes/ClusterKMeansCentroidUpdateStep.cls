/*
 * K-means centroid update step - calculates new mean values for centroids
 *
 * @author: Iskander Mukhamedgaliyev
 */
public with sharing class ClusterKMeansCentroidUpdateStep extends ClusterBatchBase implements ClusterAlgorithmStep {

    Integer[] clusterSizes;

    public ClusterKMeansCentroidUpdateStep () {
    }

    public override void init(ClusterAlgorithmRunner runner) {
        ClusterBatchBase.log.debug('Starting KMeans centroid update step');
        super.init(runner);
        ClusterKMeansJobState jobState = (ClusterKMeansJobState)runner.getJobState();
        ClusterModelWrapper model = jobState.model;
        jobState.hasAssignmentChanged = false;
        List<ClusterDataPoint> centroids = jobState.centroids;
        this.clusterSizes = new Integer[centroids.size()];
        for (Integer cindex=0; cindex<centroids.size(); cindex++) {
            for (Integer i=0; i<model.fields.size(); i++) {
                if (model.fields[i].distanceType == ClusterConstants.FIELDTYPE_NUMERIC) {
                    centroids[cindex].values[i] = 0; //initialize with zero
                }
                else if (model.fields[i].isNameField) {
                    centroids[cindex].recordName = 'Centroid ' + String.valueOf(cindex); //Update name to not point to real data point anymore since it will represent mean
                    centroids[cindex].values[i] = centroids[cindex].recordName;
                }
                else if (model.fields[i].isIdField) {
                    centroids[cindex].recordId = null; 
                    centroids[cindex].values[i] = String.valueOf(cindex); //Update real id to cluster index, same as above
                }
            }
            this.clusterSizes[cindex] = 0;
        }
    }
    
    protected override Database.QueryLocator getBatchQueryLocator() {
        ClusterKMeansJobState jobState = (ClusterKMeansJobState)runner.getJobState();
        //CRUD permissions on ClusterJobResult__c are checked in ClusterAccessCheck.checkCRUDPermission in ClusterAlgorithmRunner.start which is calling all ClusterAlgorithmStep implementors
        //exception is thrown there in case of no access
        return Database.getQueryLocator([SELECT Id, Cluster__c, Json__c, RecordId__c, RecordName__c, ClusterNumber__c, ClusterJob__c FROM ClusterJobResult__c WHERE ClusterJob__c = :jobState.clusterJob.Id]);
    }

    public override void processRecords(Database.BatchableContext bc, List<SObject> scope) {        
        ClusterKMeansJobState jobState = (ClusterKMeansJobState)this.runner.getJobState();
        ClusterModelWrapper model = jobState.model;
        ClusterMinMaxValue[] minMaxValues = jobState.minMaxValues;
        Integer length = model.fields.size();
        Integer scopeSize = scope.size();
        ClusterSObjectProcessor objectProcessor = new ClusterSObjectProcessor(jobState);
        List<ClusterDataPoint> centroids = jobState.centroids;
        for (Integer sindex = 0; sindex < scopeSize; sindex++){
            ClusterJobResult__c currentRecord = (ClusterJobResult__c)scope[sindex];
            ClusterDataPoint currentDataPoint = new ClusterDataPoint(currentRecord, objectProcessor);
            ClusterDataPoint currentCentroid = centroids[currentDataPoint.clusterIndex];
            //Calculating per cluster sum and count of all data point values
            for (Integer findex=0; findex<model.fields.size(); findex++) {
                if (model.fields[findex].isNumeric) {
                    currentCentroid.values[findex] = Double.valueOf(currentCentroid.values[findex]) + Double.valueOf(currentDataPoint.values[findex]);
                }
                else if (model.fields[findex].isLongText) {
                    Double[] tf1 = (Double[])currentCentroid.values[findex];
                    Double[] tf2 = (Double[])currentDataPoint.values[findex];
                    Integer tf1Size = tf1.size();
                    Integer tf2Size = tf2.size();
                    if (tf1Size < tf2Size) {
                        //Resizing centroid array
                        for (Integer sizeIndex = 0; sizeIndex < tf2Size - tf1Size; sizeIndex++) {
                            tf1.add(0.0);
                        }
                    }
                    for (Integer tfIndex = 0; tfIndex < tf1Size; tfIndex++) {
                        Double v2 = tfIndex < tf2Size ? tf2[tfIndex] : 0.0;
                        tf1[tfIndex] = tf1[tfIndex] + v2;
                    }            
                }
            }
            this.clusterSizes[currentDataPoint.clusterIndex]++;
        }
    }

    public override void done(){
        ClusterKMeansJobState jobState = (ClusterKMeansJobState)runner.getJobState();
        ClusterModelWrapper model = jobState.model;
        List<ClusterDataPoint> centroids = jobState.centroids;
        //Calculating centroid mean values
        for (Integer cindex=0; cindex<centroids.size(); cindex++) {
            if (this.clusterSizes[cindex] != 0) {
                for (Integer i=0; i<model.fields.size(); i++) {
                    if (model.fields[i].isNumeric) {
                        centroids[cindex].values[i] = Double.valueOf(centroids[cindex].values[i]) / this.clusterSizes[cindex];
                    }
                    else if (model.fields[i].isLongText) {
                        Object[] tf = (Object[])centroids[cindex].values[i];
                        for (Integer tfIndex = 0; tfIndex < tf.size(); tfIndex++) {
                            tf[tfIndex] = Double.valueOf(tf[tfIndex]) / this.clusterSizes[cindex];
                        }            
                    }    
                }
            }
            centroids[cindex].clusterIndex = cindex;
        }
        this.clusterSizes = null;
        super.done();
    }
}