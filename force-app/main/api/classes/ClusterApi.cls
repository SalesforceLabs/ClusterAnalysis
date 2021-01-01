/*
 * Cluster public API
 *
 * @author: Iskander Mukhamedgaliyev
 */
global with sharing class ClusterApi {
    private ClusterAlgorithmRunner runner = null;
    global ClusterApi() {

    }

    private void checkRunnerInitialized() {
        if (this.runner == null) {
            throw new ClusterException('Job or model id was not set. Call setModelOrJobId first');
        }
    }

    global void setModelOrJobId(string modelOrJobId) {
        //TODO: We're using UI controller here, refactor to use ClusterJobManager instead
        ClusterPredictController.ClusterModelJob modelJob = ClusterPredictController.getModelJob(modelOrJobId);
        Id jobId = modelJob.jobId;
        this.runner = ClusterAlgorithmFactory.getRunnerFromJobId(jobId);
    }

    /**
     * Predicts field values for the specified record
     * @param recordId
     *        Id of the record to predict
     * @param insertDataPoint
     *        Specifies whether to store data of the specified record so it can be used in further predictions
     * @returns ClusterPredictionResult with calculated field predictions
     */
    global ClusterPredictionResult predict(Id dpRecordId, Boolean insertDataPoint) {
        this.checkRunnerInitialized();
        ClusterDataPoint dataPoint = this.runner.getDataPoint(dpRecordId);
        return this.predict(dataPoint, insertDataPoint);
    }

    /**
     * Predicts field values for the specified record
     * @param dataPoint
     *        ClusterDataPoint object which contains record data
     * @param insertDataPoint
     *        Specifies whether to store the data of the specified record so it can be used in further predictions
     * @returns ClusterPredictionResult with calculated field predictions
     */
    global ClusterPredictionResult predict(ClusterDataPoint dataPoint, Boolean insertDataPoint) {
        this.checkRunnerInitialized();
        return this.runner.getPredictor().predict(dataPoint, insertDataPoint);
    }

    /**
     * Retrieves previously calculated nearest neighbors from the database
     * @param recordId
     *        Id of the source record
     * @param numNeighbors
     *        Number of neighbors to retrieve
     * @returns List<ClusterDataPointNeighbor> with populated nearest neighbors
     */
    global List<ClusterDataPointNeighbor> getNearestNeighborsFromDb(Id recordId, Integer numNeighbors) {
        this.checkRunnerInitialized();
        return this.runner.getPredictor().getNearestNeighborsFromDb(recordId, runner.getJobState().clusterJob.id, numNeighbors);
    }

    
    /**
     * Finds (calculates) nearest neighbors and stores calculations in the db
     * @param recordId
     *        Id of the source record
     * @param numNeighbors
     *        Number of neighbors to find
     * @param insertDataPoint
     *        Specifies whether to store the data of the specified record so it can be used in further predictions
     * @returns List<ClusterDataPointNeighbor> with populated nearest neighbors
     */
    global List<ClusterDataPointNeighbor> findNearestNeighbors(Id recordId, Integer numNeighbors, Boolean insertDataPoint) {
        this.checkRunnerInitialized();
        return this.runner.getPredictor().findNearestNeighbors(recordId, numNeighbors, insertDataPoint);
    }

    /**
     * Calculates distance between 2 vectors using current job state
     * @returns distance value, distance function is chosen based on cluster model configuration
     */
    global Double calculateDistance(Object[] vectorA, Object[] vectorB) {
        this.checkRunnerInitialized();
        return this.runner.calculateDistance(vectorA, vectorB);    
    }

    /**
     * Loads a record from the cluster object and converts it to a data point
     * @param externalRecordId
     *        Record id of the record to load
     * @returns ClusterDataPoint object with loaded and converted data
     */
    global ClusterDataPoint getDataPoint(Id externalRecordId) {
        this.checkRunnerInitialized();
        return this.runner.getDataPoint(externalRecordId);
    }


}
