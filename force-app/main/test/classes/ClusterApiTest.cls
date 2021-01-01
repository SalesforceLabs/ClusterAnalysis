@isTest
public with sharing class ClusterApiTest {
    @TestSetup
    static void createLeads(){
        ClusterTestData.createLeads();
    }    

    @isTest
    public static void testPredict() {
        ClusterTestData.runKMeans();
        User clusterUser = ClusterTestData.createClusterUser();
        System.runAs(clusterUser) {
            Test.startTest();
            List<Lead> leads = [SELECT Id, Name FROM Lead LIMIT 10];
            List<ClusterJob__c> jobs = [SELECT Id FROM ClusterJob__c LIMIT 1];
            Id jobId = jobs[0].Id;
            Id recordId = leads[0].Id;

            ClusterApi api = new ClusterApi();
            api.setModelOrJobId(jobId);
            ClusterPredictionResult predictionResult = api.predict(recordId, false);

            System.assertEquals(true, predictionResult.getClusterIndex() >= 0, 'Incorrect prediction cluster index');
            ClusterDataPoint dataPoint = api.getDataPoint(recordId);
            System.assertEquals(recordId, dataPoint.getExternalId(), 'Incorrect data point id');
            Double distance = api.calculateDistance(dataPoint.getValues(), dataPoint.getValues());
            System.assertEquals(true, ClusterDataHelper.doublesEqual(distance, ClusterDataHelper.DOUBLE_ZERO), 'Incorrect distance');
            Test.stopTest();
        }
    }

    @isTest
    public static void testKNN() {
        ClusterTestData.runKMeans();
        User clusterUser = ClusterTestData.createClusterUser();
        System.runAs(clusterUser) {
            Test.startTest();
            List<Lead> leads = [SELECT Id, Name FROM Lead LIMIT 11];
            List<ClusterJob__c> jobs = [SELECT Id FROM ClusterJob__c LIMIT 1];
            Id jobId = jobs[0].Id;
            Id recordId = leads[0].Id;

            ClusterApi api = new ClusterApi();
            api.setModelOrJobId(jobId);
            List<ClusterDataPointNeighbor> neighbors = api.findNearestNeighbors(recordId, 5, false);

            System.assertEquals(5, neighbors.size(), 'Incorrect nn size');
            System.assertEquals(true, neighbors[1].distance >= neighbors[0].distance, 'Incorrect nn sorting');

            neighbors = api.getNearestNeighborsFromDb(recordId, 5);
            System.assertEquals(5, neighbors.size(), 'Incorrect nn size');
            Test.stopTest();
        }
    }


}
