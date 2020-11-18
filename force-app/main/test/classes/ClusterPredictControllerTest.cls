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
            System.assertEquals(true, results.size() > 0, 'Incorrect search result count');
            System.assertEquals('Lead', results[0].getSObjectType(), 'Incorrect search result type');
            Test.stopTest();
        }
    }

    @isTest
    public static void testGetModel() {
        ClusterKMeansRunnerTest.testKMeans();
        User clusterUser = ClusterTestData.createClusterUser();
        System.runAs(clusterUser) {
            List<Lead> leads = [SELECT Id, Name FROM Lead LIMIT 10];
            ClusterPredictUiModel uiModel = ClusterPredictController.getPredictUiModel(leads[0].Id);
            System.assertEquals(1, uiModel.models.size(), 'Incorrect predict model size');
            System.assertEquals(true, uiModel.jobId != null, 'Incorrect predict job Id');
            System.assertEquals(false, uiModel.recordIdNeeded, 'Incorrect recordIdNeeded value');
            ClusterPredictUiModel.PredictJobCluster predictCluster = ClusterPredictController.predict(leads[0].Id, uiModel.jobId);
            System.assertEquals(true, predictCluster.clusterIndex >= 0, 'Incorrect predict cluster index');
            System.assertEquals(String.valueOf(leads[0].Id), predictCluster.dataPoint.externalId, 'Incorrect predict datapoint id');
        }
    }
}
