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
    public static final String FIELDTYPE_NONE = 'None';
    public static final String FIELDTYPE_OUTPUT = 'Output';

    public static final String ALGORITHM_KMEANS = 'K-Means';
    public static final String ALGORITHM_KMEDOIDS = 'K-Medoids';

    public static final String DISTANCE_MANHATTAN = 'Manhattan';
    public static final String DISTANCE_EUCLIDEAN = 'Euclidean';
    public static final String DISTANCE_GOWER = 'Gower';

    public static final Integer TEST_BATCH_SIZE = 200;

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

    public static Integer getBatchSize() {
        return getIntegerSettingValue('BatchSize', 1000); 
    }

    public static Integer getKMedoidsBatchSize() {
        return getIntegerSettingValue('KMedoidsBatchSize', 200);
    }

    public static Integer getKMedoidsSwapBatchSize() {
        return getIntegerSettingValue('KMedoidsSwapBatchSize', 200);
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

}
