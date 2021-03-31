@isTest
public with sharing class ClusterLongTextFieldValueProcessorTest {

    @isTest
    public static void testTfIdf() {
        User clusterUser = ClusterTestData.createClusterUser();
        System.runAs(clusterUser) {
            ClusterWordPreprocessor wordPreprocessor = new ClusterWordPreprocessor('english');
            Map<String, Integer> wordMap = new Map<String,Integer>();
            List<String> wordList = new List<String>();
            String text = 'Never cared for what they do, \r\n Never \n cared <b>for</b> what <br> they know! Yeah Yeah';
            Double[] tf = ClusterLongTextFieldValueProcessor.calculateTF(text, wordMap, wordList, wordPreprocessor, 2, ClusterConstants.MAX_TFIDF_WORDBAG_SIZE);
            System.assertEquals(true, wordMap.containsKey('never'), 'TF word parsing failed');
            System.assertEquals(false, wordMap.containsKey('do'), 'TF word parsing failed');
            System.assertEquals(false, wordMap.containsKey('know'), 'TF word parsing failed');
            System.assertEquals('care', wordList.get(1), 'TF word parsing failed');
            System.assertEquals(3, wordList.size(), 'TF word parsing failed');
            System.assertEquals(1, wordMap.get('never'), 'TF word count failed');
            System.assertEquals(true, wordMap.get('know') == null, 'TF word count failed');
            System.assertEquals(1, wordMap.get('yeah'), 'TF word count failed');
            System.assertEquals(true, ClusterDataHelper.doublesEqual(tf[0], Double.valueOf(2.0)/Double.valueOf(6.0)), 'TF calculated incorrectly');

            String text2 = 'Never cared for what they say, Never cared for games they play play';
            Double[] tf2 = ClusterLongTextFieldValueProcessor.calculateTF(text2, wordMap, wordList, wordPreprocessor, 2, ClusterConstants.MAX_TFIDF_WORDBAG_SIZE);
            System.assertEquals(2, wordMap.get('never'), 'TF word count failed for text2');
            System.assertEquals(1, wordMap.get('yeah'), 'TF word count failed for text2');

            Double[] idf = ClusterLongTextFieldValueProcessor.calculateIDF(wordList, wordMap, 2);
            System.assertEquals(true, ClusterDataHelper.doublesEqual(Math.log10(Double.valueOf(2) / Double.valueOf(2)), idf[0]), 'IDF calculated incorrectly');

            Double[] tf3 = ClusterLongTextFieldValueProcessor.calculateTF(text, wordMap, wordList, wordPreprocessor, 2, ClusterConstants.MAX_TFIDF_WORDBAG_SIZE);
            
            ClusterCompressedDoubleArray ctf = new ClusterCompressedDoubleArray(tf);
            ClusterCompressedDoubleArray ctf2 = new ClusterCompressedDoubleArray(tf2);
            ClusterCompressedDoubleArray ctf3 = new ClusterCompressedDoubleArray(tf3);
            ClusterCompressedDoubleArray cidf = new ClusterCompressedDoubleArray(idf);
            ClusterMinMaxValue minMax = new ClusterMinMaxValue();
            minMax.maxValue = cidf;
            Double cosineDistance = ClusterDataHelper.calculateCosineDistance(ctf, ctf3, minMax);
            System.assertEquals(true, ClusterDataHelper.doublesEqual(cosineDistance, Double.valueOf(0.0)), 'Cosine distance calculated incorrectly');
            cosineDistance = ClusterDataHelper.calculateCosineDistance(ctf, ctf2, minMax);
            System.assertEquals(true, cosineDistance > 0.0, 'Cosine distance calculated incorrectly');

            cosineDistance = 1.0 - ClusterDataHelper.calculateCosineSimilarity(tf, tf3, idf);
            System.assertEquals(true, ClusterDataHelper.doublesEqual(cosineDistance, Double.valueOf(0.0)), 'Cosine distance calculated incorrectly');
            cosineDistance = 1.0 - ClusterDataHelper.calculateCosineSimilarity(tf, tf2, idf);
            System.assertEquals(true, cosineDistance > 0.0, 'Cosine distance calculated incorrectly');

            //Testing fallback to word count 1
            wordMap = new Map<String,Integer>();
            wordList = new List<String>();
            String text4 = 'Never cared for what they say';
            Double[] tf4 = ClusterLongTextFieldValueProcessor.calculateTF(text4, wordMap, wordList, wordPreprocessor, 2, ClusterConstants.MAX_TFIDF_WORDBAG_SIZE);
            System.assertEquals(1, wordMap.get('never'), 'TF word count failed for text4');
            System.assertEquals(1, wordMap.get('care'), 'TF word count failed for text4');

            wordMap = new Map<String,Integer>();
            wordList = new List<String>();
            tf4 = ClusterLongTextFieldValueProcessor.calculateTF('a b c d e', wordMap, wordList, wordPreprocessor, 2, ClusterConstants.MAX_TFIDF_WORDBAG_SIZE);
            System.assertEquals(0, tf4.size(), 'TF word count failed for empty tf');
        }
    }

    @isTest
    public static void testTfIdfBrokenHtml() {
        User clusterUser = ClusterTestData.createClusterUser();
        System.runAs(clusterUser) {
            ClusterWordPreprocessor wordPreprocessor = new ClusterWordPreprocessor('english');
            Map<String, Integer> wordMap = new Map<String,Integer>();
            List<String> wordList = new List<String>();
            String text = '<apex:outputLink drops a part of URL. <apex:outputLink drops a part of URL. <apex:outputLink looses part of url when we open link in new tab.. Visualforce. When link is clicked by pressing a control button (to open it in a new tab) on keyboard, it loses the part of the url.. It should show the url completely.';
            Double[] tf = ClusterLongTextFieldValueProcessor.calculateTF(text, wordMap, wordList, wordPreprocessor, 2, ClusterConstants.MAX_TFIDF_WORDBAG_SIZE);
            System.assertEquals(true, wordMap.containsKey('part'), 'TF word parsing failed');
        }
    }

    @isTest
    public static void testTfIdfCompressed() {
        User clusterUser = ClusterTestData.createClusterUser();
        System.runAs(clusterUser) {
            ClusterWordPreprocessor wordPreprocessor = new ClusterWordPreprocessor('english');
            Map<String, Integer> wordMap = new Map<String,Integer>();
            List<String> wordList = new List<String>();
            String text = 'new purchase po purchase po dear purchased has please log allocation after receive item please take consideration mandatory receipts section order make receipt item ordered how video link kind regards administrator';
            String text2 = 'Never cared for what they do, \r\n Never \n cared <b>for</b> what <br> they know! Yeah Yeah';
            ClusterCompressedDoubleArray tf1 = ClusterLongTextFieldValueProcessor.calculateCompressedTF(text, wordMap, wordList, wordPreprocessor, 2, ClusterConstants.MAX_TFIDF_WORDBAG_SIZE);
            ClusterCompressedDoubleArray tf2 = ClusterLongTextFieldValueProcessor.calculateCompressedTF(text2, wordMap, wordList, wordPreprocessor, 2, ClusterConstants.MAX_TFIDF_WORDBAG_SIZE);
            ClusterCompressedDoubleArray idf = ClusterLongTextFieldValueProcessor.calculateCompressedIDF(wordList, wordMap, 2);
            wordMap = new Map<String,Integer>();
            for (String word:wordList) {
                wordMap.put(word, 0);
            }
            ClusterCompressedDoubleArray tf3 = ClusterLongTextFieldValueProcessor.calculateCompressedTF(text, wordMap, wordList, wordPreprocessor, 2, ClusterConstants.MAX_TFIDF_WORDBAG_SIZE);
            
            System.debug('tf1:' + JSON.serialize(tf1));
            System.debug('tf3:' + JSON.serialize(tf3));
            //System.assertEquals(tf3.size(), tf1.size(), 'TF vectors are different');
            ClusterMinMaxValue minMax = new ClusterMinMaxValue();
            minMax.maxValue = idf;
            Double cosineDistance = ClusterDataHelper.calculateCosineDistance(tf1, tf3, minMax);
            System.debug('cosineDistance:' + cosineDistance);
            System.assertEquals(true, ClusterDataHelper.doublesEqual(cosineDistance, ClusterDataHelper.DOUBLE_ZERO), 'Cosine distance incorrect');
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
        System.assertEquals(true, ClusterDataHelper.doublesEqual(ccda.values[0].getValue(), (Double)1.0), 'Incorrect value in compressed array');
        ClusterCompressedDoubleArray.ClusterCompressedDouble ccd = ccda.getCompressedList()[2];
        System.assertEquals(3, ccd.getCount(), 'Incorrect count in compressed array');
        System.assertEquals(true, ClusterDataHelper.doublesEqual(ccd.getValue(), (Double)3.0), 'Incorrect value in compressed array');
        
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

    @isTest
    public static void testCompressedArrayCosineDistance() {
        JSONParser parser1 = JSON.createParser('{"rle":[[2,0],0.0173160,[6,0],0.0129870,[10,0],0.0086580,[12,0],[2,0.0043290],[8,0],0.0043290,0.0086580,[7,0],0.0043290,[7,0],0.0043290,0,0.0129870,0.0389610,[4,0],0.0043290,[3,0],0.0043290,[2,0],0.0043290,[18,0],0.0129870,0,0.0086580,0.0043290,[15,0],0.0086580,[12,0],0.0043290,[13,0],0.0043290,[4,0],0.0043290,[32,0],0.0043290,[17,0],0.0173160,[8,0],0.0043290,[5,0],0.0086580,[4,0],0.0173160,[24,0],0.0043290,[35,0],0.0043290,0.0303030,0.0043290,0.0173160,[4,0],0.0043290,[4,0],0.0043290,' + 
            '[14,0],0.0259740,[9,0],[2,0.0043290],[2,0.0086580],[10,0.0043290],[11,0],0.0086580,[28,0],0.0086580,[3,0],0.0086580,[4,0],0.0043290,0,[2,0.0129870],0.0043290,[17,0],0.0129870,[18,0],0.0129870,0,0.0043290,[23,0],0.0086580,[44,0],0.0086580,[4,0],0.0043290,[17,0],0.0043290,[5,0],0.0173160,0.0129870,[21,0],0.0086580,[4,0],0.0086580,[6,0],0.0043290,0,0.0086580,[10,0],0.0043290,[22,0],0.0043290,[16,0],0.0086580,[3,0],[2,0.0043290],[42,0],0.0043290,[93,0],0.0173160,[46,0],0.0086580,0.0303030,[54,0],0.0086580,[7,0],0.0129870,[3,0],' + 
            '0.0216450,[5,0],0.0086580,[28,0],[2,0.0043290],[27,0],0.0129870,[55,0],0.0043290,[59,0],0.0043290,[65,0],0.0173160,[31,0],0.0086580,[4,0],0.0043290,[49,0],0.0086580,[41,0],0.0173160,[322,0],0.0129870,[102,0],0.0129870,[60,0],0.0129870,[34,0],0.0086580,[51,0],0.0043290,[228,0],0.0086580,[331,0],0.0259740,[133,0],0.0086580,[30,0],0.0086580,[693,0],0.0086580,[243,0],0.0043290,[2430,0],0.0129870,[393,0],0.0129870,0.0086580,0.0216450,[6,0.0043290]]}');

        JSONParser parser2 = JSON.createParser('{"rle":[[2,0],0.0111940,[14,0],0.0074627,[3,0.0037313],[5,0],0.0074627,[5,0],0.0037313,0.0186567,0.0111940,[4,0],0.0037313,[3,0],0.0261194,0.0186567,[7,0],0.0074627,[10,0],0.0149254,0.0037313,[3,0],0.0149254,[3,0],0.0074627,[6,0],0.0037313,[14,0],0.0111940,0,0.0074627,[2,0.0037313],[8,0],0.0037313,0,0.0037313,0,0.0037313,0,[2,0.0074627],[7,0],0.0186567,[3,0],0.0037313,[4,0],0.0074627,[16,0],0.0037313,[29,0],0.0149254,[17,0],0.0037313,[8,0],0.0037313,[19,0],0.0186567,[3,0],0.0111940,[11,0],' + 
            '0.0037313,[11,0],0.0037313,[23,0],0.0037313,0.0074627,0.0037313,[3,0],0.0037313,[19,0],0.0111940,[7,0],0.0186567,[3,0],[2,0.0037313],[2,0.0074627],[5,0.0037313],0.0074627,[3,0.0037313],[11,0],0.0074627,[26,0],[2,0.0037313],0,0.0074627,[4,0],[2,0.0037313],[2,0],0.0037313,0,0.0074627,0,0.0037313,[13,0],0.0111940,[14,0],0.0037313,[26,0],0.0074627,[17,0],0.0037313,[2,0],0.0111940,[45,0],0.0037313,[39,0],0.0037313,[3,0],0.0074627,[41,0],0.0037313,[35,0],0.0037313,[20,0],0.0074627,[5,0],0.0074627,[2,0],0.0223881,[35,0],0.0037313,' + 
            '[26,0],0.0074627,[3,0],0.0298507,0.0186567,[3,0],0.0074627,0,0.0149254,[23,0],0.0037313,[8,0],0.0037313,[15,0],0.0037313,[10,0],[2,0.0111940],0.0186567,[3,0],0.0037313,[8,0],0.0037313,[13,0.0074627],0,0.0037313,[38,0],0.0111940,[3,0],0.0037313,[25,0],0.0037313,[257,0],0.0186567,[48,0],0.0074627,[31,0],0.0037313,[8,0],0.0037313,[43,0],0.0037313,[132,0],0.0037313,[2,0],0.0037313,[77,0],0.0037313,[88,0],0.0037313,[91,0],0.0037313,[83,0],0.0074627,[72,0],0.0037313,[232,0],0.0037313,[499,0],0.0037313,[166,0],0.0037313,[103,0],0.0037313,' + 
            '[1376,0],0.0037313,[137,0],0.0111940,[2127,0],0.0037313,[336,0],0.0037313,[1088,0],0.0074627,[1002,0],0.0037313,[628,0],0.0111940,[4,0.0037313],0.0074627,[6,0.0037313]]}');

        ClusterLongTextFieldValueProcessor ltp = new ClusterLongTextFieldValueProcessor(null);
        ltp.setCompression(true);
        Object o = ltp.parseValueFromJson(parser1);
        System.assertEquals(true, o instanceof ClusterCompressedDoubleArray, 'Compressed json 1 parsed incorrectly');
        ClusterCompressedDoubleArray ccda1 = (ClusterCompressedDoubleArray)o;

        o = ltp.parseValueFromJson(parser2);
        System.assertEquals(true, o instanceof ClusterCompressedDoubleArray, 'Compressed json 2 parsed incorrectly');
        ClusterCompressedDoubleArray ccda2 = (ClusterCompressedDoubleArray)o;

        ClusterCompressedDoubleArray.ClusterCompressedDoubleArrayIterator iterator1 = new ClusterCompressedDoubleArray.ClusterCompressedDoubleArrayIterator(ccda1);
        ClusterCompressedDoubleArray.ClusterCompressedDoubleArrayIterator iterator2 = new ClusterCompressedDoubleArray.ClusterCompressedDoubleArrayIterator(ccda2);
        Integer count = 0,zerocount = 0;
        Boolean hasNext1 = true; Boolean hasNext2 = true;
        List<Double> idf = new List<Double>();
        ClusterCompressedDoubleArray idfda = new ClusterCompressedDoubleArray();
        Long start = DateTime.now().getTime();
        while (hasNext1 || hasNext2) {
            Double v1, v2;
            if (hasNext1 && iterator1.hasNext()) {
                hasNext1 = true;
                v1 = iterator1.next();
            }
            else {
                hasNext1 = false;
                v1 = ClusterDataHelper.DOUBLE_ZERO;                
            }
            if (hasNext2 && iterator2.hasNext()) {
                hasNext2 = true;
                v2 = iterator2.next();
            }
            else {
                hasNext2 = false;
                v2 = ClusterDataHelper.DOUBLE_ZERO;                
            }
            if (ClusterDataHelper.doublesEqual(v1, ClusterDataHelper.DOUBLE_ZERO) && ClusterDataHelper.doublesEqual(v2, ClusterDataHelper.DOUBLE_ZERO)) {
                zerocount++;
            }
            if (hasNext1 || hasNext2) {
                idf.add(Double.valueOf(count));
                idfda.add(idf[idf.size()-1]);            
                count++;
            }
        }
        Long timeTaken = DateTime.now().getTime() - start;
        System.debug('Number of matching zeros: ' + zerocount + ' out of ' + count);
        System.debug('Time taken: ' + timeTaken);

        start = DateTime.now().getTime();
        ClusterDataHelper.CosineSimilarityResult csr = ClusterDataHelper.calculateCosineSimilarity(ccda1, ccda2, idfda);
        timeTaken = DateTime.now().getTime() - start;
        System.debug('First cosine similarity time taken: ' + timeTaken);
        System.assertEquals(idf.size(), idfda.toList().size(), 'Idf arrays are not equal');
        System.assertEquals(idf[idf.size() - 1], csr.idf[csr.idf.size()-1], 'Returned idf array is not equal to the original');
        System.assertEquals(idf.size(), csr.idf.size(), 'Returned idf array size is not equal to the original');
        start = DateTime.now().getTime();
        Double cosineSimilarity = ClusterDataHelper.calculateCosineSimilarity(ccda1, ccda2, csr.idf);
        timeTaken = DateTime.now().getTime() - start;
        System.debug('Second cosine similarity time taken: ' + timeTaken);
        System.assertEquals(true, ClusterDataHelper.doublesEqual(csr.value, cosineSimilarity), 'Fast forward calculations are not correct');


        //Testing a case when tf vectors size is less than idf size
        parser1 = JSON.createParser('{"rle":[[2,0],0.0173160,[6,0],0.0129870,[10,0],0.0086580,[12,0],[2,0.0043290],[6,0.0043290]]}');
        parser2 = JSON.createParser('{"rle":[[2,0],0.0111940,[14,0],0.0074627,[3,0.0037313],[5,0],0.0074627,[5,0],0.0037313,0.0186567,0.0111940,[4,0],0.0037313,[3,0],0.0261194,0.0186567,0.0074627,[16,0.0037313]]}');
        o = ltp.parseValueFromJson(parser1);
        System.assertEquals(true, o instanceof ClusterCompressedDoubleArray, 'Compressed json 1 parsed incorrectly');
        ccda1 = (ClusterCompressedDoubleArray)o;

        o = ltp.parseValueFromJson(parser2);
        System.assertEquals(true, o instanceof ClusterCompressedDoubleArray, 'Compressed json 2 parsed incorrectly');
        ccda2 = (ClusterCompressedDoubleArray)o;

        csr = ClusterDataHelper.calculateCosineSimilarity(ccda1, ccda2, idfda);
        System.assertEquals(csr.idf.size(), idfda.toList().size(), 'Idf arrays are not equal');
        System.assertEquals(idf[idf.size() - 1], csr.idf[csr.idf.size()-1], 'Returned idf array is not equal to the original');
        System.assertEquals(idf.size(), csr.idf.size(), 'Returned idf array size is not equal to the original');
        cosineSimilarity = ClusterDataHelper.calculateCosineSimilarity(ccda1, ccda2, csr.idf);
    }
}