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
            System.assertEquals(1, wordMap.get('never'), 'TF word count failed');
            System.assertEquals(1, wordMap.get('know'), 'TF word count failed');
            System.assertEquals(1, wordMap.get('yeah'), 'TF word count failed');
            System.assertEquals(true, ClusterDataHelper.doublesEqual(tf[0], Double.valueOf(2.0)/Double.valueOf(6.0)), 'TF calculated incorrectly');

            String text2 = 'Never cared for what they say, Never cared for games they play';
            Double[] tf2 = ClusterLongTextFieldValueProcessor.calculateTF(text2, wordMap, wordList, wordPreprocessor);
            System.assertEquals(2, wordMap.get('never'), 'TF word count failed for text2');
            System.assertEquals(1, wordMap.get('yeah'), 'TF word count failed for text2');

            Double[] idf = ClusterLongTextFieldValueProcessor.calculateIDF(wordList, wordMap, 2);
            System.assertEquals(true, ClusterDataHelper.doublesEqual(Math.log10(Double.valueOf(2) / Double.valueOf(2)), idf[0]), 'IDF calculated incorrectly');

            Double[] tf3 = ClusterLongTextFieldValueProcessor.calculateTF(text, wordMap, wordList, wordPreprocessor);
            
            Double cosineDistance = ClusterDataHelper.calculateCosineDistance(tf, tf3, idf);
            System.assertEquals(true, ClusterDataHelper.doublesEqual(cosineDistance, Double.valueOf(0.0)), 'Cosine distance calculated incorrectly');
            cosineDistance = ClusterDataHelper.calculateCosineDistance(tf, tf2, idf);
            System.assertEquals(true, cosineDistance > 0.0, 'Cosine distance calculated incorrectly');
        }
    }

    private static void testCDAIterators(ClusterCompressedDoubleArray ccda, List<Double> da) {
        //Testing hasNext/next
        ClusterCompressedDoubleArray.ClusterCompressedDoubleArrayIterator iterator = new ClusterCompressedDoubleArray.ClusterCompressedDoubleArrayIterator(ccda);
        List<Double> da1 = new List<Double>();
        while (iterator.hasNext()) {
            Double d = iterator.next();
            System.debug(d);
            da1.add(d);
        }
        System.assertEquals(da.size(), da1.size(), 'Incorrect size of the compressed array');
        for (Integer i=0; i<da.size(); i++) {
            System.assertEquals(true, ClusterDataHelper.doublesEqual(da[i], da1[i]), 'Double array values are not equal');
        }

        //Testing moveNext/getValue
        iterator = new ClusterCompressedDoubleArray.ClusterCompressedDoubleArrayIterator(ccda);
        da1 = new List<Double>();
        while (iterator.moveNext()) {
            da1.add(iterator.getValue());
        }
        System.assertEquals(da.size(), da1.size(), 'Incorrect size of the compressed array');
        for (Integer i=0; i<da.size(); i++) {
            System.assertEquals(true, ClusterDataHelper.doublesEqual(da[i], da1[i]), 'Double array values are not equal');
        }

    }

    @isTest
    public static void testCompressedDoubleArray() {
        List<Double> da = new List<Double>();
        da.add(1.0);
        da.add(2.0);
        da.add(3.0);
        da.add(3.0);
        da.add(3.0);
        da.add(2.1);
        da.add(2.1);
        da.add(1.0);
        ClusterCompressedDoubleArray ccda = new ClusterCompressedDoubleArray();
        for (Double d:da) {
            ccda.add(d);
        }
        //Testing compression
        System.assertEquals(true, ClusterDataHelper.doublesEqual((Double)ccda.values[0], (Double)1.0), 'Incorrect value in compressed array');
        ClusterCompressedDoubleArray.ClusterCompressedDouble ccd = (ClusterCompressedDoubleArray.ClusterCompressedDouble)ccda.values[2];
        System.assertEquals(3, ccd.count, 'Incorrect count in compressed array');
        System.assertEquals(true, ClusterDataHelper.doublesEqual(ccd.value, (Double)3.0), 'Incorrect value in compressed array');
        
        //Testing last double
        testCDAIterators(ccda, da);

        //Testing last compressed double
        da.add(1.0);
        ccda.add((Double)1.0);
        testCDAIterators(ccda, da);
    }

    @isTest
    public static void testLongTextParser() {
        JSONParser parser = JSON.createParser('{"rle":[0,0.0377358,[2,0],[3,0.0188679],[20,0],0.0188679,[10,0],0.0377358,0.0188679,[3,0],[3,0.0188679],[11,0],0.0188679,[24,0],0.0188679,[10,0],0.0188679,[71,0],0.0188679,[63,0],[6,0.0188679],0.0566038,[2,0.0188679],[6,0.0377358],[4,0.0188679],0.0566038,[2,0.0377358],[3,0.0188679]]}');
        ClusterLongTextFieldValueProcessor ltp = new ClusterLongTextFieldValueProcessor(null);
        ltp.setCompression(true);
        Object o = ltp.parseValueFromJson(parser);
        System.assertEquals(true, o instanceof ClusterCompressedDoubleArray, 'Compressed json parsed incorrectly');
        ClusterCompressedDoubleArray ccda = (ClusterCompressedDoubleArray)o;
        ClusterCompressedDoubleArray.ClusterCompressedDoubleArrayIterator iterator = new ClusterCompressedDoubleArray.ClusterCompressedDoubleArrayIterator(ccda);
        List<Double> da1 = new List<Double>();
        Integer count = 0;
        while (iterator.hasNext()) {
            Double d = iterator.next();
            System.debug(d);
            da1.add(d);
            count++;
        }
        System.assertEquals(true, ClusterDataHelper.doublesEqual(da1[0], (Double)0.0), 'Incorrect value in compressed array');
        System.assertEquals(true, ClusterDataHelper.doublesEqual(da1[1], (Double)0.0377358), 'Incorrect value in compressed array');
        System.assertEquals(true, ClusterDataHelper.doublesEqual(da1[2], (Double)0.0), 'Incorrect value in compressed array');
        System.assertEquals(true, ClusterDataHelper.doublesEqual(da1[3], (Double)0.0), 'Incorrect value in compressed array');
        System.assertEquals(true, ClusterDataHelper.doublesEqual(da1[4], (Double)0.0188679), 'Incorrect value in compressed array');
        System.assertEquals(true, ClusterDataHelper.doublesEqual(da1[7], (Double)0.0), 'Incorrect value in compressed array');
        System.assertEquals(254, count, 'Incorrect decompressed array length');
    }
}