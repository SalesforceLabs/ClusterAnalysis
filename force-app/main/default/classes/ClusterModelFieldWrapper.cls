/*
 * This is a wrapper class for ClusterModelField__c
 *
 * @author: Iskander Mukhamedgaliyev
 */
public class ClusterModelFieldWrapper {
    public ClusterModelFieldWrapper() {

    }
    public ClusterModelFieldWrapper(ClusterModelField__c field) {
        this.fieldId = field.Id;
        this.name = field.FieldName__c;
        this.distanceType = field.DistanceType__c;
        this.objectName = field.ObjectName__c;
        this.relationName = field.RelationName__c; 
        this.weight = field.Weight__c;
    }
    public void populateFieldRecord(ClusterModelField__c field){
        field.Id = this.fieldId;
        field.FieldName__c = this.name;
        field.DistanceType__c = this.distanceType;
        field.ObjectName__c = this.objectName;
        field.RelationName__c = this.relationName; 
        field.Weight__c = this.weight;
    }
    @AuraEnabled
    public Id fieldId;
    @AuraEnabled
    public String name;
    @AuraEnabled
    public String displayLabel;
    @AuraEnabled
    public String distanceType;
    @AuraEnabled
    public String objectName;
    @AuraEnabled
    public String relationName;
    @AuraEnabled
    public Decimal weight;
    @AuraEnabled
    public String dataType;
    @AuraEnabled
    public Boolean isNumeric;
    @AuraEnabled
    public Boolean isText;
    @AuraEnabled
    public Boolean isLongText;
    @AuraEnabled
    public Boolean isCategory;
    public Boolean isIdField;
    public Boolean isNameField;
}
