public with sharing class ClusterConstants {
    public static final String JOBSTATUS_NEW = 'New';
    public static final String JOBSTATUS_SCHEDULLED = 'Scheduled';
    public static final String JOBSTATUS_IN_PROGRESS = 'InProgress';
    public static final String JOBSTATUS_COMPLETED = 'Completed';
    public static final String JOBSTATUS_MARKED_FOR_CANCEL = 'MarkedForCancel';
    public static final String JOBSTATUS_FAILED = 'Failed';
    public static final String JOBSTATUS_CANCELLED = 'Cancelled';

    public static final String FIELDTYPE_NUMERIC = 'Numeric';
    public static final String FIELDTYPE_CATEGORY = 'Category';
    public static final String FIELDTYPE_TEXT = 'Text';
    public static final String FIELDTYPE_LONGTEXT = 'LongText';
    public static final String FIELDTYPE_NONE = 'None';
    public static final String FIELDTYPE_OUTPUT = 'Output';
    public static final String FIELDTYPE_PREDICTION = 'Prediction';

    public static final String ALGORITHM_KMEANS = 'K-Means';
    public static final String ALGORITHM_KMEDOIDS = 'K-Medoids';

    public static final String DISTANCE_MANHATTAN = 'Manhattan';
    public static final String DISTANCE_EUCLIDEAN = 'Euclidean';
    public static final String DISTANCE_GOWER = 'Gower';

    public static final String LANGUAGE_NONE = 'none';
    public static final Integer MAX_TFIDF_WORDBAG_SIZE = 25000; //Max size of word list for tf-idf
    public static final Integer MAX_JSON_FIELD_SIZE = 131072;

    public static final Integer TEST_BATCH_SIZE = 200;
    public static final Integer KMEANS_CACHE_SIZE = 10000;
    public static final Integer NUM_NEAREST_CLUSTERS = 3;
    public static final Integer NUM_NEAREST_NEIGHBORS_PREDICTION = 7;
    public static final Integer MAX_NEIGHBORS = 50;
    public static final Integer MAX_PREDICTION_VALUES = 5;
    public static final Integer MIN_KNN_DP_COUNT = 25;
    public static final Double KNN_NEIGHBORHOOD_DISTANCE = 0.99; //Max distance between neighbors

    public static final Integer MAX_LONGTEXTCLASSES = 35;
    public static final Integer MIN_LONGTEXTCLASSES = 10;

    private static Map<String, Set<String>> stopWords = new Map<String, Set<String>>();
    private static List<UiSelectOption> supportedLanguages = null;

    private static Integer getIntegerSettingValue(String name, Integer defaultValue) {
        Integer intValue = defaultValue;
        try {
            ClusterAccessCheck.checkReadPermission(Schema.SObjectType.ClusterSetting__mdt);
            //Read permission is checked in ClusterAccessCheck.checkReadPermission, exception is thrown in case of no access
            List<ClusterSetting__mdt> settings = [SELECT DeveloperName, Value__c FROM ClusterSetting__mdt WHERE DeveloperName = :name];
            if (settings.size() > 0) {
                if (settings[0].Value__c != null && settings[0].Value__c != '') {
                    intValue = Integer.valueOf(settings[0].Value__c);
                }
            }
        }
        catch (Exception ex) {
            LogFactory.getLogger().error('Error getting custom setting ' + name, ex);            
        }
        return intValue;
    }

    private static String getStringSettingValue(String name, String defaultValue) {
        String value = defaultValue;
        try {
            ClusterAccessCheck.checkReadPermission(Schema.SObjectType.ClusterSetting__mdt);
            //Read permission is checked in ClusterAccessCheck.checkReadPermission, exception is thrown in case of no access
            List<ClusterSetting__mdt> settings = [SELECT DeveloperName, Value__c FROM ClusterSetting__mdt WHERE DeveloperName = :name];
            if (settings.size() > 0) {
                if (settings[0].Value__c != null) {
                    value = settings[0].Value__c;
                }
            }
        }
        catch (Exception ex) {
            LogFactory.getLogger().error('Error getting custom setting ' + name, ex);            
        }
        return value;
    }


    private static String getLongTextSettingValue(String name, String defaultValue) {
        String textValue = defaultValue;
        try {
            ClusterAccessCheck.checkReadPermission(Schema.SObjectType.ClusterSetting__mdt);
            //Read permission is checked in ClusterAccessCheck.checkReadPermission, exception is thrown in case of no access
            List<ClusterSetting__mdt> settings = [SELECT DeveloperName, LongTextValue__c FROM ClusterSetting__mdt WHERE DeveloperName = :name];
            if (settings.size() > 0) {
                if (settings[0].LongTextValue__c != null && settings[0].LongTextValue__c != '') {
                    textValue = settings[0].LongTextValue__c;
                }
            }
        }
        catch (Exception ex) {
            LogFactory.getLogger().error('Error getting custom setting ' + name, ex);            
        }
        return textValue;
    }

    public static Integer getBatchSize() {
        return getIntegerSettingValue('BatchSize', 1000); 
    }

    public static Integer getLongTextBatchSize() {
        return getIntegerSettingValue('LongTextBatchSize', 100);
    }

    public static Integer getKMedoidsBatchSize() {
        return getIntegerSettingValue('KMedoidsBatchSize', 200);
    }

    public static Integer getKMedoidsLongTextBatchSize() {
        return getIntegerSettingValue('KMedoidsLongTextBatchSize', 20);
    }

    public static Integer getKMedoidsSwapBatchSize() {
        return getIntegerSettingValue('KMedoidsSwapBatchSize', 200);
    }

    public static Integer getInitCentroidStepBatchSize() {
        return 5;
    }

    public static Integer getInitCentroidStepLongTextBatchSize() {
        return 1;
    }

    public static Integer getAttachmentMaxSize() {
        return 4*1024*1024; //TODO: move this to settings
    }

    public static Integer getSampleRecordSize(ClusterModelWrapper model) {
        return getIntegerSettingValue('SampleRecordSize', 40 + 2*model.numberOfClusters);
    }

    public static Integer getMaxSwapIterations() {
        return 100; 
    }

    public static Integer getMaxIterations() {
        return 200; 
    }

    public static Integer getTSNEPlotLimit() {
        return getIntegerSettingValue('TSNESize', 500); 
    }

    public static List<UiSelectOption> getSupportedModelLanguages() {
        if (supportedLanguages == null) {
            ClusterAccessCheck.checkReadPermission(Schema.SObjectType.ClusterLanguage__mdt);
            List<ClusterLanguage__mdt> languages = [SELECT DeveloperName, MasterLabel FROM ClusterLanguage__mdt WHERE DeveloperName <> :LANGUAGE_NONE ORDER BY MasterLabel];
            List<UiSelectOption> langList = new List<UiSelectOption>();
            langList.add(new UiSelectOption('None', 'None'));
            for (ClusterLanguage__mdt language : languages) {
                langList.add(new UiSelectOption(language.DeveloperName, language.MasterLabel));
            }
            supportedLanguages = langList;
            return langList;
        }
        else {
            return supportedLanguages;
        }
    }

    public static Set<String> getStopWords(String language) {
        Set<String> stopWordSet = stopWords.get(language);
        if (stopWordSet == null) {
            Set<String> emptySet = new Set<String>();
            if (language == null || language == '' || language.toLowerCase() == LANGUAGE_NONE) {
                return emptySet;
            }
            ClusterAccessCheck.checkReadPermission(Schema.SObjectType.ClusterLanguage__mdt);
            List<ClusterLanguage__mdt> languages = [SELECT DeveloperName, MasterLabel,clustan__StopWords__c FROM ClusterLanguage__mdt WHERE DeveloperName = :language];
            if (languages.size() > 0) {
                stopWordSet = new Set<String>(languages.get(0).StopWords__c.split(','));
                stopWords.put(language, stopWordSet);
                return stopWordSet;
            }
            stopWords.put(language, emptySet);
            return emptySet;
        }
        else {
            return stopWordSet;
        }
    }

    public static Integer getMinTfIdfWordCount() {
        Integer minWordCount = getIntegerSettingValue('TFIDFMinWordCount', 2);
        if (minWordCount <= 0) {
            minWordCount = 2;
        }
        return minWordCount;
    }

    public static Integer getMaxJsonFieldSize() {
        return MAX_JSON_FIELD_SIZE;
    }

    public static String[] getDefaultClusterColors() {
        return (String[])JSON.deserialize(getLongTextSettingValue('DefaultClusterColors','[]'), String[].class);
    }

    public static Boolean getStorePredictions() {
        Integer storePredictions = getIntegerSettingValue('StorePredictedDataPoints', 0);
        return storePredictions == 1;        
    }

    public static Boolean getStoreNearestNeighbors() {
        Integer storePredictions = getIntegerSettingValue('StoreNearestNeighbors', 1);
        return storePredictions == 1;        
    }

    public static Integer getKNNSearchLimit() {
        return getIntegerSettingValue('KNNSearchLimit', 100);
    }

    public static Integer getKNNSearchChunkLimit() {
        return getIntegerSettingValue('KNNSearchChunkLimit', MIN_KNN_DP_COUNT);
    }
    

    public static Integer getKNNResultLimit() {
        return getIntegerSettingValue('KNNResultLimit', MAX_NEIGHBORS);
    }

    public static Integer getKNNNumber() {
        return getIntegerSettingValue('KNNNumber', NUM_NEAREST_NEIGHBORS_PREDICTION);
    }

    public static Integer getTFIDFWordBagSize() {
        return getIntegerSettingValue('TFIDFWordBagSize', MAX_TFIDF_WORDBAG_SIZE);
    }

    public static String getApexRecordPreprocessorClassName() {
        return getStringSettingValue('ApexRecordPreprocessorClassName', '');
    }

}