/*
 * K-Medoids PAM (CLARA approach) algorithm runner
 *
 * @author: Iskander Mukhamedgaliyev
 */
 public with sharing class ClusterKMedoidsPAMRunner extends ClusterAlgorithmRunner {
    ClusterKMeansJobState state;
    Integer dataAssignmentStepIndex;
    Integer dataSwapStepIndex;
    Boolean runRefinementStep = true;
    public ClusterKMedoidsPAMRunner() {

    }

    public override ClusterAlgorithmRunner.ModelValidationResult validateModel(ClusterModelWrapper model) {
        ModelValidationResult result = super.validateModel(model);
        if ((model.numberOfClusters < 2) || (model.parameters != null && model.parameters.size() > 0 && Integer.valueOf(model.parameters.get('numberOfClusters')) < 2)) {
            result.isValid = false;
            result.messages.add('The number of result clusters cannot be less than 2');
        }
        return result;
    }

    public override void init(ClusterModelWrapper model) {
        this.steps.clear();
        this.state = (ClusterKMeansJobState)this.createJobState();
        this.state.model = model;
        model.numberOfClusters = Integer.valueOf(model.parameters.get('numberOfClusters'));
        model.distanceFunction = ClusterConstants.DISTANCE_GOWER;
        Boolean hasLongTextFields = model.hasLongTextFields();
        if (model.parameters.containsKey('runRefinementStep')) {
            this.runRefinementStep = !model.hasLongTextFields() && Boolean.valueOf(model.parameters.get('runRefinementStep'));
        }
        else {
            this.runRefinementStep = false;
        }
        //Initializing steps
        Integer kMedoidsBatchSize = Test.isRunningTest() ? ClusterConstants.TEST_BATCH_SIZE : 
            hasLongTextFields ? ClusterConstants.getKMedoidsLongTextBatchSize() : ClusterConstants.getKMedoidsBatchSize();
        ClusterPrepareDataStep step1 = new ClusterPrepareDataStep();
        this.steps.add(step1);
        ClusterInitCentroidsStep step2 = new ClusterInitCentroidsStep(true);
        this.steps.add(step2);
        ClusterPAMDataAssignmentStep step3 = new ClusterPAMDataAssignmentStep(ClusterConstants.getKMedoidsSwapBatchSize());
        this.steps.add(step3);
        this.dataAssignmentStepIndex = this.steps.size() - 1;
        ClusterPAMSwapStep step4 = new ClusterPAMSwapStep(kMedoidsBatchSize);
        this.steps.add(step4);
        this.dataSwapStepIndex = this.steps.size() - 1;
        Integer swapBatchSize = hasLongTextFields ? ClusterConstants.getKMedoidsLongTextBatchSize() : ClusterConstants.getKMedoidsSwapBatchSize();
        if (this.runRefinementStep) {
            ClusterSilhouetteRefinementStep step5 = new ClusterSilhouetteRefinementStep(swapBatchSize);
            this.steps.add(step5);
        }
        ClusterCentroidDataAssignmentStep step6 = new ClusterCentroidDataAssignmentStep(true, false, false, this.runRefinementStep);
        this.steps.add(step6);
        ClusterSilhouetteScoreStep step7 = new ClusterSilhouetteScoreStep(swapBatchSize);
        this.steps.add(step7);
        super.init(model);
    }

    public override void initializeDistanceCache() {
        this.distanceCacheManager = new ClusterIndexDistanceCacheManager(this.state.dataPoints.size());
    }

    public override ClusterJobState createJobState() {
        ClusterKMeansJobState newState = new ClusterKMeansJobState();
        newState.currentAlgorithmStep = 0;
        newState.iterationsCount = 0;
        return newState;
    }

    public override ClusterJobState getJobState() {
        return this.state;
    }

    public override void setJobState(ClusterJobState state) {
        this.state = (ClusterKMeansJobState)state;
    }

    public override void start() {        
        super.start();
    }

    public override Boolean prepareNextStep() {
        if (this.state.currentAlgorithmStep >= this.steps.size() - 1) {
            ClusterJobManager.saveJobState(state, ClusterConstants.JOBSTATUS_COMPLETED, '');
            return true;
        }
        if (this.state.currentAlgorithmStep == this.dataAssignmentStepIndex) {
            if (this.state.iterationsCount > ClusterConstants.getMaxSwapIterations()) {
                //If swap has happened too many times we will stop swapping
                ClusterIterableBase.log.debug('Maximum number of iterations reached, finishing centroid reassignment cycle');
                this.state.currentAlgorithmStep = this.dataSwapStepIndex + 1; //Go to next step after swap
            }
            else {
                //After the data assignment step we need to do the data swap step
                this.state.iterationsCount++;
                this.state.currentAlgorithmStep = this.dataSwapStepIndex;
            }
        }
        else if (this.state.currentAlgorithmStep == this.dataSwapStepIndex) {
            if (!this.state.hasSwapped) {
                //Medoids are stable, no swap happened
                ClusterIterableBase.log.debug('Medoids are stable, finishing centroid reassignment cycle');
                this.state.currentAlgorithmStep = this.dataSwapStepIndex + 1; //Go to next step after swap
            }
            else {
                //If medoids were changed during data swap step we need to repeat data assignment and data swap steps
                this.state.currentAlgorithmStep = this.dataAssignmentStepIndex;
            }
        }
        else {
            this.state.currentAlgorithmStep = this.state.currentAlgorithmStep + 1;
        }
        return false;
    }

    public override Double calculateDistance(Object[] currentObject, Object[] centroid) {
        return ClusterDataHelper.calculateGowerDistance(currentObject, centroid, this.state);
    }

    public override ClusterAlgorithmParameter[] getParameters(ClusterModelWrapper model) {
        List<ClusterAlgorithmParameter> parameters = new List<ClusterAlgorithmParameter>();
        Object clusterNumber = model == null ? 4 : model.numberOfClusters;
        parameters.add(new ClusterAlgorithmParameter('numberOfClusters', 'Number of clusters', ClusterAlgorithmParameter.ParameterType.INTEGER_PARAMETER, clusterNumber, null));
        parameters.add(new ClusterAlgorithmParameter('runRefinementStep', 'Run cluster refinement', ClusterAlgorithmParameter.ParameterType.BOOLEAN_PARAMETER, true, null));
        return parameters;
    }

    public override List<ClusterNeighbor> findNearestClusters(ClusterDataPoint dataPoint, Integer numNeighbors) {
        return ClusterDataHelper.findNearestClusters(dataPoint, numNeighbors, this);
    }

    public override List<ClusterDataPointNeighbor> findNearestNeighbors(ClusterDataPoint dataPoint, List<Integer> nearestClusters, Integer numNeighbors) {
        return ClusterDataHelper.findNearestNeighbors(dataPoint, nearestClusters, numNeighbors, this);
    }
}