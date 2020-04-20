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

}
