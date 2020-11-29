/*
 * Represents a record neighbor - wrapper for ClusterJobNeighbor__c
 *
 * @author: Iskander Mukhamedgaliyev
 */
public with sharing class ClusterDataPointNeighbor implements Comparable {
    @AuraEnabled
    public String externalRecordId;
    @AuraEnabled
    public Double distance;
    @AuraEnabled
    public Id recordId;
    @AuraEnabled
    public Id jobId;
    @AuraEnabled
    public String neighborExternalRecordId;
    @AuraEnabled
    public ClusterDataPoint neighborDataPoint;

    public ClusterDataPointNeighbor() {

    }

    public ClusterDataPointNeighbor(ClusterJobNeighbor__c jobNeighbor) {
        this.recordId = jobNeighbor.Id;
        this.distance = Double.valueOf(jobNeighbor.Distance__c);
        this.externalRecordId = jobNeighbor.RecordId__c;
        this.jobId = jobNeighbor.ClusterJob__c;
        this.neighborExternalRecordId = jobNeighbor.NeighborRecordId__c;
    }

    public void populateNeighborRecord(ClusterJobNeighbor__c jobNeighbor) {
        jobNeighbor.Distance__c = Decimal.valueOf(this.distance);
        jobNeighbor.RecordId__c = this.externalRecordId;
        jobNeighbor.ClusterJob__c = this.jobId;
        jobNeighbor.NeighborRecordId__c = this.neighborExternalRecordId;
        jobNeighbor.ClusterJobResult__c = this.neighborDataPoint.recordId;
    }

    /**
     * Allow to sort neighbors
     */
    public Integer compareTo(Object compareTo) {
        ClusterDataPointNeighbor other = (ClusterDataPointNeighbor) compareTo;
        return ClusterDataHelper.compareDoubles(this.distance, other.distance);
    }

}
