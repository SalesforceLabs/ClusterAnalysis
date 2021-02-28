/*
 * Allows to implement custom Apex record preprocessors
 *
 * @author: Iskander Mukhamedgaliyev
 */
global interface ClusterRecordPreprocessor {
    void processRecords(List<SObject> records, ClusterRecordPreprocessorParameters parameters);
}
