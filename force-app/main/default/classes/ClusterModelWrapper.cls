/*
 * Represents a cluster model, wrapper for ClusterModel__c
 * Used almost everywhere in UI and calculations
 *
 * @author: Iskander Mukhamedgaliyev
 */
public class ClusterModelWrapper {
    public ClusterModelWrapper() {
        this.parameters = new Map<String, Object>();
    }
    public ClusterModelWrapper(ClusterModel__c model) {
        this.modelId = model.Id;
        this.name = model.Name;
        this.description = model.Description__c;
        this.algorithm = model.Algorithm__c;
        this.filter = model.Filter__c;
        if (model.Parameters__c != null && model.Parameters__c != '') {
            this.parameters = (Map<String, Object>)JSON.deserializeUntyped(model.Parameters__c);
        }
        this.soql = model.SOQL__c;
        this.objectName = model.Object__c;
        this.isCustomSoql = model.isCustomSoql__c;
        this.numberOfClusters = model.NumberOfClusters__c == null ? 0 : model.NumberOfClusters__c.intValue();
        this.populateModelFields(model.ClusterModelFields__r);
    }
    public void populateModelRecord(ClusterModel__c model){
        model.Id = this.modelId;
        model.Name = this.name;
        model.Description__c = this.description;
        model.Algorithm__c = this.algorithm;
        model.Filter__c = this.filter;
        model.Parameters__c = JSON.serialize(this.parameters);
        model.SOQL__c = this.soql;
        model.Object__c = this.objectName;
        model.isCustomSoql__c = this.isCustomSoql;
        model.NumberOfClusters__c = this.numberOfClusters;
    }
    public void populateModelFields(List<ClusterModelField__c> modelFields){
        this.fields = new List<ClusterModelFieldWrapper>();
        if (modelFields == null || modelFields.size() == 0) return;
        Schema.DescribeSObjectResult[] descResult = Schema.describeSObjects(new String[]{objectName});
        System.assertNotEquals(descResult.size(), 0, 'Cannot find object ' + objectName + ' in the describe result');
        Map<String,Schema.SObjectField> fieldsMap = descResult[0].fields.getMap();
        for (ClusterModelField__c cmf:modelFields) {
            ClusterModelFieldWrapper field = new ClusterModelFieldWrapper(cmf);
            SObjectField sof = fieldsMap.get(field.name);
            DescribeFieldResult fd = sof == null ? null : sof.getDescribe();
            this.populateField(field, fd);
            this.fields.add(field);
        }
    }
    public void prepare() {
        Schema.DescribeSObjectResult[] descResult = Schema.describeSObjects(new String[]{objectName});
        System.assertNotEquals(descResult.size(), 0, 'Cannot find object ' + objectName + ' in the describe result');
        Map<String,Schema.SObjectField> fieldsMap = descResult[0].fields.getMap();
        for (ClusterModelFieldWrapper field:this.fields) {
            SObjectField sof = fieldsMap.get(field.name);
            DescribeFieldResult fd = sof == null ? null : sof.getDescribe();
            this.populateField(field, fd);
        }
    }
    private void populateField(ClusterModelFieldWrapper field, DescribeFieldResult fd) {
        if (fd != null) {
            field.isIdField = field.name.toLowerCase() == 'id';
            field.isNameField = fd.isNameField();
            field.dataType = fd.getType().name().toLowerCase();
        }
        field.isNumeric = field.distanceType == ClusterConstants.FIELDTYPE_NUMERIC;
        field.isText = field.distanceType == ClusterConstants.FIELDTYPE_TEXT;
        field.isLongText = field.distanceType == ClusterConstants.FIELDTYPE_LONGTEXT;
        field.isCategory = field.distanceType == ClusterConstants.FIELDTYPE_CATEGORY;
    }
    public List<ClusterModelField__c> getModelFields() {
        List<ClusterModelField__c> modelFields = new List<ClusterModelField__c>();
        for (ClusterModelFieldWrapper fieldWrapper:this.fields) {
            ClusterModelField__c field = new ClusterModelField__c();
            fieldWrapper.populateFieldRecord(field);
            field.Id = null;
            if (Schema.sObjectType.ClusterModelField__c.fields.Model__c.isAccessible() && Schema.sObjectType.ClusterModelField__c.fields.Model__c.isCreateable()) {
                field.Model__c = this.modelId;
            }
            modelFields.add(field);
        }
        return modelFields;
    }
    public Boolean hasLongTextFields() {
        Boolean hasLongText = false;
        for (ClusterModelFieldWrapper field : this.fields) {
            if (field.isLongText) {
                hasLongText = true;
                break;
            }
        }
        return hasLongText;
    }

    @AuraEnabled
    public Id modelId;
    @AuraEnabled
    public String name;
    @AuraEnabled
    public String description;
    @AuraEnabled
    public String algorithm;
    @AuraEnabled
    public String filter;
    @AuraEnabled
    public String objectName;
    @AuraEnabled
    public Map<String, Object> parameters;
    @AuraEnabled
    public Integer numberOfClusters;
    @AuraEnabled
    public String soql;
    @AuraEnabled
    public Boolean isCustomSoql;
    @AuraEnabled
    public String distanceFunction;
    @AuraEnabled
    public List<ClusterModelFieldWrapper> fields;
}