@isTest
public inherited sharing class ClusterRecordPreprocessorTest {
    public class ClusterRecordPreprocessorImpl implements ClusterRecordPreprocessor {
        public void processRecords(List<SObject> records, ClusterRecordPreprocessorParameters parameters) {
            if (parameters.getIsLearning()) {
                System.assertEquals(50, records.size(), 'Incorrect number of records passed to preprocessor');
            }
            else {
                System.assertEquals(1, records.size(), 'Incorrect number of records passed to preprocessor');
            }
            System.assertEquals('LeadsUnitTest', parameters.getModelName(), 'Incorrect model name');
            for (SObject so:records) {
                so.put('Title','Changed from preprocessor');
                so.put('AnnualRevenue',12345);
            }
        }
    }

    public class ClusterObjectFactoryMock extends ClusterObjectFactory {
        public override ClusterRecordPreprocessor createRecordPreprocessor() {
            String customPreprocessorApexClassName = ClusterConstants.getApexRecordPreprocessorClassName();
            return this.createRecordPreprocessor('ClusterRecordPreprocessorTest.ClusterRecordPreprocessorImpl');
        }
    }

    @TestSetup
    static void createLeads(){
        List<sObject> leads = Test.loadData(Lead.sObjectType, 'ClustanLeadsMock');
    }

    @isTest
    public static void testRecordPreprocessor() {
        ClusterModelWrapper model = ClusterTestData.createKMedoidsModel();
        User clusterUser = ClusterTestData.createClusterUser();
        System.runAs(clusterUser) {
            ClusterKMedoidsPAMRunner runner = (ClusterKMedoidsPAMRunner)ClusterAlgorithmFactory.getRunner(model);
            model.parameters.put('numberOfClusters', 5);
            model.parameters.put('runRefinementStep', true);
            runner.init(model);
            runner.setRecordPreprocessor(new ClusterRecordPreprocessorImpl());
            Test.startTest();
            runner.start();
            Test.stopTest();
            checkDataPoints(runner);
        }
    }

    @isTest
    public static void testRecordPreprocessorFromStringParameter() {
        ClusterModelWrapper model = ClusterTestData.createKMedoidsModel();
        User clusterUser = ClusterTestData.createClusterUser();
        System.runAs(clusterUser) {
            ClusterKMedoidsPAMRunner runner = (ClusterKMedoidsPAMRunner)ClusterAlgorithmFactory.getRunner(model);
            ClusterObjectFactoryMock factoryMock = new ClusterObjectFactoryMock();
            runner.objectFactory = factoryMock;
            model.parameters.put('numberOfClusters', 5);
            model.parameters.put('runRefinementStep', true);
            runner.init(model);
            Test.startTest();
            runner.start();
            Test.stopTest();
            checkDataPoints(runner);
        }
    }

    private static void checkDataPoints(ClusterKMedoidsPAMRunner runner) {
        List<ClusterDataPoint> dpList = ClusterDataHelper.getRandomDataPoints(3, runner.getJobState());
        System.assertEquals('Changed from preprocessor', dpList.get(0).values[6], 'Incorrect data point title');
        System.assertEquals(12345, dpList.get(0).values[0], 'Incorrect data point AnnualRevenue');
        Lead l = [SELECT AnnualRevenue, Id, Industry, Name, NumberOfEmployees, Rating, Title FROM Lead LIMIT 1];
        ClusterDataPoint dp = runner.getDataPoint(l.Id);
        System.assertEquals('Changed from preprocessor', dp.values[6], 'Incorrect data point title');
        System.assertEquals(12345, dp.values[0], 'Incorrect data point AnnualRevenue');
    }


}
