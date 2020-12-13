public with sharing class ClusterKNNPredictor {
    public static Logger log = LogFactory.getLogger();

    ClusterAlgorithmRunner runner;
    
    public ClusterKNNPredictor() {

    }

    public ClusterKNNPredictor(ClusterAlgorithmRunner runner) {
        this.setRunner(runner);
    }

    public void setRunner(ClusterAlgorithmRunner runner) {
        this.runner = runner;
    }

    public ClusterPredictionResult predict(Id recordId, String jobStateJson) {
        this.runner.setJobState(jobStateJson);
        return this.predict(recordId);
    }

    public ClusterPredictionResult predict(Id dpRecordId) {
        ClusterDataPoint dataPoint = this.runner.getDataPoint(dpRecordId);
        return this.predict(dataPoint);
    }

    public virtual ClusterPredictionResult predict(ClusterDataPoint dataPoint) {
        log.debug('Starting prediction calculations for ' + dataPoint.recordName);
        ClusterJobState jobState = this.runner.getJobState();
        List<ClusterDataPointNeighbor> nearestNeighbors = this.getNearestNeighborsFromDb(dataPoint.externalId, jobState.clusterJob.Id, ClusterConstants.NUM_NEAREST_NEIGHBORS_PREDICTION);
        if (nearestNeighbors.size() == 0) {
            nearestNeighbors = this.findNearestNeighbors(dataPoint.externalId, ClusterConstants.NUM_NEAREST_NEIGHBORS_PREDICTION);
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
        log.debug(JSON.serialize(clusterPrediction));
        predictionResult.clusterIndex = Integer.valueOf(clusterPrediction.fieldValuePredictions[0].value);
        return predictionResult;
    }

    public List<ClusterDataPointNeighbor> findNearestNeighbors(Id recordId, List<Integer> nearestClusters, Integer numNeighbors) {
        ClusterDataPoint dataPoint = this.runner.getDataPoint(recordId);
        return this.findNearestNeighbors(dataPoint, nearestClusters, numNeighbors);
    }

    public List<ClusterDataPointNeighbor> findNearestNeighbors(Id recordId, Integer numNeighbors) {
        log.debug('Starting k nearest neighbor calculations for record id: ' + recordId);
        ClusterJobState state = this.runner.getJobState();
        Id jobId = state.clusterJob.Id;
        ClusterAccessCheck.checkCRUDPermission(Schema.SObjectType.ClusterJobNeighbor__c);
        List<ClusterNeighbor> clusterNeighbors = this.runner.findNearestClusters(recordId, ClusterConstants.NUM_NEAREST_CLUSTERS);
        List<Integer> nearestClusters = new List<Integer>();
        for (ClusterNeighbor cn:clusterNeighbors) {
            nearestClusters.add(cn.clusterIndex);
        }
        log.debug('Retrieved ' + nearestClusters.size() + ' nearest clusters');
        //We will retrieve MAX_NEIGHBORS neighbors and then return first numNeighbors
        List<ClusterDataPointNeighbor> neighbors = this.findNearestNeighbors(recordId, nearestClusters, ClusterConstants.MAX_NEIGHBORS);
        List<ClusterJobNeighbor__c> neighborRecords = new List<ClusterJobNeighbor__c>();
        for (ClusterDataPointNeighbor neighbor:neighbors) {
            ClusterJobNeighbor__c neighborRecord = new ClusterJobNeighbor__c();
            neighbor.populateNeighborRecord(neighborRecord);
            neighborRecords.add(neighborRecord);
        }
        //Check again is another future method finished calculations
        Integer count = [SELECT count() FROM ClusterJobNeighbor__c WHERE RecordId__c = :String.valueOf(recordId) AND ClusterJob__c = :jobId WITH SECURITY_ENFORCED];
        if (count == 0) {
            log.debug('Inserting ' + neighborRecords.size() + ' nearest neighbors');
            insert neighborRecords;
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
        //Getting nearest data points in nearest clusters
        for (Integer i = 0; i < nearestClusters.size(); i++) {
            Double distance = this.runner.calculateDPDistance(dataPoint, jobState.centroids[nearestClusters[i]]);
            nearestDataPoints.addAll(this.getRandomDataPoints(ClusterConstants.MIN_KNN_DP_COUNT, nearestClusters[i], distance, jobState));
        }
        //Also getting random datapoints from the same cluster
        nearestDataPoints.addAll(getRandomDataPoints(ClusterConstants.MIN_KNN_DP_COUNT, dataPoint.clusterIndex, null, jobState));
        log.debug('Retrieved ' + nearestDataPoints.size() + ' nearest data points from ' + nearestClusters.size() + ' nearest clusters');

        List<ClusterDataPointNeighbor> neighbors = new List<ClusterDataPointNeighbor>();
        Set<String> processedDpIds = new Set<String>();
        for (ClusterDataPoint nearestDP:nearestDataPoints) {
            if (!processedDpIds.contains(nearestDP.recordId)) {
                ClusterDataPointNeighbor neighbor = new ClusterDataPointNeighbor();
                neighbor.externalRecordId = dataPoint.externalId;
                neighbor.neighborDataPoint = nearestDP;
                neighbor.neighborExternalRecordId = nearestDP.externalId;
                neighbor.distance = this.runner.calculateDPDistance(dataPoint, nearestDP);
                neighbor.jobId = jobState.clusterJob.Id;            
                neighbors.add(neighbor);
                processedDpIds.add(nearestDP.recordId);
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
            ClusterJobResult__r.ClusterNumber__c, ClusterJobResult__r.DistanceToCluster__c, ClusterJobResult__r.Json__c, ClusterJobResult__r.Json2__c,
            ClusterJobResult__r.Json3__c, ClusterJobResult__r.Json4__c, ClusterJobResult__r.Json5__c, ClusterJobResult__r.Random__c, ClusterJobResult__r.RecordId__c, ClusterJobResult__r.RecordName__c
            FROM ClusterJobNeighbor__c WHERE RecordId__c = :String.valueOf(recordId) AND ClusterJob__c = :jobId WITH SECURITY_ENFORCED];
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

    public ClusterDataPoint[] getRandomDataPoints(Integer count, Integer clusterIndex, Double distanceToCenter, ClusterJobState jobState) {
        log.debug('Retrieving nearest random data points in cluster ' + clusterIndex);
        ClusterAccessCheck.checkReadPermission(Schema.SObjectType.ClusterJobResult__c);
        List<ClusterJobResult__c> jobResults = null;
        if (distanceToCenter != null) {
            Double[] distanceTolerances = new Double[3];
            distanceTolerances[0] = distanceToCenter * 0.1;  //10%
            distanceTolerances[1] = distanceToCenter * 0.25; //25%
            distanceTolerances[2] = distanceToCenter * 0.50; //50%
            for (Integer i=0; i<distanceTolerances.size(); i++) {
                Decimal distanceMin = Decimal.valueOf(distanceToCenter - distanceTolerances[i]);
                Decimal distanceMax = Decimal.valueOf(distanceToCenter + distanceTolerances[i]);
                //We are trying to retrieve results with similar distanceToCenter value to reduce KNN calculations
                jobResults = [SELECT Id, Cluster__c, Json__c, Json2__c, Json3__c, Json4__c, Json5__c, RecordId__c, RecordName__c, ClusterNumber__c, ClusterJob__c, DistanceToCluster__c 
                    FROM ClusterJobResult__c WHERE ClusterJob__c = :jobState.clusterJob.Id AND ClusterNumber__c = :clusterIndex AND (DistanceToCluster__c >= :distanceMin AND DistanceToCluster__c<= :distanceMax) ORDER BY Random__c LIMIT :count];
                if (jobResults.size() > ClusterConstants.MIN_KNN_NEIGHBOR_SIZE) {
                    break;
                }            
            }
        }
        //If we failed to get nearest results or if distanceToCenter is null
        if (distanceToCenter == null || jobResults == null || jobResults.size() == 0) {
            jobResults = [SELECT Id, Cluster__c, Json__c, Json2__c, Json3__c, Json4__c, Json5__c, RecordId__c, RecordName__c, ClusterNumber__c, ClusterJob__c, DistanceToCluster__c 
                FROM ClusterJobResult__c WHERE ClusterJob__c = :jobState.clusterJob.Id AND ClusterNumber__c = :clusterIndex ORDER BY Random__c LIMIT :count];
        }
        log.debug('Retrieved ' + jobResults.size() + ' nearest random data points in cluster ' + clusterIndex);
        return ClusterDataHelper.getDataPoints(jobResults, jobState);
    }



}
