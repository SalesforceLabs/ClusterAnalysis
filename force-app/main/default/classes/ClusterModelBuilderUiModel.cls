/*
 * UI model for model builder lightning component
 *
 * @author: Iskander Mukhamedgaliyev
 */
public class ClusterModelBuilderUiModel {
    public class QueryObject{
        public QueryObject() {

        }
        public QueryObject(Schema.DescribeSObjectResult descibe){
            this.name = descibe.getName();
            this.label = descibe.getLabel();
        }
        @AuraEnabled
        public String name;
        @AuraEnabled
        public String relationshipName;
        @AuraEnabled
        public String label;
        @AuraEnabled
        public List<QueryField> fields;
    }
    public class QueryField implements Comparable {
        @AuraEnabled
        public String name;
        @AuraEnabled
        public String relationshipName;
        @AuraEnabled
        public String objectName;
        @AuraEnabled
        public String label;
        @AuraEnabled
        public String displayLabel;
        @AuraEnabled
        public Boolean checked;
        @AuraEnabled
        public Boolean required;
        @AuraEnabled
        public String value;
        @AuraEnabled
        public String dataType;
        @AuraEnabled
        public Boolean isFilterable;
        @AuraEnabled
        public List<UiSelectOption> picklistValues;
        public QueryField(DescribeFieldResult fd, String objectName, String relationName) {
            this.name = fd.getName();
            this.displayLabel = fd.getLabel();
            this.label = fd.getName();
            this.objectName = objectName;
            this.relationshipName = relationName;
            this.value = (relationName == '' || relationName == null ? this.objectName : relationName) + '.' + this.name;
            this.checked = false;
            this.isFilterable = fd.isFilterable();
            Schema.DisplayType fieldType = fd.getType();
            this.dataType = fieldType.name();
            this.picklistValues = new List<UiSelectOption>();
            if (fieldType == Schema.DisplayType.Picklist) {
                List<Schema.PicklistEntry> plValues = fd.getPicklistValues();
                for (Schema.PicklistEntry pe:plValues){
                    if (pe.isActive()) {
                        UiSelectOption peWrapper = new UiSelectOption(pe.getValue(), pe.getLabel());
                        this.picklistValues.add(peWrapper);
                    }
                }
            }
        }
        public Integer compareTo(Object compareTo) {
            if (compareTo == null || ((QueryField)compareTo).label == null) {
                return 1;
            }
            if (this.label == null) {
                return -1;
            }
            return this.label.compareTo(((QueryField)compareTo).label);
        }
    }    
    public ClusterModelBuilderUiModel() {

    }
    @AuraEnabled
    public ClusterModelWrapper model;
    @AuraEnabled
    public List<UiSelectOption> objects;
    @AuraEnabled
    public List<QueryObject> queryObjects;
    @AuraEnabled
    public List<UiSelectOption> algorithmList;
    @AuraEnabled
    public List<UiSelectOption> fieldTypeList;
    
}
