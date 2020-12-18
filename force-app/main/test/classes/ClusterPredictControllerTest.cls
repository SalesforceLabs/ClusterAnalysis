@isTest
public with sharing class ClusterPredictControllerTest {
    @TestSetup
    static void createLeads(){
        ClusterTestData.createLeads();
    }    

    @isTest
    public static void testSearch() {
        ClusterModelWrapper model = ClusterTestData.createLongTextModel();
        User clusterUser = ClusterTestData.createClusterUser();
        System.runAs(clusterUser) {
            Test.startTest();
            List<Lead> leads = [SELECT Id, Name FROM Lead LIMIT 10];
            Id[] fixedSearchResults = new Id[1];
            fixedSearchResults[0] = leads.get(0).Id;
            Test.setFixedSearchResults(fixedSearchResults);
            List<ClusterLookupSearchResult> results = ClusterPredictController.search('Barrat', null, model.modelId);
            System.assertEquals(0, results.get(0).compareTo(results.get(0)), 'Search results comparison failed');
            System.assertEquals(true, results.size() > 0, 'Incorrect search result count');
            System.assertEquals('Lead', results[0].getSObjectType(), 'Incorrect search result type');
            Test.stopTest();
        }
    }

    @isTest
    public static void testGetModel() {
        ClusterTestData.runKMeans();
        User clusterUser = ClusterTestData.createClusterUser();
        System.runAs(clusterUser) {
            Test.startTest();
            List<Lead> leads = [SELECT Id, Name FROM Lead LIMIT 10];
            ClusterPredictUiModel uiModel = ClusterPredictController.getPredictUiModel(leads[0].Id);
            System.assertEquals(1, uiModel.models.size(), 'Incorrect predict model size');
            System.assertEquals(true, uiModel.jobId != null, 'Incorrect predict job Id');
            System.assertEquals(false, uiModel.recordIdNeeded, 'Incorrect recordIdNeeded value');
            ClusterPredictController.findNearestNeighbors(leads[0].Id, uiModel.jobId, ClusterConstants.MAX_NEIGHBORS);
            ClusterPredictUiModel.PredictResultModel predictResult = ClusterPredictController.predict(leads[0].Id, uiModel.models[0].name, true);
            System.assertEquals(true, predictResult.clusterIndex >= 0, 'Incorrect cluster index when cached');
            Test.stopTest();
        }
    }

    @isTest
    public static void testPredict() {
        ClusterTestData.runKMeans();
        User clusterUser = ClusterTestData.createClusterUser();
        System.runAs(clusterUser) {
            Test.startTest();
            List<Lead> leads = [SELECT Id, Name FROM Lead LIMIT 10];
            ClusterPredictUiModel uiModel = ClusterPredictController.getPredictUiModel(leads[0].Id);
            ClusterPredictUiModel.PredictResultModel predictResult = ClusterPredictController.predict(leads[0].Id, uiModel.models[0].name, false);
            System.assertEquals(true, predictResult.clusterIndex >= 0, 'Incorrect cluster index when using model name');

            predictResult = ClusterPredictController.predict(leads[0].Id, uiModel.jobId, false);
            System.assertEquals(true, predictResult.clusterIndex >= 0, 'Incorrect predict cluster index');
            System.assertEquals(String.valueOf(leads[0].Id), predictResult.dataPoint.externalId, 'Incorrect predict datapoint id');
            Test.stopTest();
        }
    }


    @isTest
    public static void testGetModelNoJobs() {
        ClusterModelWrapper model = ClusterTestData.createLongTextModel();
        User clusterUser = ClusterTestData.createClusterUser();
        System.runAs(clusterUser) {
            Test.startTest();
            List<Lead> leads = [SELECT Id, Name FROM Lead LIMIT 10];
            Boolean hadError = false;
            try {
                ClusterPredictUiModel uiModel = ClusterPredictController.getPredictUiModel(model.modelId);
            }
            catch (ClusterException ex) {
                hadError = true;
            }
            System.assertEquals(true, hadError, 'Incorrect handling of models without jobs (getPredictUiModel)');
            hadError = false;
            try {
                ClusterPredictUiModel.PredictResultModel predictResult = ClusterPredictController.predict(leads[0].Id, model.modelId, false);
            }
            catch (ClusterException ex) {
                hadError = true;
            }
            System.assertEquals(true, hadError, 'Incorrect handling of models without jobs (predict)');
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
            ClusterPredictKNNUiModel uiModel = ClusterPredictController.getNearestNeighbors(recordId, jobId, 3);
            System.assertEquals(3, uiModel.nearestNeighbors.size(), 'Incorrect nn size');
            System.assertEquals(true, uiModel.nearestNeighbors[1].distance >= uiModel.nearestNeighbors[0].distance, 'Incorrect nn sorting');
            ClusterPredictKNNUiModel uiModel2 = ClusterPredictController.pullNearestNeighbors(recordId, jobId, 3);
            System.assertEquals(uiModel.nearestNeighbors.size(), uiModel2.nearestNeighbors.size(), 'Incorrect pull nn size');
            Test.stopTest();
        }
    }

}
