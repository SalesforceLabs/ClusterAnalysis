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
        this.language = field.Language__c;
    }
    public void populateFieldRecord(ClusterModelField__c field){
        field.Id = this.fieldId;
        field.FieldName__c = this.name;
        field.DistanceType__c = this.distanceType;
        field.ObjectName__c = this.objectName;
        field.RelationName__c = this.relationName; 
        field.Weight__c = this.weight;
        field.Language__c = this.language;
    }

    public virtual void loadFromMap(Map<String, Object> fieldValues) {
        this.fieldId = Id.valueOf((String)fieldValues.get('fieldId'));
        this.name = (String)fieldValues.get('name');
        this.displayLabel = (String)fieldValues.get('displayLabel');
        this.distanceType = (String)fieldValues.get('distanceType');
        this.objectName = (String)fieldValues.get('objectName');
        this.relationName = (String)fieldValues.get('relationName');
        this.weight = (Decimal)fieldValues.get('weight');
        this.dataType = (String)fieldValues.get('dataType');
        this.language = (String)fieldValues.get('language');
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
    public String language;
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