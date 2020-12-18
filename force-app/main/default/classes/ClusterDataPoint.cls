/*
 * Represents a data point - wrapper for ClusterJobResult__c
 *
 * @author: Iskander Mukhamedgaliyev
 */
public with sharing class ClusterDataPoint {
    @AuraEnabled
    public Object[] values;
    @AuraEnabled
    public String valuesJson;
    @AuraEnabled
    public Id recordId;
    @AuraEnabled
    public String externalId;
    @AuraEnabled
    public Integer clusterIndex;
    @AuraEnabled
    public String recordName;    
    @AuraEnabled
    public Double distanceToCluster;
    @AuraEnabled
    public Double distanceToNNCluster;
    public Integer index; //index of the item in the array
    public Double cost;
    public ClusterDataPoint() {

    }

    public ClusterDataPoint(ClusterJobResult__c resultRecord) {
        this.recordId = resultRecord.Id;
        this.externalId = resultRecord.RecordId__c;
        this.clusterIndex = Integer.valueOf(resultRecord.ClusterNumber__c);
        this.recordName = resultRecord.RecordName__c;
        this.distanceToCluster = Double.valueOf(resultRecord.DistanceToCluster__c);
        this.distanceToNNCluster = Double.valueOf(resultRecord.DistanceToNNCluster__c);
    }

    public void loadFromMap(Map<String, Object> values) {
        String recordIdStr = (String)values.get('recordId');
        this.recordId = ClusterDataHelper.stringIsNullOrEmpty(recordIdStr) ? null : Id.valueOf(recordIdStr);
        this.externalId = (String)values.get('externalId');
        this.recordName = (String)values.get('recordName');
        this.valuesJson = (String)values.get('valuesJson');
        this.clusterIndex = (Integer)values.get('clusterIndex');
        this.index = (Integer)values.get('index');
        this.cost = Double.valueOf(values.get('cost'));
        this.distanceToCluster = Double.valueOf(values.get('distanceToCluster'));
        this.distanceToNNCluster = Double.valueOf(values.get('distanceToNNCluster'));
        Object[] dpValues = (Object[])values.get('values');
        this.values = new List<Object>();
        if (dpValues != null) {
            for (Object dpValue:dpValues) {
                if ((dpValue instanceof String) || (dpValue instanceof Integer) || (dpValue instanceof Long) ||
                (dpValue instanceof Double) || (dpValue instanceof Decimal) || (dpValue == null)) {
                    this.values.add(dpValue);
                }                
                else if (dpValue instanceof Map<String, Object>) {
                    this.values.add(ClusterCompressedDoubleArray.createFromJsonMap((Map<String, Object>)dpValue));
                }
            }
        }
    }
    
}