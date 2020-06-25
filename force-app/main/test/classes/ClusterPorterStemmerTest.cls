@isTest
public with sharing class ClusterPorterStemmerTest {
    @isTest
    public static void testPorterStemmer() {
        ClusterPorterStemmer stemmer = new ClusterPorterStemmer();
        System.assertEquals(stemmer.stem('deny'), 'deni', 'Stemmer test failed' );
        System.assertEquals(stemmer.stem('declining'), 'declin', 'Stemmer test failed' );
        System.assertEquals(stemmer.stem('diversity'), 'divers', 'Stemmer test failed' );
        System.assertEquals(stemmer.stem('divers'), 'diver', 'Stemmer test failed' );
        System.assertEquals(stemmer.stem('dental'), 'dental', 'Stemmer test failed' );
    }
}
