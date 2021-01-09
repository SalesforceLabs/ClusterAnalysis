@isTest
public with sharing class ClusterKMedoidsPAMRunnerTest {

    @TestSetup
    static void createLeads(){
        List<sObject> leads = Test.loadData(Lead.sObjectType, 'ClustanLeadsMock');
    }

    @isTest
    public static void testKMedoids() {
        String modelJson = '{"algorithm":"K-Medoids","fields":[{"name":"AnnualRevenue","displayLabel":"Annual Revenue","relationName":"","objectName":"Lead","distanceType":"Numeric","weight":1},{"name":"Id","displayLabel":"Lead ID","relationName":"","objectName":"Lead","distanceType":"None","weight":1},{"name":"Industry","displayLabel":"Industry","relationName":"","objectName":"Lead","distanceType":"Category","weight":1},{"name":"Name","displayLabel":"Full Name","relationName":"","objectName":"Lead","distanceType":"None","weight":1},{"name":"NumberOfEmployees","displayLabel":"Employees","relationName":"","objectName":"Lead","distanceType":"Numeric","weight":1},{"name":"Rating","displayLabel":"Rating","relationName":"","objectName":"Lead","distanceType":"Category","weight":1},{"name":"Title","displayLabel":"Title","relationName":"","objectName":"Lead","distanceType":"Text","weight":1}],"filter":"{\\"expressionFields\\":[],\\"customLogic\\":\\"\\"}","isCustomSoql":false,"name":"LeadsUnitTest","numberOfClusters":5,"objectName":"Lead","soql":"SELECT AnnualRevenue, Id, Industry, Name, NumberOfEmployees, Rating, Title FROM Lead LIMIT 50"}';
        ClusterModelWrapper model = ClusterTestData.createModel(modelJson);
        User clusterUser = ClusterTestData.createClusterUser();
        System.runAs(clusterUser) {
            ClusterKMedoidsPAMRunner runner = (ClusterKMedoidsPAMRunner)ClusterAlgorithmFactory.getRunner(model);
            model.parameters.put('numberOfClusters', 5);
            model.parameters.put('runRefinementStep', true);
            runner.init(model);
            Test.startTest();
            runner.start();
            Test.stopTest();
            ClusterKMeansJobState state = (ClusterKMeansJobState)ClusterAlgorithmRunner.jobState;
            String stateJson = ClusterJobManager.loadJobState(state.clusterJob.Id);
            System.assertEquals(true, stateJson != null, 'Cluster saved job state is null');
            System.assertEquals(state.model.numberOfClusters, state.jobClusters.size(), 'Incorrect number of clusters created for the job');

            System.assertEquals(true, state.clusterJob != null, 'Cluster job was not created');
            System.assertEquals(1, state.currentAlgorithmStep, 'Incorrect current step');
            System.assertEquals(state.model.fields.size(), state.minMaxValues.size(), 'MinMax values initialized incorrectly');
            System.debug('MinMax values: ' + state.minMaxValues);
            System.assertEquals(true, (Decimal)state.minMaxValues[0].maxValue > 0, 'MinMax value calculated incorrectly');
            List<ClusterJobResult__c> results = [SELECT Id, Random__c, Json__c FROM ClusterJobResult__c WHERE ClusterJob__c = :state.clusterJob.Id LIMIT 1];
            System.assertEquals(true, results != null && results.size() > 0, 'Job results are not populated');
            System.assertEquals(true, results[0].Random__c >= 0, 'Incorrect random seed value');
            System.assertEquals(true, results[0].Json__c != null && results[0].Json__c != '', 'Json data is not populated');

            state = (ClusterKMeansJobState)ClusterAlgorithmRunner.jobState;
            //ClusterInitCentroidsStep
            runner.setJobState(state);
            ClusterInitCentroidsStep initCentroidsStep = (ClusterInitCentroidsStep)runner.steps[state.currentAlgorithmStep];
            initCentroidsStep.init(runner);
            initCentroidsStep.execute(null, initCentroidsStep.start(null));
            initCentroidsStep.finish(null);
            
            System.assertEquals(state.model.numberOfClusters, state.centroids.size(), 'Centroids initialized incorrectly');
            System.assertEquals(ClusterConstants.getSampleRecordSize(state.model), state.dataPoints.size(), 'Sample records are not loaded');

            stateJson = JSON.serialize(state);

            //ClusterPAMDataAssignmentStep
            runner.setJobState(state);
            ClusterPAMDataAssignmentStep pdaStep = (ClusterPAMDataAssignmentStep)runner.steps[state.currentAlgorithmStep];
            pdaStep.init(runner);
            Object[] dataPoints = pdaStep.start(null);
            pdaStep.execute(null, dataPoints);
            pdaStep.finish(null);

            System.assertEquals(true, state.centroids[0].cost > 0, 'Centroid cost calculated incorrectly');
            Boolean isCentroidFirst = false;
            for (ClusterDataPoint centroid:state.centroids){
                if (state.dataPoints[0].recordId == centroid.recordId) {
                    isCentroidFirst = true;
                    break;
                }
            }
            System.assertEquals(true, state.dataPoints[0].clusterIndex >=0 || isCentroidFirst, 'Assignment to cluster is incorrect');
            System.assertEquals(3, state.currentAlgorithmStep, 'Incorrect next step after PAM data assignment');

            Integer currentStep = state.currentAlgorithmStep;
            ClusterPAMSwapStep swapStep = (ClusterPAMSwapStep)runner.steps[state.currentAlgorithmStep];
            ClusterDataPoint[] swapScope = new ClusterDataPoint[10];
            for (Integer i=0; i<swapScope.size(); i++) {
                swapScope[i] = state.dataPoints[i];
            }
            swapStep.init(runner);
            swapStep.execute(null, swapScope);
            swapStep.finish(null);
            System.assertEquals(true, state.hasSwapped, 'There was no centroid swap');
            System.assertEquals(currentStep - 1, state.currentAlgorithmStep, 'Incorrect next step if there is swap');
            
            state.hasSwapped = false;
            state.currentAlgorithmStep = currentStep; //Setting current step back to swap step
            runner.prepareNextStep();
            System.assertEquals(currentStep + 1, state.currentAlgorithmStep, 'Incorrect next step if there is no swap');

            currentStep = state.currentAlgorithmStep;
            ClusterSilhouetteRefinementStep refineStep = (ClusterSilhouetteRefinementStep)runner.steps[state.currentAlgorithmStep];
            refineStep.init(runner);
            refineStep.execute(null, state.dataPoints);
            refineStep.finish(null);
            System.assertEquals(currentStep + 1, state.currentAlgorithmStep, 'Incorrect next step after refinement');

            currentStep = state.currentAlgorithmStep;
            ClusterCentroidDataAssignmentStep dataAssignmentStep = (ClusterCentroidDataAssignmentStep)runner.steps[state.currentAlgorithmStep];
            dataAssignmentStep.init(runner);
            // Get a query locator
            Database.QueryLocator ql = dataAssignmentStep.start(null);
            // Get an iterator
            Database.QueryLocatorIterator it =  ql.iterator();
            List<ClusterJobResult__c> resultScope = new List<ClusterJobResult__c>();
            while (it.hasNext())
            {
                resultScope.add((ClusterJobResult__c)it.next());
            }
            dataAssignmentStep.execute(null, resultScope);
            dataAssignmentStep.done();

            currentStep = state.currentAlgorithmStep;
            ClusterSilhouetteScoreStep scoreStep = (ClusterSilhouetteScoreStep)runner.steps[state.currentAlgorithmStep];
            scoreStep.init(runner);
            scoreStep.execute(null, ClusterDataHelper.getRandomDataPoints(10, state));
            scoreStep.finish(null);
            System.assertEquals(true, state.clusterJob.Score__c != null, 'Silhouette score calculated incorrectly');

            Boolean lastStep = runner.prepareNextStep();
            results = [SELECT Id, ClusterNumber__c, Cluster__c FROM ClusterJobResult__c WHERE ClusterJob__c = :state.clusterJob.Id LIMIT 1];
            System.assertEquals(true, results[0].ClusterNumber__c >= 0, 'Cluster result cluster number not saved');
            System.assertEquals(true, results[0].Cluster__c != null, 'Cluster result cluster id not saved');
            System.assertEquals(currentStep, state.currentAlgorithmStep, 'Incorrect next step after silhouette score calculation');
            System.assertEquals(true, lastStep, 'Last step not returned');
            System.assertEquals(state.clusterJob.JobStatus__c, ClusterConstants.JOBSTATUS_COMPLETED, 'Incorrect job status on last step');

            //Testing ClusterJobDetailsController
            ClusterJobDetailsUiModel jobDetailModel = ClusterJobDetailsController.getJob(state.clusterJob.Id);
            System.assertEquals(state.clusterJob.JobStatus__c, jobDetailModel.status, 'Unexpected job status retrieved');
            
            List<ClusterDataPoint> clusterDataPoints = ClusterJobDetailsController.getDataPoints(state.clusterJob.Id, 100, 0);
            System.assertEquals(true, clusterDataPoints.size() > 0, 'No data points retrieved');
        }
    }

    @isTest
    public static void testEmptyDataset() {
        String modelJson = 
            '{"isCustomSoql":false,"soql":"SELECT AccountNumber, AccountSource, AnnualRevenue, Id FROM Account","filter":"{\\"expressionFields\\":[],\\"customLogic\\":\\"\\"}",' + 
            '"fields":[{"name":"AccountNumber","displayLabel":"Account Number","relationName":"","objectName":"Account","distanceType":"Text","weight":1},' + 
            '{"name":"AccountSource","displayLabel":"Account Source","relationName":"","objectName":"Account","distanceType":"Category","weight":1},' + 
            '{"name":"AnnualRevenue","displayLabel":"Annual Revenue","relationName":"","objectName":"Account","distanceType":"Numeric","weight":1},' + 
            '{"name":"Id","displayLabel":"Account ID","relationName":"","objectName":"Account","distanceType":"None","weight":1}],"algorithm":"K-Medoids","numberOfClusters":"5","name":"test","objectName":"Account"}';
        ClusterModelWrapper wrapper = ClusterTestData.createModel(modelJson);
        User clusterUser = ClusterTestData.createClusterUser();
        System.runAs(clusterUser) {
            Map<String, Object> parameters = new Map<String, Object>();
            parameters.put('numberOfClusters', 5);
            parameters.put('runRefinementStep', true);
            Test.startTest();
            String jobId = ClusterModelLauncherController.runModel(wrapper.modelId, parameters); //This should run just 1 step in test mode
            Test.stopTest();

            ClusterJobDetailsUiModel jobDetails =  ClusterJobDetailsController.getJob(jobId);
            System.assertEquals(jobDetails.model.modelId, wrapper.modelId, 'Incorrect job model id');
            System.assertEquals(ClusterConstants.JOBSTATUS_FAILED, jobDetails.status, 'Incorrect job status for an empty dataset');
            
            List<ClusterDataPoint> dataPoints = ClusterJobDetailsController.getDataPoints(jobDetails.jobId, 100, 0);
            System.assertEquals(0, dataPoints.size(), 'Incorrect number of data points');
        }
    }  

    @isTest
    public static void testKMedoidsMaxIterations() {        
        String modelJson = '{"algorithm":"K-Medoids","fields":[{"name":"AnnualRevenue","displayLabel":"Annual Revenue","relationName":"","objectName":"Lead","distanceType":"Numeric","weight":1},{"name":"Id","displayLabel":"Lead ID","relationName":"","objectName":"Lead","distanceType":"None","weight":1},{"name":"Industry","displayLabel":"Industry","relationName":"","objectName":"Lead","distanceType":"Category","weight":1},{"name":"Name","displayLabel":"Full Name","relationName":"","objectName":"Lead","distanceType":"None","weight":1},{"name":"NumberOfEmployees","displayLabel":"Employees","relationName":"","objectName":"Lead","distanceType":"Numeric","weight":1},{"name":"Rating","displayLabel":"Rating","relationName":"","objectName":"Lead","distanceType":"Category","weight":1},{"name":"Title","displayLabel":"Title","relationName":"","objectName":"Lead","distanceType":"Text","weight":1}],"filter":"{\\"expressionFields\\":[],\\"customLogic\\":\\"\\"}","isCustomSoql":false,"name":"LeadsUnitTest","numberOfClusters":5,"objectName":"Lead","soql":"SELECT AnnualRevenue, Id, Industry, Name, NumberOfEmployees, Rating, Title FROM Lead LIMIT 200"}';
        ClusterModelWrapper model = ClusterTestData.createModel(modelJson);
        User clusterUser = ClusterTestData.createClusterUser();
        System.runAs(clusterUser) {
            ClusterKMedoidsPAMRunner runner = (ClusterKMedoidsPAMRunner)ClusterAlgorithmFactory.getRunner(model);
            model.parameters.put('numberOfClusters', 5);
            model.parameters.put('runRefinementStep', true);
            runner.init(model);
            Test.startTest();
            runner.start();
            Test.stopTest();
            ClusterKMeansJobState state = (ClusterKMeansJobState)ClusterAlgorithmRunner.jobState;
            String stateJson = ClusterJobManager.loadJobState(state.clusterJob.Id);
            System.assertEquals(true, stateJson != null, 'Cluster saved job state is null');
            System.assertEquals(state.model.numberOfClusters, state.jobClusters.size(), 'Incorrect number of clusters created for the job');

            state.totalIterationsCount = ClusterConstants.getMaxIterations();

            //ClusterInitCentroidsStep
            runner.setJobState(state);
            ClusterInitCentroidsStep initCentroidsStep = (ClusterInitCentroidsStep)runner.steps[state.currentAlgorithmStep];
            initCentroidsStep.init(runner);
            initCentroidsStep.execute(null, initCentroidsStep.start(null));
            initCentroidsStep.finish(null);
            ClusterJob__c job = ClusterJobManager.getJob(state.clusterJob.Id);
            System.assertEquals(ClusterConstants.JOBSTATUS_CANCELLED, job.JobStatus__c, 'Incorrect job status for max iterations');
            System.assertEquals('Maximum algorithm iterations reached, job was interrupted', job.JobStatusText__c, 'Incorrect job status text for max iterations');
        }
    }

    @isTest
    public static void testKMedoidsLongText() {        
        ClusterModelWrapper model = ClusterTestData.createLongTextModel();
        User clusterUser = ClusterTestData.createClusterUser();
        System.runAs(clusterUser) {
            ClusterKMedoidsPAMRunner runner = (ClusterKMedoidsPAMRunner)ClusterAlgorithmFactory.getRunner(model);
            model.parameters.put('numberOfClusters', 5);
            model.parameters.put('runRefinementStep', true);
            runner.init(model);
            Test.startTest();
            runner.start();
            Test.stopTest();
            ClusterKMeansJobState state = (ClusterKMeansJobState)ClusterAlgorithmRunner.jobState;
            String stateJson = ClusterJobManager.loadJobState(state.clusterJob.Id);
            System.assertEquals(true, stateJson != null, 'Cluster saved job state is null');
            System.assertEquals(state.model.numberOfClusters, state.jobClusters.size(), 'Incorrect number of clusters created for the job');
            //state = (ClusterKMeansJobState)JSON.deserialize(stateJson, ClusterKMeansJobState.class);

            System.assertEquals(true, state.clusterJob != null, 'Cluster job was not created');
            System.assertEquals(1, state.currentAlgorithmStep, 'Incorrect current step');
            System.assertEquals(state.model.fields.size(), state.minMaxValues.size(), 'MinMax values initialized incorrectly');
            System.assertEquals(true, ((ClusterCompressedDoubleArray)state.minMaxValues[0].maxValue).iterator().hasNext(), 'MinMax value calculated incorrectly');
            List<ClusterJobResult__c> results = [SELECT Id, Random__c, Json__c FROM ClusterJobResult__c WHERE ClusterJob__c = :state.clusterJob.Id LIMIT 1];
            System.assertEquals(true, results != null && results.size() > 0, 'Job results are not populated');
            System.assertEquals(true, results[0].Random__c >= 0, 'Incorrect random seed value');
            System.assertEquals(true, results[0].Json__c != null && results[0].Json__c != '', 'Json data is not populated');

            //ClusterInitCentroidsStep
            runner.setJobState(state);
            ClusterInitCentroidsStep initCentroidsStep = (ClusterInitCentroidsStep)runner.steps[state.currentAlgorithmStep];
            initCentroidsStep.init(runner);
            initCentroidsStep.execute(null, initCentroidsStep.start(null));
            initCentroidsStep.finish(null);
            
            state = (ClusterKMeansJobState)ClusterAlgorithmRunner.jobState;
            System.assertEquals(state.model.numberOfClusters, state.centroids.size(), 'Centroids initialized incorrectly');
            System.assertEquals(10, state.dataPoints.size(), 'Sample records are not loaded');

            stateJson = JSON.serialize(state);

            //ClusterPAMDataAssignmentStep
            runner.setJobState(state);
            ClusterPAMDataAssignmentStep pdaStep = (ClusterPAMDataAssignmentStep)runner.steps[state.currentAlgorithmStep];
            pdaStep.init(runner);
            Object[] dataPoints = pdaStep.start(null);
            pdaStep.execute(null, dataPoints);
            pdaStep.finish(null);

            Double centroidCost = 0.0;
            for (Integer i = 0; i<state.centroids.size(); i++){
                if (state.centroids[i].cost > 0) {
                    centroidCost += state.centroids[i].cost;
                }
            }

            System.assertEquals(true, (centroidCost > 0.0), 'Centroid cost calculated incorrectly');
            Boolean isCentroidFirst = false;
            for (ClusterDataPoint centroid:state.centroids){
                if (state.dataPoints[0].recordId == centroid.recordId) {
                    isCentroidFirst = true;
                    break;
                }
            }
            System.assertEquals(true, state.dataPoints[0].clusterIndex >=0 || isCentroidFirst, 'Assignment to cluster is incorrect');
            System.assertEquals(3, state.currentAlgorithmStep, 'Incorrect next step after PAM data assignment');
            System.assertEquals(true, state.hasNearestCentroids(), 'Nearest centroids calculated incorrectly');

            Integer currentStep = state.currentAlgorithmStep;
            ClusterPAMSwapStep swapStep = (ClusterPAMSwapStep)runner.steps[state.currentAlgorithmStep];
            ClusterDataPoint[] swapScope = new ClusterDataPoint[10];
            for (Integer i=0; i<swapScope.size(); i++) {
                swapScope[i] = state.dataPoints[i];
            }
            swapStep.init(runner);
            swapStep.execute(null, swapScope);
            swapStep.finish(null);
            //We are not testing if the centroid swap actually hapenned, because long text model has only 10 items
            System.assertEquals(state.hasSwapped ? currentStep - 1 : currentStep + 1, state.currentAlgorithmStep, 'Incorrect next step if there is swap');
            
            state.hasSwapped = false;
            state.currentAlgorithmStep = currentStep; //Setting current step back to swap step
            runner.prepareNextStep();
            System.assertEquals(currentStep + 1, state.currentAlgorithmStep, 'Incorrect next step if there is no swap');

            currentStep = state.currentAlgorithmStep;
            ClusterCentroidDataAssignmentStep dataAssignmentStep = (ClusterCentroidDataAssignmentStep)runner.steps[state.currentAlgorithmStep];
            dataAssignmentStep.init(runner);
            // Get a query locator
            Database.QueryLocator ql = dataAssignmentStep.start(null);
            // Get an iterator
            Database.QueryLocatorIterator it =  ql.iterator();
            List<ClusterJobResult__c> resultScope = new List<ClusterJobResult__c>();
            while (it.hasNext())
            {
                resultScope.add((ClusterJobResult__c)it.next());
            }
            dataAssignmentStep.execute(null, resultScope);
            dataAssignmentStep.done();

            currentStep = state.currentAlgorithmStep;
            ClusterSilhouetteScoreStep scoreStep = (ClusterSilhouetteScoreStep)runner.steps[state.currentAlgorithmStep];
            scoreStep.init(runner);
            scoreStep.execute(null, state.dataPoints);
            scoreStep.finish(null);
            System.assertEquals(true, state.clusterJob.Score__c != null, 'Silhouette score calculated incorrectly');

            Boolean lastStep = runner.prepareNextStep();
            results = [SELECT Id, ClusterNumber__c, Cluster__c FROM ClusterJobResult__c WHERE ClusterJob__c = :state.clusterJob.Id LIMIT 1];
            System.assertEquals(true, results[0].ClusterNumber__c >= 0, 'Cluster result cluster number not saved');
            System.assertEquals(true, results[0].Cluster__c != null, 'Cluster result cluster id not saved');
            System.assertEquals(currentStep, state.currentAlgorithmStep, 'Incorrect next step after silhouette score calculation');
            System.assertEquals(true, lastStep, 'Last step not returned');
            System.assertEquals(state.clusterJob.JobStatus__c, ClusterConstants.JOBSTATUS_COMPLETED, 'Incorrect job status on last step');

            //Testing ClusterJobDetailsController
            ClusterJobDetailsUiModel jobDetailModel = ClusterJobDetailsController.getJob(state.clusterJob.Id);
            System.assertEquals(state.clusterJob.JobStatus__c, jobDetailModel.status, 'Unexpected job status retrieved');
            
            List<ClusterDataPoint> clusterDataPoints = ClusterJobDetailsController.getDataPoints(state.clusterJob.Id, 100, 0);
            System.assertEquals(true, clusterDataPoints.size() > 0, 'No data points retrieved');

            ClusterPredictUiModel.PredictResultModel predictResult = ClusterPredictController.predict(clusterDataPoints.get(0).externalId, model.modelId, false);
            // Expected is clusterDataPoints.get(0).clusterIndex, but it can't be guaranteed because we only run 1 iteration
            // So we only check if predicted cluster index is less than the number of clusters
            System.assertEquals(true, predictResult.clusterIndex < 5, 'Cluster predicted incorrectly');

            ClusterJobResult__c leadResult = [SELECT Id, RecordId__c FROM ClusterJobResult__c LIMIT 1];
            Lead l1 = [SELECT Description, Id, Industry, Name, NumberOfEmployees, Title FROM Lead WHERE Id=:leadResult.RecordId__c];
            List<Id> dataPointIds = new List<Id>();
            dataPointIds.add(leadResult.Id);
            ClusterDataPoint d1 = ClusterDataHelper.getDataPoints(dataPointIds, state).get(0);
            l1.Id = null;
            l1.FirstName = 'Test2';
            l1.LastName = 'Test2';
            l1.Company = 'Test2';
            insert l1;
            ClusterDataPoint d2 = runner.getDataPoint(l1.Id);
            //Double distance = runner.calculateDPDistance(d1, d2);
            Double distance = ClusterDataHelper.calculateCosineDistance(d1.values[0], d2.values[0], null);
            ClusterCompressedDoubleArray ccd1 = (ClusterCompressedDoubleArray)d1.values[0];
            ClusterCompressedDoubleArray ccd2 = (ClusterCompressedDoubleArray)d2.values[0];
            System.assertEquals(true, ClusterDataHelper.doublesEqual(distance, ClusterDataHelper.DOUBLE_ZERO), 'Distance test failed');

        }
    }

    @isTest
    public static void testKMedoidsNullValues() {
        User adminUser = ClusterTestData.createAdminUser();
        Boolean leadUpdated = false;
        System.runas(adminUser) {
            try {
                Lead l = [SELECT AnnualRevenue, Id, Industry, Name, NumberOfEmployees FROM Lead LIMIT 1];
                System.assertEquals(true, l != null, 'Lead record not loaded');
                l.Industry = null;
                l.AnnualRevenue = null;
                l.NumberOfEmployees = null;
                update l;
                leadUpdated = true;
            }
            catch (Exception ex) {
                leadUpdated = false;
            }
        }
        if (leadUpdated) {
            testKMedoids();
        }
    }

    @isTest
    public static void testPredictionModel() {
        ClusterModelWrapper model = ClusterTestData.createPredictionModel();
        User clusterUser = ClusterTestData.createClusterUser();
        System.runAs(clusterUser) {
            ClusterKMedoidsPAMRunner runner = ClusterTestData.runKMedoids(model, 5);
            Test.startTest();
            Lead l = [SELECT Id, Name FROM Lead LIMIT 1];
            ClusterPredictionResult pr = runner.getPredictor().predict(l.Id, true);
            System.assertEquals(2, pr.getFieldPredictions().size(), 'Incorrect field prediction size');
            System.assertEquals('Industry', pr.fieldPredictions[1].field.name, 'Incorrect prediction field name');
            System.assertEquals(true, pr.fieldPredictions[1].getFieldValuePredictions()[0].getValue() != null, 'Incorrect prediction field value');
            System.assertEquals(true, pr.fieldPredictions[1].fieldValuePredictions[0].getProbability() > 0.0, 'Incorrect prediction field value probability');
            System.assertEquals(true, Double.valueOf(pr.fieldPredictions[0].fieldValuePredictions[0].value) > 0.0, 'Incorrect prediction field value');
            System.assertEquals(1, pr.fieldPredictions[0].fieldValuePredictions.size(), 'Incorrect prediction field values size');
            System.assertEquals(true, pr.getClusterPrediction() != null, 'Incorrect cluster prediction');
            System.assertEquals(true, pr.getClusterIndex() > -1 != null, 'Incorrect cluster index');
            Test.stopTest();
        }
    }
    
}