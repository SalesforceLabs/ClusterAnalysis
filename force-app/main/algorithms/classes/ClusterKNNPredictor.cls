/*
 * K-Nearest Neighbors prediction implementation
 *
 * @author: Iskander Mukhamedgaliyev
 */
public with sharing class ClusterKNNPredictor {
    public static Logger log = LogFactory.getLogger();

    ClusterAlgorithmRunner runner;
    Integer maxNNSearchCount;
    Integer knnNumber;
    Integer maxNNSearchChunkCount;
    
    public ClusterKNNPredictor() {
        this.init();
    }

    public ClusterKNNPredictor(ClusterAlgorithmRunner runner) {
        this.setRunner(runner);
        this.init();
    }

    private void init() {
        this.maxNNSearchCount = ClusterConstants.getKNNSearchLimit();
        this.knnNumber = ClusterConstants.getKNNNumber();
        this.maxNNSearchChunkCount = ClusterConstants.getKNNSearchChunkLimit();    
    }

    public void setRunner(ClusterAlgorithmRunner runner) {
        this.runner = runner;
    }

    public ClusterPredictionResult predict(Id recordId, String jobStateJson, Boolean insertDataPoint) {
        this.runner.setJobState(jobStateJson);
        return this.predict(recordId, insertDataPoint);
    }

    public ClusterPredictionResult predict(Id dpRecordId, Boolean insertDataPoint) {
        ClusterDataPoint dataPoint = this.runner.getDataPoint(dpRecordId);
        return this.predict(dataPoint, insertDataPoint);
    }

    public virtual ClusterPredictionResult predict(ClusterDataPoint dataPoint, Boolean insertDataPoint) {
        log.debug('Starting prediction calculations for ' + dataPoint.recordName);
        ClusterJobState jobState = this.runner.getJobState();
        List<ClusterDataPointNeighbor> nearestNeighbors = null;
        if (String.isNotBlank(dataPoint.externalId)) {
            //Check if we previously calculated and cached nearest neighbors
            nearestNeighbors = this.getNearestNeighborsFromDb(dataPoint.externalId, jobState.clusterJob.Id, this.knnNumber);
        }
        if (nearestNeighbors == null || nearestNeighbors.size() == 0) {
            nearestNeighbors = this.findNearestNeighbors(dataPoint, ClusterConstants.NUM_NEAREST_NEIGHBORS_PREDICTION, insertDataPoint);
        }
        ClusterPredictionResult predictionResult = new ClusterPredictionResult();
        predictionResult.dataPoint = dataPoint;
        Map<Id,ClusterPredictionResult.FieldPrediction> fieldPredictionMap = new Map<Id,ClusterPredictionResult.FieldPrediction>();
        ClusterPredictionResult.FieldPrediction clusterPrediction = new ClusterPredictionResult.FieldPrediction();
        for (ClusterDataPointNeighbor neighbor:nearestNeighbors) {
            for (Integer i=0; i<jobState.model.fields.size(); i++) {
                ClusterModelFieldWrapper field = jobState.model.fields[i];
                if (field.isPrediction) {
                    log.debug('Calculating prediction values for field: ' + field.name + ', value: ' + neighbor.neighborDataPoint.values[i]);
                    ClusterPredictionResult.FieldPrediction fieldPrediction = fieldPredictionMap.get(field.fieldId);
                    if (fieldPrediction == null) {
                        fieldPrediction = new ClusterPredictionResult.FieldPrediction();
                        fieldPrediction.field = field;
                        fieldPredictionMap.put(field.fieldId, fieldPrediction);
                    }
                    if (field.isDataTypeNumeric) {
                        //If prediction field is numeric calculate weighted mean
                        fieldPrediction.addPredictionDoubleValue(Double.valueOf(neighbor.neighborDataPoint.values[i]), (Double)1.0 - neighbor.distance);
                    }
                    else {
                        //If it is a string calculate weighted mode
                        fieldPrediction.addPredictionStringValue(String.valueOf(neighbor.neighborDataPoint.values[i]), (Double)1.0 - neighbor.distance);
                    }
                }
            }
            //Calculate weighted cluster index mode
            log.debug('Adding cluster index: ' + neighbor.neighborDataPoint.clusterIndex);
            clusterPrediction.addPredictionStringValue(String.valueOf(neighbor.neighborDataPoint.clusterIndex), (Double)1.0 - neighbor.distance);
        }
        clusterPrediction.aggregateValues(nearestNeighbors.size());
        predictionResult.fieldPredictions = fieldPredictionMap.values();
        predictionResult.clusterPrediction = clusterPrediction;
        for (ClusterPredictionResult.FieldPrediction prediction:predictionResult.fieldPredictions) {
            prediction.aggregateValues(nearestNeighbors.size());
        }
        predictionResult.clusterIndex = Integer.valueOf(clusterPrediction.fieldValuePredictions[0].value);
        return predictionResult;
    }

    public List<ClusterDataPointNeighbor> findNearestNeighbors(Id recordId, Integer numNeighbors, Boolean insertDataPoint) {
        log.debug('Starting k nearest neighbor calculations for record id: ' + recordId);
        ClusterDataPoint dataPoint = this.runner.getDataPoint(recordId);
        return this.findNearestNeighbors(dataPoint, numNeighbors, insertDataPoint);
    }

    public List<ClusterDataPointNeighbor> findNearestNeighbors(ClusterDataPoint dataPoint, Integer numNeighbors, Boolean insertDataPoint) {
        ClusterAccessCheck.checkCRUDPermission(Schema.SObjectType.ClusterJobNeighbor__c);
        ClusterAccessCheck.checkCRUDPermission(Schema.SObjectType.ClusterJobResult__c);
        ClusterKMeansJobState state = (ClusterKMeansJobState)this.runner.getJobState();
        Id jobId = state.clusterJob.Id;
        List<ClusterNeighbor> clusterNeighbors = this.runner.findNearestClusters(dataPoint, ClusterConstants.NUM_NEAREST_CLUSTERS);
        List<Integer> nearestClusters = new List<Integer>();
        for (ClusterNeighbor cn:clusterNeighbors) {
            nearestClusters.add(cn.clusterIndex);
        }
        log.debug('Retrieved ' + nearestClusters.size() + ' nearest clusters');
        //We will retrieve MAX_NEIGHBORS neighbors and then return first numNeighbors
        List<ClusterDataPointNeighbor> neighbors = this.findNearestNeighbors(dataPoint, nearestClusters, ClusterConstants.getKNNResultLimit());
        if (String.isNotBlank(dataPoint.externalId) && ClusterConstants.getStoreNearestNeighbors()) {
            List<ClusterJobNeighbor__c> neighborRecords = new List<ClusterJobNeighbor__c>();
            for (ClusterDataPointNeighbor neighbor:neighbors) {
                ClusterJobNeighbor__c neighborRecord = new ClusterJobNeighbor__c();
                neighbor.populateNeighborRecord(neighborRecord);
                neighborRecords.add(neighborRecord);
            }
            //Check again is another future method finished calculations
            Integer count = [SELECT count() FROM ClusterJobNeighbor__c WHERE RecordId__c = :dataPoint.externalId AND ClusterJob__c = :jobId WITH SECURITY_ENFORCED];
            if (count == 0) {
                System.Savepoint sp1 = Database.setSavepoint();
                log.debug('Inserting ' + neighborRecords.size() + ' nearest neighbors');
                insert neighborRecords;

                //Locking records
                List<ClusterJobNeighbor__c> insertedNeighborRecords = [SELECT Id FROM ClusterJobNeighbor__c WHERE RecordId__c = :dataPoint.externalId AND ClusterJob__c = :jobId WITH SECURITY_ENFORCED FOR UPDATE];
                if (insertedNeighborRecords.size() > neighborRecords.size()) {
                    //We retrieved more than inserted. Most likely another future had already calculated NN
                    //Let's rollback what we inserted
                    Database.rollback(sp1);
                }
            }
        }
        if (insertDataPoint && String.isNotBlank(dataPoint.externalId)) {
            //We will insert the source datapoint if specified so it can be found as a neighbor itself
            List<ClusterJobResult__c> jobResults = [SELECT Id FROM ClusterJobResult__c WHERE ClusterJob__c = :state.clusterJob.Id AND RecordId__c = :dataPoint.externalId WITH SECURITY_ENFORCED LIMIT 1];
            if (jobResults.size() == 0) {
                log.debug('Inserting new data point with record id: ' + dataPoint.externalId);
                ClusterJobResult__c jobResult = new ClusterJobResult__c();
                jobResult.RecordId__c = dataPoint.externalId;
                jobResult.RecordName__c = dataPoint.recordName;
                jobResult.ClusterJob__c = state.clusterJob.Id;
                jobResult.ClusterNumber__c = dataPoint.clusterIndex;
                jobResult.Cluster__c = state.jobClusters[dataPoint.clusterIndex].Id;
                ClusterDataHelper.populateClusterJobResultJsonValues(jobResult, this.runner.getSObjectProcessor().serializeValuesToJson(dataPoint.values));
                jobResult.Random__c = ClusterDataHelper.getRandomInt(0, 1000000); //Randomize record order
                jobResult.DistanceToCluster__c = this.runner.calculateDistance(dataPoint.values, state.centroids[dataPoint.clusterIndex].values);
                Integer nextClusterIndex = state.getNextClusterIndex(dataPoint.clusterIndex);
                jobResult.DistanceToNNCluster__c = this.runner.calculateDistance(dataPoint.values, state.centroids[nextClusterIndex].values);
                insert jobResult;
            }
        }
        List<ClusterDataPointNeighbor> firstNeighbors = this.getFirstNeighbors(neighbors, numNeighbors);
        log.debug('Returning ' + firstNeighbors.size() + ' nearest neighbors');
        return firstNeighbors;
    }

    public List<ClusterDataPointNeighbor> getFirstNeighbors(List<ClusterDataPointNeighbor> neighbors, Integer numNeighbors) {
        if (numNeighbors < neighbors.size()) {
            List<ClusterDataPointNeighbor> firstNeighbors = new List<ClusterDataPointNeighbor>();
            for (Integer i=0; i<numNeighbors; i++) {
                firstNeighbors.add(neighbors.get(i));
            }
            return firstNeighbors;
        }
        else {
            return neighbors;
        }
    }

    public virtual List<ClusterDataPointNeighbor> findNearestNeighbors(ClusterDataPoint dataPoint, List<Integer> nearestClusters, Integer numNeighbors) {
        log.debug('Starting nearest neighbors calculation for ' + dataPoint.externalId);
        if (dataPoint.clusterIndex == null) {
            dataPoint.clusterIndex = nearestClusters.get(0);
        }
        ClusterKMeansJobState jobState = (ClusterKMeansJobState)this.runner.getJobState();
        List<ClusterDataPoint> nearestDataPoints = new List<ClusterDataPoint>();
        Boolean hasNearestCentroids = jobState.hasNearestCentroids();
        Integer centroidSize = jobState.centroids.size();        
        //Getting nearest data points in nearest clusters
        Double currentCentroidDistance;
        for (Integer i = 0; i < nearestClusters.size(); i++) {
            Double distance = this.runner.calculateDPDistance(dataPoint, jobState.centroids[nearestClusters[i]]);
            if (dataPoint.clusterIndex == nearestClusters[i]) {
                currentCentroidDistance = distance;
            }
            Integer nextClusterIndex = jobState.getNextClusterIndex(nearestClusters[i]);
            Double nextClusterDistance = this.runner.calculateDPDistance(dataPoint, jobState.centroids[nextClusterIndex]);
            nearestDataPoints.addAll(this.getRandomDataPoints(this.maxNNSearchChunkCount, nearestClusters[i], distance, nextClusterDistance, jobState));
        }
        //Also getting random datapoints from the same cluster which have less distance to center than current dataPoint
        nearestDataPoints.addAll(getRandomDataPoints(this.maxNNSearchChunkCount, dataPoint.clusterIndex, currentCentroidDistance));
        //Also getting other random datapoints from the same cluster
        nearestDataPoints.addAll(getRandomDataPoints(this.maxNNSearchChunkCount, dataPoint.clusterIndex, null, null, jobState));
        log.debug('Retrieved ' + nearestDataPoints.size() + ' nearest data points from ' + nearestClusters.size() + ' nearest clusters');

        List<ClusterDataPointNeighbor> neighbors = new List<ClusterDataPointNeighbor>();
        Set<String> processedDpIds = new Set<String>();
        for (ClusterDataPoint nearestDP:nearestDataPoints) {
            //Excluding already processed and self datapoints
            if (!processedDpIds.contains(nearestDP.recordId) && (dataPoint.externalId != nearestDP.externalId)) {
                ClusterDataPointNeighbor neighbor = new ClusterDataPointNeighbor();
                neighbor.externalRecordId = dataPoint.externalId;
                neighbor.neighborDataPoint = nearestDP;
                neighbor.neighborExternalRecordId = nearestDP.externalId;
                neighbor.distance = this.runner.calculateDPDistance(dataPoint, nearestDP);
                //Checking if this neightbor is in the neighborhood
                if (neighbor.distance < ClusterConstants.KNN_NEIGHBORHOOD_DISTANCE) {                    
                    neighbor.jobId = jobState.clusterJob.Id;            
                    neighbors.add(neighbor);
                }
                processedDpIds.add(nearestDP.recordId);
            }
            //Checking NN search limits
            if (neighbors.size() > this.maxNNSearchCount) {
                break;
            }
        }
        //Sorting based on distance and retrieving first numNeighbors
        neighbors.sort();
        List<ClusterDataPointNeighbor> kNeighbors = new List<ClusterDataPointNeighbor>();
        Integer numItems = Math.min(numNeighbors, neighbors.size());
        for (Integer i = 0; i < numItems; i++) {
            kNeighbors.add(neighbors.get(i));
        }
        log.debug('Found ' + kNeighbors.size() + ' nearest neighbors');
        return kNeighbors;
    }

    
    public List<ClusterDataPointNeighbor> getNearestNeighborsFromDb(Id recordId, Id jobId) {
        return this.getNearestNeighborsFromDb(recordId, jobId, ClusterConstants.MAX_NEIGHBORS);
    }

    public List<ClusterDataPointNeighbor> getNearestNeighborsFromDb(Id recordId, Id jobId, Integer numNeighbors) {
        ClusterJobState jobState = this.runner.getJobState();
        List<ClusterDataPointNeighbor> nearestNeighbors = new List<ClusterDataPointNeighbor>();
        List<ClusterJobNeighbor__c> neighbors = [SELECT Id, ClusterJob__c, ClusterJobResult__c, Distance__c, NeighborRecordId__c, RecordId__c,
            ClusterJobResult__r.Id, ClusterJobResult__r.Name, ClusterJobResult__r.Cluster__c, ClusterJobResult__r.ClusterJob__c, ClusterJobResult__r.ClusterName__c,
            ClusterJobResult__r.ClusterNumber__c, ClusterJobResult__r.DistanceToCluster__c, ClusterJobResult__r.DistanceToNNCluster__c, ClusterJobResult__r.Json__c, ClusterJobResult__r.Json2__c,
            ClusterJobResult__r.Json3__c, ClusterJobResult__r.Json4__c, ClusterJobResult__r.Json5__c, ClusterJobResult__r.Random__c, ClusterJobResult__r.RecordId__c, ClusterJobResult__r.RecordName__c
            FROM ClusterJobNeighbor__c WHERE RecordId__c = :String.valueOf(recordId) AND ClusterJob__c = :jobId WITH SECURITY_ENFORCED ORDER BY Distance__c];
        ClusterJobResult__c[] jobResults = new ClusterJobResult__c[1];
        Set<String> neighborIds = new Set<String>();
        if (neighbors.size() > 0) {
            log.debug('Retrieved ' + neighbors.size() + ' previously calculated neighbors');
            for (ClusterJobNeighbor__c neighbor:neighbors) {
                //Dupes are possible if 2 users run KNN simultaniously on the same record Id.
                //We will dedupe them here for now
                if (!neighborIds.contains(neighbor.NeighborRecordId__c) && (neighbor.ClusterJobResult__r != null) && (neighbor.ClusterJobResult__r.RecordId__c != recordId)) {
                    jobResults[0] = neighbor.ClusterJobResult__r;                    
                    ClusterDataPoint[] dataPoints = ClusterDataHelper.getDataPoints(jobResults, jobState);
                    ClusterDataPointNeighbor nearestNeighbor = new ClusterDataPointNeighbor(neighbor);
                    if (dataPoints.size() > 0) {
                        nearestNeighbor.neighborDataPoint = dataPoints[0];
                    }
                    nearestNeighbors.add(nearestNeighbor);
                    neighborIds.add(neighbor.NeighborRecordId__c);
                    if (nearestNeighbors.size() >= numNeighbors) {
                        break;
                    }
                }
            }
        }
        log.debug('Returning ' + numNeighbors + ' neighbors');
        return nearestNeighbors;
    }

    public void deleteNearestNeighbors(Id recordId, Id jobId) {
        ClusterAccessCheck.checkCRUDPermission(Schema.SObjectType.ClusterJobNeighbor__c);        
        List<ClusterJobNeighbor__c> neighbors = [SELECT Id FROM ClusterJobNeighbor__c WHERE RecordId__c = :String.valueOf(recordId) AND ClusterJob__c = :jobId WITH SECURITY_ENFORCED];
        if (neighbors.size() > 0) {
            delete neighbors;
            log.debug('Deleted ' + neighbors.size() + ' nearest neighbors for record ' + recordId);
        }
    }

    public ClusterDataPoint[] getRandomDataPoints(Integer count, Integer clusterIndex, Double distanceToCenter, Double distanceToNextCluster, ClusterJobState jobState) {
        log.debug('Retrieving nearest random data points in cluster ' + clusterIndex + ', distanceToCenter: ' + distanceToCenter + ', distanceToNextCluster: ' + distanceToNextCluster);
        ClusterAccessCheck.checkReadPermission(Schema.SObjectType.ClusterJobResult__c);
        List<ClusterJobResult__c> jobResults = null;
        if (distanceToCenter != null) {
            Double[] distanceTolerances = new Double[10];
            distanceTolerances[0] = 0.001;  //0.1%
            distanceTolerances[1] = 0.002;  //0.2%
            distanceTolerances[2] = 0.004;  //0.4%
            distanceTolerances[3] = 0.008;  //0.8%
            distanceTolerances[4] = 0.01; //1%
            distanceTolerances[5] = 0.02; //2%
            distanceTolerances[6] = 0.04; //4%
            distanceTolerances[7] = 0.05; //5%
            distanceTolerances[8] = 0.1; //10%
            distanceTolerances[9] = 0.25; //25%
            for (Integer i=0; i<distanceTolerances.size(); i++) {
                Decimal distanceMin = Decimal.valueOf(distanceToCenter - distanceToCenter * distanceTolerances[i]);
                Decimal distanceMax = Decimal.valueOf(distanceToCenter + distanceToCenter * distanceTolerances[i]);
                Decimal nextDistanceMin = Decimal.valueOf(distanceToNextCluster - distanceToCenter * distanceTolerances[i]);
                Decimal nextDistanceMax = Decimal.valueOf(distanceToNextCluster + distanceToCenter * distanceTolerances[i]);
                //We are trying to retrieve results with similar distanceToCenter value to reduce KNN calculations
                //Here we are looking for an intersection of the current and nearest clusters
                jobResults = [SELECT Id, Cluster__c, Json__c, Json2__c, Json3__c, Json4__c, Json5__c, RecordId__c, RecordName__c, ClusterNumber__c, ClusterJob__c, DistanceToCluster__c, DistanceToNNCluster__c 
                    FROM ClusterJobResult__c WHERE ClusterJob__c = :jobState.clusterJob.Id AND ClusterNumber__c = :clusterIndex 
                    AND (DistanceToCluster__c >= :distanceMin AND DistanceToCluster__c<= :distanceMax AND DistanceToNNCluster__c<=:nextDistanceMax AND DistanceToNNCluster__c>=:nextDistanceMin) 
                    ORDER BY DistanceToCluster__c DESC LIMIT :count];
                if (jobResults.size() >= this.knnNumber) {
                    log.debug('Retrieved ' + jobResults.size() + ' nearest data points with tolerance ' + distanceTolerances[i]);
                    log.debug('distanceMin: ' + distanceMin + ', distanceMax: ' + distanceMax + ', nextDistanceMax: ' + nextDistanceMax);
                    break;
                }            
            }
        }
        //If we failed to get nearest results or if distanceToCenter is null
        if (distanceToCenter == null || jobResults == null || jobResults.size() == 0) {
            jobResults = [SELECT Id, Cluster__c, Json__c, Json2__c, Json3__c, Json4__c, Json5__c, RecordId__c, RecordName__c, ClusterNumber__c, ClusterJob__c, DistanceToCluster__c, DistanceToNNCluster__c 
                FROM ClusterJobResult__c WHERE ClusterJob__c = :jobState.clusterJob.Id AND ClusterNumber__c = :clusterIndex ORDER BY Random__c LIMIT :count];
        }
        log.debug('Retrieved ' + jobResults.size() + ' nearest random data points in cluster ' + clusterIndex);
        return ClusterDataHelper.getDataPoints(jobResults, jobState);
    }

    public ClusterDataPoint[] getRandomDataPoints(Integer count, Integer clusterIndex, Double distanceToCenter) {
        log.debug('Retrieving nearest random data points in cluster ' + clusterIndex + ' with radius ' + distanceToCenter);
        ClusterJobState jobState = this.runner.getJobState();
        ClusterAccessCheck.checkReadPermission(Schema.SObjectType.ClusterJobResult__c);
        List<ClusterJobResult__c> jobResults = null;
        //We are trying to retrieve results with similar distanceToCenter value to reduce KNN calculations
        jobResults = [SELECT Id, Cluster__c, Json__c, Json2__c, Json3__c, Json4__c, Json5__c, RecordId__c, RecordName__c, ClusterNumber__c, ClusterJob__c, DistanceToCluster__c, DistanceToNNCluster__c 
            FROM ClusterJobResult__c WHERE ClusterJob__c = :jobState.clusterJob.Id AND ClusterNumber__c = :clusterIndex 
            AND DistanceToCluster__c<= :distanceToCenter 
            ORDER BY DistanceToCluster__c DESC LIMIT :count];
        log.debug('Retrieved ' + jobResults.size() + ' nearest random data points in cluster ' + clusterIndex);
        return ClusterDataHelper.getDataPoints(jobResults, jobState);
    }


}
