@isTest
public with sharing class ClusterTestData {
    public static User createClusterAdmin() {
        // Create a unique UserName
        String uniqueUserName = 'clusteradminuser' + DateTime.now().getTime() + '@testorg.com';
        // This code runs as the system user
        Profile p = [SELECT Id FROM Profile WHERE Name='Standard User'];
        User u = new User(Alias = 'standt', Email='standarduser@testorg.com',
            EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US',
            LocaleSidKey='en_US', ProfileId = p.Id,
            TimeZoneSidKey='America/Los_Angeles',
            UserName=uniqueUserName);
        insert u;
        PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = 'ClusterPac_Admin'];
        insert new PermissionSetAssignment(AssigneeId = u.id, PermissionSetId = ps.Id);
        return u;
    }

    public static User createClusterUser() {
        String uniqueUserName = 'clusteruser' + DateTime.now().getTime() + '@testorg.com';
        Profile p = [SELECT Id FROM Profile WHERE Name='Standard User'];
        //Creating cluster user
        User u = new User(Alias = 'clustu', Email='clusteruser@testorg.com',
        EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US',
        LocaleSidKey='en_US', ProfileId = p.Id,
        TimeZoneSidKey='America/Los_Angeles',
        UserName=uniqueUserName);
        insert u;
        PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = 'ClusterPac_User'];
        insert new PermissionSetAssignment(AssigneeId = u.id, PermissionSetId = ps.Id);
        return u;
    }

    public static User createStandardUser() {
        String uniqueUserName = 'standarduser' + DateTime.now().getTime() + '@testorg.com';
        Profile p = [SELECT Id FROM Profile WHERE Name='Standard User'];
        User standarduser = new User(Alias = 'standt', Email='standarduser@testorg.com',
        EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US',
        LocaleSidKey='en_US', ProfileId = p.Id,
        TimeZoneSidKey='America/Los_Angeles',
        UserName=uniqueUserName);
        insert standarduser;
        return standarduser;
    }

    public static User createAdminUser() {
        String uniqueUserName = 'adminuser' + DateTime.now().getTime() + '@testorg.com';
        Profile p = [SELECT Id FROM Profile WHERE Name='System Administrator'];
        User standarduser = new User(Alias = 'adminu', Email='adminuser@testorg.com',
        EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US',
        LocaleSidKey='en_US', ProfileId = p.Id,
        TimeZoneSidKey='America/Los_Angeles',
        UserName=uniqueUserName);
        insert standarduser;
        return standarduser;
    }

    public static void createLeads(){
        List<sObject> leads = Test.loadData(Lead.sObjectType, 'ClustanLeadsMock');
    }

    public static ClusterModelWrapper createModel(string modelJson) {
        User adminUser = createClusterAdmin();
        ClusterModelWrapper model;
        System.runAs(adminUser) {
            model = ClusterModelBuilderController.saveModel(modelJson);
        }
        return model;
    }

    public static ClusterModelWrapper createLongTextModel() {
        String modelJson = '{"algorithm":"K-Medoids","fields":[{"name":"Description","displayLabel":"Description","relationName":"","objectName":"Lead","distanceType":"LongText","weight":1},{"name":"Id","displayLabel":"Lead ID","relationName":"","objectName":"Lead","distanceType":"None","weight":1},{"name":"Industry","displayLabel":"Industry","relationName":"","objectName":"Lead","distanceType":"Category","weight":1},{"name":"Name","displayLabel":"Full Name","relationName":"","objectName":"Lead","distanceType":"None","weight":1},{"name":"NumberOfEmployees","displayLabel":"Employees","relationName":"","objectName":"Lead","distanceType":"Numeric","weight":1},{"name":"Title","displayLabel":"Title","relationName":"","objectName":"Lead","distanceType":"Text","weight":1}],"filter":"{\\"expressionFields\\":[],\\"customLogic\\":\\"\\"}","isCustomSoql":false,"name":"LeadsUnitTest","numberOfClusters":5,"objectName":"Lead","soql":"SELECT Description, Id, Industry, Name, NumberOfEmployees, Title FROM Lead LIMIT 10"}';
        return ClusterTestData.createModel(modelJson);
    }

    public static ClusterModelWrapper createPredictionModel() {
        String modelJson = '{"algorithm":"K-Medoids","fields":[{"name":"AnnualRevenue","displayLabel":"Annual Revenue","relationName":"","objectName":"Lead","distanceType":"Prediction","weight":1},' +
        '{"name":"Id","displayLabel":"Lead ID","relationName":"","objectName":"Lead","distanceType":"None","weight":1},'+
        '{"name":"Industry","displayLabel":"Industry","relationName":"","objectName":"Lead","distanceType":"Prediction","weight":1},'+
        '{"name":"Name","displayLabel":"Full Name","relationName":"","objectName":"Lead","distanceType":"None","weight":1},'+
        '{"name":"NumberOfEmployees","displayLabel":"Employees","relationName":"","objectName":"Lead","distanceType":"Numeric","weight":1},'+
        '{"name":"Rating","displayLabel":"Rating","relationName":"","objectName":"Lead","distanceType":"Category","weight":1},'+
        '{"name":"Title","displayLabel":"Title","relationName":"","objectName":"Lead","distanceType":"Text","weight":1}],"filter":"{\\"expressionFields\\":[],\\"customLogic\\":\\"\\"}","isCustomSoql":false,"name":"LeadsUnitTest","numberOfClusters":5,"objectName":"Lead","soql":"SELECT AnnualRevenue, Id, Industry, Name, NumberOfEmployees, Rating, Title FROM Lead LIMIT 200"}';        
        return ClusterTestData.createModel(modelJson);
    }


    public static List<SObject> getBatchApexData(Database.Batchable<sObject> batchApexInstance) {
        // Get a query locator
        Database.QueryLocator ql = (Database.QueryLocator)batchApexInstance.start(null);
        // Get an iterator
        Database.QueryLocatorIterator it =  ql.iterator();
        List<SObject> resultScope = new List<SObject>();
        while (it.hasNext())
        {
            resultScope.add((SObject)it.next());
        }
        return resultScope;
    }

    public static String loadTextFromStaticResource(String resourceName) {
        //Looks like the only way to load a string from a static resource in a unit test is to mock an http response
        StaticResourceCalloutMock mock = new StaticResourceCalloutMock();
        mock.setStaticResource(resourceName);
        mock.setStatusCode(200);
        mock.setHeader('Content-Type', 'application/json');
        
        // Set the mock callout mode
        Test.setMock(HttpCalloutMock.class, mock);
        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://www.salesforce.com');
        req.setMethod('GET');
        Http h = new Http();
        HttpResponse res = h.send(req);
        return res.getBody();
    }

    public static ClusterKMedoidsPAMRunner runKMedoids(ClusterModelWrapper model, Integer numberOfClasses) {        
        ClusterKMedoidsPAMRunner runner = (ClusterKMedoidsPAMRunner)ClusterAlgorithmFactory.getRunner(model);
        model.parameters.put('numberOfClusters', numberOfClasses);
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

        return runner;

    }

}