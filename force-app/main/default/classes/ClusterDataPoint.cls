/*
 * Represents a data point - wrapper for ClusterJobResult__c
 *
 * @author: Iskander Mukhamedgaliyev
 */
public with sharing class ClusterDataPoint {
    @AuraEnabled
    public Object[] values;
    @AuraEnabled
    public Id recordId;
    @AuraEnabled
    public String externalId;
    @AuraEnabled
    public Integer clusterIndex;
    @AuraEnabled
    public String recordName;    
    public Integer index; //index of the item in the array
    public Double cost;
    public ClusterDataPoint() {

    }
    public ClusterDataPoint(ClusterJobResult__c resultRecord) {
        this.recordId = resultRecord.Id;
        this.externalId = resultRecord.RecordId__c;
        this.clusterIndex = Integer.valueOf(resultRecord.ClusterNumber__c);
        this.recordName = resultRecord.RecordName__c;
        this.values = (Object[])JSON.deserializeUntyped(resultRecord.Json__c);
    }
}
