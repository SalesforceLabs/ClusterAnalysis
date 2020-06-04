@isTest
public with sharing class ClusterUiControllerTest {
    @TestSetup
    static void createLeads(){
        List<sObject> leads = Test.loadData(Lead.sObjectType, 'ClustanLeadsMock');
    }

    @isTest 
    static void testLauncherAndJobDetailsUiControlers() {
        String modelJson = '{"algorithm":"K-Medoids","fields":[{"name":"AnnualRevenue","displayLabel":"Annual Revenue","relationName":"","objectName":"Lead","distanceType":"Numeric","weight":1},{"name":"Id","displayLabel":"Lead ID","relationName":"","objectName":"Lead","distanceType":"None","weight":1},{"name":"Industry","displayLabel":"Industry","relationName":"","objectName":"Lead","distanceType":"Category","weight":1},{"name":"Name","displayLabel":"Full Name","relationName":"","objectName":"Lead","distanceType":"None","weight":1},{"name":"NumberOfEmployees","displayLabel":"Employees","relationName":"","objectName":"Lead","distanceType":"Numeric","weight":1},{"name":"Rating","displayLabel":"Rating","relationName":"","objectName":"Lead","distanceType":"Category","weight":1},{"name":"Title","displayLabel":"Title","relationName":"","objectName":"Lead","distanceType":"Text","weight":1}],"filter":"{\\"expressionFields\\":[],\\"customLogic\\":\\"\\"}","isCustomSoql":false,"name":"LeadsUnitTest","numberOfClusters":5,"objectName":"Lead","soql":"SELECT AnnualRevenue, Id, Industry, Name, NumberOfEmployees, Rating, Title FROM Lead LIMIT 200"}';
        //Testing insert model
        ClusterModelWrapper wrapper = ClusterTestData.createModel(modelJson);
        User clusterUser = ClusterTestData.createClusterUser();
        System.runAs(clusterUser) {
            ClusterModelLauncherUiModel uiModel = ClusterModelLauncherController.loadModel(wrapper.modelId);            
            System.assertEquals(wrapper.name, uiModel.model.name, 'Saved and loaded model names do not match');
            System.assertEquals(2, uiModel.parameters.size(), 'K-Medoids should have 2 parameters');

            Map<String, Object> parameters = new Map<String, Object>();
            parameters.put('numberOfClusters', 5);
            parameters.put('runRefinementStep', true);
            Test.startTest();
            String jobId = ClusterModelLauncherController.runModel(uiModel.model.modelId, parameters); //This should run just 1 step in test mode
            Test.stopTest();

            ClusterJobDetailsUiModel jobDetails =  ClusterJobDetailsController.getJob(jobId);
            System.assertEquals(jobDetails.model.modelId, uiModel.model.modelId, 'Incorrect job model id');
            System.assertEquals(5, jobDetails.clusters.size(), 'Incorrect job model id');
            
            List<ClusterDataPoint> dataPoints = ClusterJobDetailsController.getDataPoints(jobDetails.jobId, 100, 0);
            System.assertEquals(true, dataPoints.size() > 0, 'Cluster job data points were not retrieved');

            ClusterResultDetailsUiModel resultUiModel = ClusterJobDetailsController.getJobResultModel(dataPoints.get(0).recordId);
            System.assertEquals(dataPoints.get(0).recordName, resultUiModel.dataPoint.recordName, 'Cluster data point was not retrieved correctly');

            ClusterJobDetailsUiModel saveJobDetails = ClusterJobDetailsController.setJobName(jobDetails.jobId, 'Test job name');
            System.assertEquals('Test job name', saveJobDetails.jobName, 'Save job name test failed');

            saveJobDetails = ClusterJobDetailsController.cancelJob(jobId);
            System.assertEquals(ClusterConstants.JOBSTATUS_MARKED_FOR_CANCEL, saveJobDetails.status, 'Cancel job test failed');
        }
    }

    @isTest 
    static void testKMeansValidation() {
        User clusterUser = ClusterTestData.createClusterUser();
        System.runAs(clusterUser) {
            String modelJson = '{"algorithm":"K-Means","fields":[{"name":"AnnualRevenue","displayLabel":"Annual Revenue","relationName":"","objectName":"Lead","distanceType":"Numeric","weight":1},{"name":"Id","displayLabel":"Lead ID","relationName":"","objectName":"Lead","distanceType":"None","weight":1},{"name":"Industry","displayLabel":"Industry","relationName":"","objectName":"Lead","distanceType":"Category","weight":1}' 
            + ',{"name":"Name","displayLabel":"Full Name","relationName":"","objectName":"Lead","distanceType":"None","weight":1},{"name":"NumberOfEmployees","displayLabel":"Employees","relationName":"","objectName":"Lead","distanceType":"Numeric","weight":1},{"name":"Rating","displayLabel":"Rating","relationName":"","objectName":"Lead","distanceType":"Category","weight":1}'
            + ',{"name":"Company","displayLabel":"Company","relationName":"","objectName":"Lead","distanceType":"Output","weight":1},{"name":"Title","displayLabel":"Title","relationName":"","objectName":"Lead","distanceType":"Text","weight":1}],"filter":"{\\"expressionFields\\":[],\\"customLogic\\":\\"\\"}","isCustomSoql":false,"name":"LeadsUnitTest","numberOfClusters":5,"objectName":"Lead","soql":"SELECT AnnualRevenue, Id, Industry, Name, NumberOfEmployees, Rating, Title FROM Lead LIMIT 200"}';
            //Testing insert model
            ClusterModelWrapper model = (ClusterModelWrapper)JSON.deserialize(modelJson, ClusterModelWrapper.class);
            model.prepare();
            
            ClusterAlgorithmRunner runner = ClusterAlgorithmFactory.getRunner(ClusterConstants.ALGORITHM_KMEANS);
            List<ClusterAlgorithmParameter> parameters = runner.getParameters(model);
            System.assertEquals(2, parameters.size(), 'K-Means should have 2 parameters');

            ClusterAlgorithmRunner.ModelValidationResult vr = runner.validateModel(model);
            System.assertEquals(false, vr.isValid, 'Incorrect validation result');
            System.assertEquals(4, vr.messages.size(), 'Incorrect number of validation errors');
            System.assertEquals(true, vr.messages.contains(ClusterAlgorithmRunner.MSG_ERR_OUTPUTFIELDVALIDATION), 'Cluster output step validation error was not found');
        }
    }

    @isTest
    static void testDeleteJob() {
        String modelJson = '{"algorithm":"K-Means","fields":[{"name":"AnnualRevenue","displayLabel":"Annual Revenue","relationName":"","objectName":"Lead","distanceType":"Numeric","weight":1},{"name":"Id","displayLabel":"Lead ID","relationName":"","objectName":"Lead","distanceType":"None","weight":1},{"name":"Name","displayLabel":"Full Name","relationName":"","objectName":"Lead","distanceType":"None","weight":1},{"name":"NumberOfEmployees","displayLabel":"Employees","relationName":"","objectName":"Lead","distanceType":"Numeric","weight":1}],"filter":"{\\"expressionFields\\":[],\\"customLogic\\":\\"\\"}","isCustomSoql":false,"name":"LeadsUnitTest","numberOfClusters":5,"objectName":"Lead","soql":"SELECT AnnualRevenue, Id, Name, NumberOfEmployees FROM Lead ORDER BY Id LIMIT 200"}';
        ClusterModelWrapper model = ClusterTestData.createModel(modelJson);
        User clusterUser = ClusterTestData.createClusterUser();
        System.runAs(clusterUser) {
            ClusterKMeansRunner runner = (ClusterKMeansRunner)ClusterAlgorithmFactory.getRunner(model);
            model.parameters.put('numberOfClusters', 5);
            model.parameters.put('distanceFunction', ClusterConstants.DISTANCE_EUCLIDEAN);
            ClusterAlgorithmRunner.ModelValidationResult vr = runner.validateModel(model);
            System.assertEquals(true, vr.isValid, 'Model validation has failed');

            runner.init(model);
            ClusterKMeansJobState state = (ClusterKMeansJobState)runner.getJobState();
            state.clusterJob = ClusterJobManager.createJob(state.model.name, state.model);
            state.jobClusters = ClusterJobManager.createJobClusters(state.clusterJob);
            state.totalIterationsCount = 0;
            Integer currentStep = state.currentAlgorithmStep;
            ClusterPrepareDataStep prepareDataStep = (ClusterPrepareDataStep)runner.steps[state.currentAlgorithmStep];
            prepareDataStep.init(runner);
            // Get a query locator
            Database.QueryLocator ql = prepareDataStep.start(null);
            // Get an iterator
            Database.QueryLocatorIterator it =  ql.iterator();
            List<Lead> resultScope = new List<Lead>();
            while (it.hasNext())
            {
                resultScope.add((Lead)it.next());
            }
            prepareDataStep.execute(null, resultScope);
            prepareDataStep.finish(null);

            ClusterModel__c modelRecord = [SELECT Id, Name, Object__c, Algorithm__c, Filter__c, Parameters__c, SOQL__c , isCustomSoql__c, Description__c, NumberOfClusters__c,
                    (SELECT Id, Name, FieldName__c, Model__c, ObjectName__c, DistanceType__c, Weight__c, RelationName__c FROM ClusterModelFields__r)
                    FROM ClusterModel__c WHERE Id = :model.modelId];
            List<ClusterJob__c> jobRecords = [SELECT Id, ClusterModel__c, NumberOfClusters__c, ObjectName__c, JobStatus__c, JobStatusText__c, StartDate__c, EndDate__c, InternalJobId__c, Score__c 
                FROM ClusterJob__c WHERE ClusterModel__c = :model.modelId];

            Test.startTest();
            PageReference pageRef = Page.DeleteJob;
            pageRef.getparameters().put('recordId', jobRecords.get(0).id);  
            Test.setCurrentPage(pageRef);
            Apexpages.StandardController sc = new Apexpages.StandardController(jobRecords.get(0));
            ClusterDeleteJobControllerExt ext = new  ClusterDeleteJobControllerExt(sc);         
            ext.deleteJob();
            System.assertNotEquals('', ext.batchJobId, 'Batch job id should not be empty');
            Test.stopTest();
            jobRecords = [SELECT Id, ClusterModel__c, NumberOfClusters__c, ObjectName__c, JobStatus__c, JobStatusText__c, StartDate__c, EndDate__c, InternalJobId__c, Score__c 
                FROM ClusterJob__c WHERE ClusterModel__c = :model.modelId];

            System.assertEquals(0, jobRecords.size(), 'Cluster job was not deleted');
        }
    }

    @isTest
    static void testDeleteModel() {
        String modelJson = '{"algorithm":"K-Means","fields":[{"name":"AnnualRevenue","displayLabel":"Annual Revenue","relationName":"","objectName":"Lead","distanceType":"Numeric","weight":1},{"name":"Id","displayLabel":"Lead ID","relationName":"","objectName":"Lead","distanceType":"None","weight":1},{"name":"Name","displayLabel":"Full Name","relationName":"","objectName":"Lead","distanceType":"None","weight":1},{"name":"NumberOfEmployees","displayLabel":"Employees","relationName":"","objectName":"Lead","distanceType":"Numeric","weight":1}],"filter":"{\\"expressionFields\\":[],\\"customLogic\\":\\"\\"}","isCustomSoql":false,"name":"LeadsUnitTest","numberOfClusters":5,"objectName":"Lead","soql":"SELECT AnnualRevenue, Id, Name, NumberOfEmployees FROM Lead ORDER BY Id LIMIT 200"}';
        ClusterModelWrapper model = ClusterTestData.createModel(modelJson);
        User clusterAdmin = ClusterTestData.createClusterAdmin();
        System.runAs(clusterAdmin) {
            ClusterKMeansRunner runner = (ClusterKMeansRunner)ClusterAlgorithmFactory.getRunner(model);
            model.parameters.put('numberOfClusters', 5);
            model.parameters.put('distanceFunction', ClusterConstants.DISTANCE_EUCLIDEAN);
            ClusterAlgorithmRunner.ModelValidationResult vr = runner.validateModel(model);
            System.assertEquals(true, vr.isValid, 'Model validation has failed');

            runner.init(model);
            ClusterKMeansJobState state = (ClusterKMeansJobState)runner.getJobState();
            state.clusterJob = ClusterJobManager.createJob(state.model.name, state.model);
            state.jobClusters = ClusterJobManager.createJobClusters(state.clusterJob);
            state.totalIterationsCount = 0;
            Integer currentStep = state.currentAlgorithmStep;
            ClusterPrepareDataStep prepareDataStep = (ClusterPrepareDataStep)runner.steps[state.currentAlgorithmStep];
            prepareDataStep.init(runner);
            // Get a query locator
            Database.QueryLocator ql = prepareDataStep.start(null);
            // Get an iterator
            Database.QueryLocatorIterator it =  ql.iterator();
            List<Lead> resultScope = new List<Lead>();
            while (it.hasNext())
            {
                resultScope.add((Lead)it.next());
            }
            prepareDataStep.execute(null, resultScope);
            prepareDataStep.finish(null);

            ClusterModel__c modelRecord = [SELECT Id, Name, Object__c, Algorithm__c, Filter__c, Parameters__c, SOQL__c , isCustomSoql__c, Description__c, NumberOfClusters__c,
                    (SELECT Id, Name, FieldName__c, Model__c, ObjectName__c, DistanceType__c, Weight__c, RelationName__c FROM ClusterModelFields__r)
                    FROM ClusterModel__c WHERE Id = :model.modelId];
            List<ClusterJob__c> jobRecords = [SELECT Id, ClusterModel__c, NumberOfClusters__c, ObjectName__c, JobStatus__c, JobStatusText__c, StartDate__c, EndDate__c, InternalJobId__c, Score__c 
                FROM ClusterJob__c WHERE ClusterModel__c = :model.modelId];

            Test.startTest();
            PageReference pageRef = Page.DeleteModel;
            pageRef.getparameters().put('recordId', jobRecords.get(0).id);  
            Test.setCurrentPage(pageRef);
            Apexpages.StandardController sc = new Apexpages.StandardController(modelRecord);
            ClusterDeleteModelControllerExt ext = new  ClusterDeleteModelControllerExt(sc);         
            ext.deleteModel();
            System.assertNotEquals('', ext.batchJobId, 'Batch job id should not be empty');
            Test.stopTest();
            jobRecords = [SELECT Id, ClusterModel__c, NumberOfClusters__c, ObjectName__c, JobStatus__c, JobStatusText__c, StartDate__c, EndDate__c, InternalJobId__c, Score__c 
                FROM ClusterJob__c WHERE ClusterModel__c = :model.modelId];

            System.assertEquals(0, jobRecords.size(), 'Cluster job was not deleted');

            List<ClusterModel__c> modelRecords = [SELECT Id, Name, Object__c, Algorithm__c, Filter__c, Parameters__c, SOQL__c , isCustomSoql__c, Description__c, NumberOfClusters__c,
                    (SELECT Id, Name, FieldName__c, Model__c, ObjectName__c, DistanceType__c, Weight__c, RelationName__c FROM ClusterModelFields__r)
                    FROM ClusterModel__c WHERE Id = :model.modelId];

            System.assertEquals(0, modelRecords.size(), 'Cluster model was not deleted');
        }
    }

    @isTest
    public static void testClusterAdmin() {
        // Setup test data
        User u = ClusterTestData.CreateClusterAdmin();

        System.runAs(u) {
            //Testing CRUD
            ClusterModel__c testCRUDModel = new ClusterModel__c();
            Schema.DescribeSObjectResult describe = testCRUDModel.getSObjectType().getDescribe();
            System.assertEquals(true, describe.isUpdateable(), 'Incorrect CRUD value for update');
            System.assertEquals(true, describe.isCreateable(), 'Incorrect CRUD value for create');
            System.assertEquals(true, describe.isQueryable(), 'Incorrect CRUD value for select');

        }
    }

    @isTest
    public static void testClusterPermissions() {
        // Setup test data
        // Create a unique UserName
        String uniqueUserName = 'standarduser' + DateTime.now().getTime() + '@testorg.com';
        // This code runs as the system user
        Profile p = [SELECT Id FROM Profile WHERE Name='Standard User'];

        //Creating cluster admin
        User admin = ClusterTestData.createClusterAdmin();

        //Creating cluster user
        User u = ClusterTestData.createClusterUser();

        //Creating standard user
        User standarduser = ClusterTestData.createStandardUser();

        ClusterModelWrapper wrapper;

        System.runAs(admin) {
            String modelJson = '{"algorithm":"K-Medoids","fields":[{"name":"AnnualRevenue","displayLabel":"Annual Revenue","relationName":"","objectName":"Lead","distanceType":"Numeric","weight":1},{"name":"Id","displayLabel":"Lead ID","relationName":"","objectName":"Lead","distanceType":"None","weight":1},{"name":"Industry","displayLabel":"Industry","relationName":"","objectName":"Lead","distanceType":"Category","weight":1},{"name":"Name","displayLabel":"Full Name","relationName":"","objectName":"Lead","distanceType":"None","weight":1},{"name":"NumberOfEmployees","displayLabel":"Employees","relationName":"","objectName":"Lead","distanceType":"Numeric","weight":1},{"name":"Rating","displayLabel":"Rating","relationName":"","objectName":"Lead","distanceType":"Category","weight":1},{"name":"Title","displayLabel":"Title","relationName":"","objectName":"Lead","distanceType":"Text","weight":1}],"filter":"{\\"expressionFields\\":[],\\"customLogic\\":\\"\\"}","isCustomSoql":false,"name":"LeadsUnitTest","numberOfClusters":5,"objectName":"Lead","soql":"SELECT AnnualRevenue, Id, Industry, Name, NumberOfEmployees, Rating, Title FROM Lead LIMIT 200"}';
            //Testing insert model
            wrapper = ClusterModelBuilderController.saveModel(modelJson);
        }

        System.runAs(standarduser) {
            Boolean success = true;
            try {
                ClusterModelBuilderController.getModel(wrapper.modelId);
            }
            catch (ClusterException ex) {
                success = false;
            }
            System.assertEquals(false, success, 'Model was retrieved under standard user');
        }

        System.runAs(u) {
            //Testing CRUD
            ClusterModel__c testCRUDModel = new ClusterModel__c();
            Schema.DescribeSObjectResult describe = testCRUDModel.getSObjectType().getDescribe();
            System.assertEquals(false, describe.isUpdateable(), 'Incorrect CRUD value for update');
            System.assertEquals(false, describe.isCreateable(), 'Incorrect CRUD value for create');
            System.assertEquals(true, describe.isQueryable(), 'Incorrect CRUD value for select');

            //Testing insert model failure
            Boolean success = true;
            try {
                String modelJson = '{"algorithm":"K-Medoids","fields":[{"name":"AnnualRevenue","displayLabel":"Annual Revenue","relationName":"","objectName":"Lead","distanceType":"Numeric","weight":1},{"name":"Id","displayLabel":"Lead ID","relationName":"","objectName":"Lead","distanceType":"None","weight":1},{"name":"Industry","displayLabel":"Industry","relationName":"","objectName":"Lead","distanceType":"Category","weight":1},{"name":"Name","displayLabel":"Full Name","relationName":"","objectName":"Lead","distanceType":"None","weight":1},{"name":"NumberOfEmployees","displayLabel":"Employees","relationName":"","objectName":"Lead","distanceType":"Numeric","weight":1},{"name":"Rating","displayLabel":"Rating","relationName":"","objectName":"Lead","distanceType":"Category","weight":1},{"name":"Title","displayLabel":"Title","relationName":"","objectName":"Lead","distanceType":"Text","weight":1}],"filter":"{\\"expressionFields\\":[],\\"customLogic\\":\\"\\"}","isCustomSoql":false,"name":"LeadsUnitTest","numberOfClusters":5,"objectName":"Lead","soql":"SELECT AnnualRevenue, Id, Industry, Name, NumberOfEmployees, Rating, Title FROM Lead LIMIT 200"}';
                ClusterModelBuilderController.saveModel(modelJson);
            }
            catch (ClusterException ex) {
                success = false;
            }
            System.assertEquals(false, success, 'Model was saved under ClusterPac_User perm set');

            //Testing delete
            success = true;
            try {
                ClusterAccessCheck.checkDeletePermission(Schema.SObjectType.ClusterModel__c);
            }
            catch (ClusterException ex) {
                success = false;
            }
            System.assertEquals(false, success, 'Delete permission check failed under ClusterPac_User perm set');

            //Testing output step failure
            //Here we will test if we can output to ClusterModel__c.Name field - this should fail
            String clusterModelObjectName = Schema.SObjectType.ClusterModel__c.getName();
            String modelWithOutputJson = '{"algorithm":"K-Means","fields":[{"name":"AnnualRevenue","displayLabel":"Annual Revenue","relationName":"","objectName":"Lead","distanceType":"Numeric","weight":1},{"name":"Id","displayLabel":"Lead ID","relationName":"","objectName":"Lead","distanceType":"None","weight":1}' 
            + ',{"name":"Name","displayLabel":"Full Name","relationName":"","objectName":"Lead","distanceType":"None","weight":1},{"name":"NumberOfEmployees","displayLabel":"Employees","relationName":"","objectName":"Lead","distanceType":"Numeric","weight":1}'
            + ',{"name":"Name","displayLabel":"Name","relationName":"","objectName":"'+ clusterModelObjectName + '","distanceType":"Output","weight":1}],"filter":"{\\"expressionFields\\":[],\\"customLogic\\":\\"\\"}","isCustomSoql":false,"name":"LeadsUnitTest","numberOfClusters":5,"objectName":"Lead","soql":"SELECT AnnualRevenue, Id, Name, NumberOfEmployees, Company FROM Lead LIMIT 200"}';
            
            ClusterModelWrapper modelWithOutput = (ClusterModelWrapper)JSON.deserialize(modelWithOutputJson, ClusterModelWrapper.class);
    
            List<String> errors = ClusterAccessCheck.checkModelObjectAccessPermissions(modelWithOutput);
            System.assertEquals(1, errors.size(), 'Model validation failed under standard user');
            System.assertEquals(true, errors.get(0).startsWith('Current user doesn\'t have update FLS permissions on'), 'Incorrect validation error for output step');

            //Testing model loading and first algorithm step
            ClusterModelLauncherUiModel uiModel = ClusterModelLauncherController.loadModel(wrapper.modelId);            
            System.assertEquals(wrapper.name, uiModel.model.name, 'Saved and loaded model names do not match');
            System.assertEquals(2, uiModel.parameters.size(), 'K-Medoids should have 2 parameters');

            ClusterJobRunnerUiModel jrUiModel = ClusterModelLauncherController.getModels();
            System.assertEquals(1, jrUiModel.models.size(), 'Incorrect number of models retrieved');
    
            Map<String, Object> parameters = new Map<String, Object>();
            parameters.put('numberOfClusters', 5);
            parameters.put('runRefinementStep', true);
            Test.startTest();
            String jobId = ClusterModelLauncherController.runModel(uiModel.model.modelId, parameters); //This should run just 1 step in test mode
            Test.stopTest();
    
            ClusterJobDetailsUiModel jobDetails =  ClusterJobDetailsController.getJob(jobId);
            System.assertEquals(jobDetails.model.modelId, uiModel.model.modelId, 'Incorrect job model id');
            System.assertEquals(5, jobDetails.clusters.size(), 'Incorrect job model id');
            
            List<ClusterDataPoint> dataPoints = ClusterJobDetailsController.getDataPoints(jobDetails.jobId, 100, 0);
            System.assertEquals(true, dataPoints.size() > 0, 'Cluster job data points were not retrieved');
    
            ClusterJobDetailsUiModel saveJobDetails = ClusterJobDetailsController.setJobName(jobDetails.jobId, 'Test job name');
            System.assertEquals('Test job name', saveJobDetails.jobName, 'Save job name test failed');
    
            saveJobDetails = ClusterJobDetailsController.cancelJob(jobId);
            System.assertEquals(ClusterConstants.JOBSTATUS_MARKED_FOR_CANCEL, saveJobDetails.status, 'Cancel job test failed');
    
        }
    }

}
