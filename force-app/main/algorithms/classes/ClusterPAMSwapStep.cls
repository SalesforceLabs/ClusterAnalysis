/*
 * PAM (K-medoids) swap step - swap centroids and calculate cost
 *
 * @author: Iskander Mukhamedgaliyev
 */
public with sharing class ClusterPAMSwapStep extends ClusterIterableBase {
    private Double[] minCentroidCosts;
    private ClusterDataPoint[] minCentroids;
    private Double totalMinCost;

    public ClusterPAMSwapStep() {

    }

    public ClusterPAMSwapStep(Integer batchSize) {
        super(batchSize);
    }

    public override Integer getBatchSize() {
        ClusterKMeansJobState jobState = (ClusterKMeansJobState)runner.getJobState();
        Integer bs = super.getBatchSize();
        if (jobState.iterationsCount < 2) {
            Integer denom = jobState.model.hasLongTextFields() ? 4 : 2;
            bs = bs / denom; //Reducing batch size for initial swap operation, distance cache is mostly empty at this stage
            if (bs == 0) {
                bs = 1;
            }
        }
        return bs;
    }

    public override void init(ClusterAlgorithmRunner runner) {
        ClusterIterableBase.log.debug('Starting PAM swap step');
        super.init(runner);
        ClusterKMeansJobState jobState = (ClusterKMeansJobState)runner.getJobState();
        this.minCentroidCosts = new Double[jobState.model.numberOfClusters];
        this.minCentroids = new ClusterDataPoint[jobState.model.numberOfClusters];
        this.totalMinCost = 0;
        //Initializing cluster assignment matrix
        for (Integer i = 0; i<jobState.centroids.size(); i++) {
            this.minCentroids[i] = jobState.centroids[i];
            this.minCentroidCosts[i] = jobState.centroids[i].cost;
            totalMinCost += this.minCentroidCosts[i];
        }
        jobState.hasSwapped = false;
    }

    protected override Object[] getRecords() {
        return ((ClusterKMeansJobState)this.runner.getJobState()).dataPoints;
    }
    
    public override void processRecords(Database.BatchableContext bc, Object[] scope) {
        ClusterDataPoint[] dataPoints = (ClusterDataPoint[])scope;
        ClusterKMeansJobState jobState = (ClusterKMeansJobState)this.runner.getJobState();
        ClusterModelWrapper model = jobState.model;
        Integer scopeSize = scope.size();
        List<ClusterDataPoint> centroids = jobState.centroids;
        Integer centroidSize = centroids.size();
        Double[] centroidCosts = new Double[centroidSize];
        List<ClusterDataPoint> allDataPoints = jobState.dataPoints;
        ClusterDataPoint[] newCentroids = new ClusterDataPoint[centroidSize];
        jobState.iterationsCount++;
        for (Integer sindex = 0; sindex < scopeSize; sindex++){
            ClusterDataPoint currentRecord = dataPoints[sindex];
            ClusterDataPoint currentMedoid;
            if (currentRecord.clusterIndex == null) {
                currentMedoid = currentRecord;
            }
            else {
                currentMedoid = centroids[currentRecord.clusterIndex];
            }
            if (currentRecord.recordId == currentMedoid.recordId) continue;           
            //Cloning and swapping centroids
            for (Integer i=0; i<centroidSize; i++) {
                centroidCosts[i] = 0;
                newCentroids[i] = centroids[i];
            }
            newCentroids[currentRecord.clusterIndex] = currentRecord;
            for (Integer dpindex = 0; dpindex < allDataPoints.size(); dpindex++) {
                if (allDataPoints[dpindex].recordId == currentRecord.recordId) continue;
                ClusterDataPoint currentObject = allDataPoints[dpindex];
                //Finding the nearest centroid and min distance
                //TODO: since this is almost the same logic as in PAM data assignment step repeating it is not needed if we remember assignment and cost here
                //This however will require more memory
                Integer nearestCentroidIndex = 0;
                Boolean isCentroid = false;
                Double minDistance = Math.abs(this.runner.calculateDPDistance(currentObject, newCentroids[nearestCentroidIndex]));
                for (Integer cindex = 1; cindex < centroidSize; cindex++) {
                    isCentroid = newCentroids[cindex].recordId == allDataPoints[dpindex].recordId;
                    if (isCentroid)
                        break;
                    Double distance = Math.abs(this.runner.calculateDPDistance(currentObject, newCentroids[cindex]));
                    if (distance < minDistance) {
                        minDistance = distance;
                        nearestCentroidIndex = cindex;
                    }
                }
                //Accumulating new cost per centroid
                if (!isCentroid) {
                    centroidCosts[nearestCentroidIndex] += minDistance;
                }
            }
            //Calculating total new centroid cost
            Double totalNewCost = 0;
            for (Integer i=0; i<centroidSize; i++) {
                totalNewCost += centroidCosts[i];
            }
            //If new cost is less than current remember this
            if (totalNewCost < totalMinCost) {
                ClusterIterableBase.log.debug('Current min cost: ' + totalMinCost + ', new min cost ' + totalNewCost);
                for (Integer i=0; i<centroidSize; i++) {
                    this.minCentroidCosts[i] = centroidCosts[i];
                }
                this.minCentroids[currentRecord.clusterIndex] = currentRecord;
                totalMinCost = totalNewCost;
                ClusterIterableBase.log.debug('Swapping centroid' + currentRecord.clusterIndex + ' to ' + currentRecord.clusterIndex);
                //Set hasSwapped flag to repeat data data assignment and swap steps again
                jobState.hasSwapped = true;
            }
        }
    }

    public override void done(){
        ClusterKMeansJobState jobState = (ClusterKMeansJobState)this.runner.getJobState();
        //Perform swap to the minimal configuration
        if (jobState.hasSwapped) {
            ClusterIterableBase.log.debug('Swapping centroids');
            jobState.centroids = this.minCentroids;
        }
        //Clear variables to reduce state
        this.minCentroidCosts = null;
        this.minCentroids = null;
        super.done();
    }
}