@isTest
public with sharing class ClusterLongTextFieldValueProcessorTest {

    @isTest
    public static void testTfIdf() {
        User clusterUser = ClusterTestData.createClusterUser();
        System.runAs(clusterUser) {
            ClusterWordPreprocessor wordPreprocessor = new ClusterWordPreprocessor('english');
            Map<String, Integer> wordMap = new Map<String,Integer>();
            List<String> wordList = new List<String>();
            String text = 'Never cared for what they do, \r\n Never \n cared <b>for</b> what <br> they know! Yeah';
            Double[] tf = ClusterLongTextFieldValueProcessor.calculateTF(text, wordMap, wordList, wordPreprocessor);
            System.assertEquals(true, wordMap.containsKey('never'), 'TF word parsing failed');
            System.assertEquals(false, wordMap.containsKey('do'), 'TF word parsing failed');
            System.assertEquals(true, wordMap.containsKey('know'), 'TF word parsing failed');
            System.assertEquals('care', wordList.get(1), 'TF word parsing failed');
            System.assertEquals(4, wordList.size(), 'TF word parsing failed');
            System.assertEquals(2, wordMap.get('never'), 'TF word count failed');
            System.assertEquals(1, wordMap.get('know'), 'TF word count failed');
            System.assertEquals(1, wordMap.get('yeah'), 'TF word count failed');
            System.assertEquals(true, ClusterDataHelper.doublesEqual(tf[0], Double.valueOf(2.0)/Double.valueOf(6.0)), 'TF calculated incorrectly');

            String text2 = 'Never cared for what they say, Never cared for games they play';
            Double[] tf2 = ClusterLongTextFieldValueProcessor.calculateTF(text2, wordMap, wordList, wordPreprocessor);
            System.assertEquals(4, wordMap.get('never'), 'TF word count failed for text2');
            System.assertEquals(1, wordMap.get('yeah'), 'TF word count failed for text2');

            Double[] idf = ClusterLongTextFieldValueProcessor.calculateIDF(wordList, wordMap, 2);
            System.assertEquals(true, ClusterDataHelper.doublesEqual(Math.log10(Double.valueOf(2) / Double.valueOf(4)), idf[0]), 'IDF calculated incorrectly');

            Double[] tf3 = ClusterLongTextFieldValueProcessor.calculateTF(text, wordMap, wordList, wordPreprocessor);
            
            Double cosineDistance = ClusterDataHelper.calculateCosineDistance(tf, tf3, idf);
            System.assertEquals(true, ClusterDataHelper.doublesEqual(cosineDistance, Double.valueOf(0.0)), 'Cosine distance calculated incorrectly');
            cosineDistance = ClusterDataHelper.calculateCosineDistance(tf, tf2, idf);
            System.assertEquals(true, cosineDistance > 0.0, 'Cosine distance calculated incorrectly');
        }
    }
}