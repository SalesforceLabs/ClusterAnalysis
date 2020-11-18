@isTest
public with sharing class ClusterDataHelperTest {
    @isTest
    public static void testCompareFieldValueAbs() {
        ClusterModelFieldWrapper field = new ClusterModelFieldWrapper();
        field.distanceType = ClusterConstants.FIELDTYPE_NUMERIC;
        Integer result = ClusterDataHelper.compareFieldValueAbs(null, 1, field);
        System.assertEquals(-1, result, 'Failed null compare to number');
        result = ClusterDataHelper.compareFieldValueAbs(1, null, field);
        System.assertEquals(1, result, 'Failed number compare to null');
        result = ClusterDataHelper.compareFieldValueAbs(2, 1, field);
        System.assertEquals(1, result, 'Failed number compare');
    }

    @isTest
    public static void testDistanceFunctions() {
        Double d = ClusterDataHelper.calculateCategoryGowerDistance('test1', 'test2');
        System.assertEquals(1, Integer.valueOf(d), 'Category distance test failed');
        d = ClusterDataHelper.calculateCategoryGowerDistance('test1', 'test1');
        System.assertEquals(0, Integer.valueOf(d), 'Category distance test failed');
        d = ClusterDataHelper.calculateTextGowerDistance('test1', 'test2', 1, 1);
        System.assertEquals(1, Integer.valueOf(d), 'Text distance test failed');
        d = ClusterDataHelper.calculateTextGowerDistance('test1', 'test1', 1, 1);
        System.assertEquals(0, Integer.valueOf(d), 'Text distance test failed');
        d = ClusterDataHelper.calculateNumericGowerDistance(100, 50, 1);
        System.assertEquals(50, Integer.valueOf(d), 'Numeric distance test failed');
    }

    @isTest
    public static void testClusterJobResultJsonValues() {
        ClusterJobResult__c result = new ClusterJobResult__c();
        Integer[] values = new Integer[100];
        for (Integer i=0; i<values.size(); i++) {
            values[i] = i;
        }
        String json1 = JSON.serialize(values);
        ClusterDataHelper.populateClusterJobResultJsonValues(result, json1, 100);
        String json2 = ClusterDataHelper.getClusterJobResultValues(result);
        System.assertEquals(json1, json2, 'ClusterJobResult json values comparisson failed');
        Integer[] values2 = (Integer[])JSON.deserialize(json2, Integer[].class);
        for (Integer i=0; i<values.size(); i++) {
            System.assertEquals(values[i], values2[i], 'ClusterJobResult deserialized json values comparisson failed');
        }
        ClusterDataHelper.populateClusterJobResultJsonValues(result, json1);
        json2 = ClusterDataHelper.getClusterJobResultValues(result);
        System.assertEquals(json1, json2, 'ClusterJobResult json values comparisson 2 failed');
        json1 = '012345678901234567890123456789';
        ClusterDataHelper.populateClusterJobResultJsonValues(result, json1, 10);
        json2 = ClusterDataHelper.getClusterJobResultValues(result);
        System.assertEquals(json1, json2, 'ClusterJobResult json values comparisson 3 failed');
        json1 = '';
        ClusterDataHelper.populateClusterJobResultJsonValues(result, json1, 10);
        json2 = ClusterDataHelper.getClusterJobResultValues(result);
        System.assertEquals(json1, json2, 'ClusterJobResult json values comparisson 4 failed');
        json1 = null;
        ClusterDataHelper.populateClusterJobResultJsonValues(result, json1, 10);
        json2 = ClusterDataHelper.getClusterJobResultValues(result);
        System.assertEquals(true, json2 == null, 'ClusterJobResult json values comparisson 5 failed');
    }

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