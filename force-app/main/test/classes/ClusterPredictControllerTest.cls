@isTest
public with sharing class ClusterPredictControllerTest {

    @isTest
    public static void testJobStateLoading() {
        String jobStateJson = ClusterTestData.loadTextFromStaticResource('JobStateTest');
        ClusterKMeansJobState jobState = new ClusterKMeansJobState();
        Map<String, Object> valuesMap = (Map<String, Object>)JSON.deserializeUntyped(jobStateJson);
        jobState.loadFromMap(valuesMap);
        System.assertEquals('lead', jobState.model.objectName.toLowerCase(), 'Incorrect model object name');
        System.assertEquals(4, jobState.centroids.size(), 'Incorrect number of centroids');
        System.assertEquals(5, jobState.minMaxValues.size(), 'Incorrect number of minMaxValues');
        System.assertEquals(true, ClusterDataHelper.doublesEqual(Double.valueOf(jobState.minMaxValues[0].minValue), Double.valueOf(31090.0)), 'Incorrect minValue');
        System.assertEquals(true, ((List<String>)jobState.minMaxValues[1].minValue).size() > 0, 'Incorrect minValue size');
        System.assertEquals(true, ((ClusterCompressedDoubleArray)jobState.minMaxValues[1].maxValue).size() > 0, 'Incorrect minValue size');
    }
    
}
