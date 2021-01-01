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
                else if (model.fields[i].isLongText) {
                    centroids[cindex].values[i] = new List<Double>(); //Initialize with Double[], this will be converted to ClusterCompressedDoubleArray in the end
                }
                
            }
            this.clusterSizes[cindex] = 0;
        }
    }
    
    protected override Database.QueryLocator getBatchQueryLocator() {
        ClusterKMeansJobState jobState = (ClusterKMeansJobState)runner.getJobState();
        //CRUD permissions on ClusterJobResult__c are checked in ClusterAccessCheck.checkCRUDPermission in ClusterAlgorithmRunner.start which is calling all ClusterAlgorithmStep implementors
        //exception is thrown there in case of no access
        return Database.getQueryLocator([SELECT Id, Cluster__c, Json__c, Json2__c, Json3__c, Json4__c, Json5__c, RecordId__c, RecordName__c, ClusterNumber__c, ClusterJob__c,DistanceToCluster__c, DistanceToNNCluster__c 
            FROM ClusterJobResult__c WHERE ClusterJob__c = :jobState.clusterJob.Id]);
    }

    public override void processRecords(Database.BatchableContext bc, List<SObject> scope) {        
        ClusterKMeansJobState jobState = (ClusterKMeansJobState)this.runner.getJobState();
        ClusterModelWrapper model = jobState.model;
        ClusterMinMaxValue[] minMaxValues = jobState.minMaxValues;
        Integer length = model.fields.size();
        Integer scopeSize = scope.size();
        ClusterSObjectProcessor objectProcessor = this.runner.getSObjectProcessor();
        List<ClusterDataPoint> centroids = jobState.centroids;
        for (Integer sindex = 0; sindex < scopeSize; sindex++){
            ClusterJobResult__c currentRecord = (ClusterJobResult__c)scope[sindex];
            ClusterDataPoint currentDataPoint = objectProcessor.createDataPointFromResult(currentRecord);
            ClusterDataPoint currentCentroid = centroids[currentDataPoint.clusterIndex];
            //Calculating per cluster sum and count of all data point values
            for (Integer findex=0; findex<model.fields.size(); findex++) {
                if (model.fields[findex].isNumeric) {
                    currentCentroid.values[findex] = ClusterDataHelper.asDouble(currentCentroid.values[findex]) + ClusterDataHelper.asDouble(currentDataPoint.values[findex]);
                }
                else if (model.fields[findex].isLongText) {
                    Double[] tf1 = (Double[])currentCentroid.values[findex];
                    ClusterCompressedDoubleArray tf2 = (ClusterCompressedDoubleArray)currentDataPoint.values[findex];
                    if ((tf1 != null) && (tf2 != null)) {
                        ClusterCompressedDoubleArray.ClusterCompressedDoubleArrayIterator tf2iterator = tf2.iterator();
                        Integer tf1Index = 0;
                        Integer tf1Size = tf1.size();
                        while (tf2iterator.moveNext()) {
                            if (tf1Size <= tf1Index) {
                                tf1.add(ClusterDataHelper.DOUBLE_ZERO);
                                tf1Size++;
                            }
                            Double v2 = tf2iterator.getValue();
                            tf1[tf1Index] = tf1[tf1Index] + v2;
                            tf1Index++;
                        }
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
                        centroids[cindex].values[i] = ClusterDataHelper.asDouble(centroids[cindex].values[i]) / this.clusterSizes[cindex];
                    }
                    else if (model.fields[i].isLongText) {
                        Double[] tf = (Double[])centroids[cindex].values[i];
                        if (tf != null) {
                            for (Integer tfIndex = 0; tfIndex < tf.size(); tfIndex++) {
                                tf[tfIndex] = tf[tfIndex] / this.clusterSizes[cindex];
                            }
                        }
                        centroids[cindex].values[i] = new ClusterCompressedDoubleArray(tf);
                    }    
                }
            }
            centroids[cindex].clusterIndex = cindex;
        }
        this.clusterSizes = null;
        super.done();
    }
}