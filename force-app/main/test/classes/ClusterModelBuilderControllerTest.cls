@isTest
public class ClusterModelBuilderControllerTest {
    @isTest static void testModelSaveLoad() {
        User clusterAdmin = ClusterTestData.createClusterAdmin();
        System.runAs(clusterAdmin) {
            String modelJson = 
    '{"isCustomSoql":false,"soql":"SELECT AccountNumber, AccountSource, AnnualRevenue, Id FROM Account","filter":"{\\"expressionFields\\":[],\\"customLogic\\":\\"\\"}",' + 
    '"fields":[{"name":"AccountNumber","displayLabel":"Account Number","relationName":"","objectName":"Account","distanceType":"Text","weight":1},' + 
    '{"name":"AccountSource","displayLabel":"Account Source","relationName":"","objectName":"Account","distanceType":"Category","weight":1},' + 
    '{"name":"AnnualRevenue","displayLabel":"Annual Revenue","relationName":"","objectName":"Account","distanceType":"Numeric","weight":1},' + 
    '{"name":"Id","displayLabel":"Account ID","relationName":"","objectName":"Account","distanceType":"None","weight":1}],"algorithm":"K-Medoids","numberOfClusters":"5","name":"test","objectName":"Account"}';
            //Testing insert model
            ClusterModelWrapper wrapper = ClusterModelBuilderController.saveModel(modelJson);
            System.assertEquals(true, wrapper != null && wrapper.modelId != null, 'saveModel should return id');
            //Testing load UI model
            ClusterModelBuilderUiModel uiModel = ClusterModelBuilderController.getModel(wrapper.modelId);
            System.assertEquals(true, uiModel != null && uiModel.model != null, 'getModel should return model instance');
            System.assertEquals(true, uiModel.model.modelId == wrapper.modelId && uiModel.model.name == wrapper.name && uiModel.model.numberOfClusters == wrapper.numberOfClusters, 'Mismatch between saved and loaded model data');
            System.assertEquals(wrapper.fields.size(), uiModel.model.fields.size(), 'Mismatch between saved and loaded field count');
            //Testing update model
            wrapper.numberOfClusters = 10;
            wrapper = ClusterModelBuilderController.saveModel(JSON.serialize(wrapper));
            wrapper = ClusterModelBuilderController.loadModel(wrapper.modelId);
            System.assertEquals(10, wrapper.numberOfClusters, 'Mismatch between saved and loaded number of clusters');
        }
    }
}