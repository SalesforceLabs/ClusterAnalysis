/*
 * Controller class for model builder lightning component
 *
 * @author: Iskander Mukhamedgaliyev
 */
public with sharing class ClusterModelBuilderController {

    @AuraEnabled
    public static ClusterModelBuilderUiModel getModel(Id modelId) {
        ClusterAccessCheck.checkReadPermission(Schema.SObjectType.ClusterModel__c);
        ClusterModelBuilderUiModel uiModel = new ClusterModelBuilderUiModel();
        ClusterModelWrapper cmWrapper;
        if (modelId != null) {
            cmWrapper = loadModel(modelId);
            uiModel.queryObjects = getQueryObjects(cmWrapper.objectName);
            //TODO: rewrite this loop to iterate through queryobjects first
            for (ClusterModelFieldWrapper field:cmWrapper.fields){
                for (ClusterModelBuilderUiModel.QueryObject queryObject:uiModel.queryObjects){
                    if (queryObject.name == field.objectName && queryObject.relationshipName == field.relationName){
                        for (ClusterModelBuilderUiModel.QueryField queryField:queryObject.fields){
                            if (field.name == queryField.name) {
                                queryField.checked = true;
                            }
                        }
                    }
                }
            }
        }
        else {
            cmWrapper = new ClusterModelWrapper();
            cmWrapper.numberOfClusters = 3;
            cmWrapper.algorithm = ClusterConstants.ALGORITHM_KMEDOIDS;
        }
        uiModel.objects = getObjects();
        uiModel.model = cmWrapper;
        uiModel.algorithmList = getAlgorithmList();
        uiModel.fieldTypeList = getPickListValues(ClusterModelField__c.DistanceType__c.getDescribe());
        uiModel.languageList = ClusterConstants.getSupportedModelLanguages();
        return uiModel;
    }

    public static ClusterModelWrapper loadModel(Id modelId) {
        ClusterModel__c model;
        ClusterAccessCheck.checkReadPermission(Schema.SObjectType.ClusterModel__c);
        //isAccessible permission is checked in ClusterAccessCheck.checkReadPermission, exception is thrown in case of no access
        model = [SELECT Id, Name, Object__c, Algorithm__c, Filter__c, Parameters__c, SOQL__c , isCustomSoql__c, Description__c, NumberOfClusters__c,
                (SELECT Id, Name, FieldName__c, Model__c, ObjectName__c, DistanceType__c, Weight__c, RelationName__c, Language__c FROM ClusterModelFields__r)
                FROM ClusterModel__c WHERE Id = :modelId];
        return new ClusterModelWrapper(model);
    }

    @AuraEnabled
    public static ClusterModelWrapper saveModel(String modelJson) {
        ClusterModelWrapper model = (ClusterModelWrapper)JSON.deserialize(modelJson, ClusterModelWrapper.class);
        model.prepare();
        ClusterAlgorithmRunner runner = ClusterAlgorithmFactory.getRunner(model);
        ClusterAlgorithmRunner.ModelValidationResult vr = runner.validateModel(model);
        if (!vr.isValid) {
            ClusterException ex = new ClusterException();
            ex.setMessage('Model validation failed. Error message(s): ' + String.join(vr.messages,'\n'));
            throw ex;
        }
        ClusterModel__c cmodel;
        List<ClusterModelField__c> cmodelFields;
        //Checking FLS permissions
        ClusterAccessCheck.checkFLSCreatePermission(Schema.sObjectType.ClusterModelField__c.fields.Model__c);
        ClusterAccessCheck.checkFLSCreatePermission(Schema.sObjectType.ClusterModelField__c.fields.FieldName__c);
        ClusterAccessCheck.checkFLSCreatePermission(Schema.sObjectType.ClusterModelField__c.fields.DistanceType__c);
        ClusterAccessCheck.checkFLSCreatePermission(Schema.sObjectType.ClusterModelField__c.fields.ObjectName__c);
        ClusterAccessCheck.checkFLSCreatePermission(Schema.sObjectType.ClusterModelField__c.fields.RelationName__c);
        ClusterAccessCheck.checkFLSCreatePermission(Schema.sObjectType.ClusterModelField__c.fields.Weight__c);
        ClusterAccessCheck.checkFLSCreatePermission(Schema.sObjectType.ClusterModelField__c.fields.Language__c);
        ClusterAccessCheck.checkFLSReadPermission(Schema.sObjectType.ClusterModelField__c.fields.Id);

        if (model.modelId != null) {
            ClusterAccessCheck.checkCRUDPermission(Schema.SObjectType.ClusterModel__c);
            ClusterAccessCheck.checkCRUDPermission(Schema.SObjectType.ClusterModelField__c);
    
            //CRUD permissions are checked in ClusterAccessCheck.checkCRUDPermission, exception is thrown in case of no access
            cmodel = [SELECT Id, Name, Algorithm__c, Filter__c, Parameters__c, SOQL__c , isCustomSoql__c, Description__c, NumberOfClusters__c FROM ClusterModel__c WHERE Id = :model.modelId WITH SECURITY_ENFORCED FOR UPDATE];
            //removing existing fields
            List<ClusterModelField__c> existingFields = [SELECT Id, Name, Model__c FROM ClusterModelField__c WHERE Model__c = :model.modelId WITH SECURITY_ENFORCED FOR UPDATE];
            delete existingFields;
            model.populateModelRecord(cmodel);
            update cmodel;
            cmodelFields = model.getModelFields();
            insert cmodelFields;
        }
        else {
            ClusterAccessCheck.checkCreatePermission(Schema.SObjectType.ClusterModel__c);
            ClusterAccessCheck.checkCreatePermission(Schema.SObjectType.ClusterModelField__c);
            //Insert permissions are checked in ClusterAccessCheck.checkCreatePermission above, exception is thrown in case of no access
            cmodel = new ClusterModel__c();
            model.populateModelRecord(cmodel);
            insert cmodel;
            model.modelId = cmodel.Id;
            cmodelFields = model.getModelFields();
            insert cmodelFields;
        }
        model.populateModelFields(cmodelFields);
        if (model.parameters == null) {
            model.parameters = new Map<String, Object>();
        }
        return model;
    }

    private static List<UiSelectOption> getPickListValues(Schema.DescribeFieldResult fieldResult) {
        List<UiSelectOption> values = new List<UiSelectOption>();
        List<Schema.PicklistEntry> ple = fieldResult.getPicklistValues();
        for(Schema.PicklistEntry pickListVal : ple) {
            if (pickListVal.isActive()) {
                values.add(new UiSelectOption(pickListVal.getValue(), pickListVal.getLabel() ));
            }
        }
        return values;
    }

    private static List<UiSelectOption> getAlgorithmList() {
        return ClusterAlgorithmFactory.getAlgorithmList();
    }

    @AuraEnabled
    public static List<UiSelectOption> getObjects() {
        Map<String, Schema.SObjectType> gd = Schema.getGlobalDescribe();    
        List<UiSelectOption> objects = new List<UiSelectOption>();
        for(String objectName : gd.keySet())
        {
            DescribeSObjectResult od = gd.get(objectName).getDescribe();
            if (od.isQueryable()) {
                objects.add(new UiSelectOption(od.getName(),od.getLabel() + ' (' + od.getName() + ')'));
            }
        }
        objects.sort();
        return objects;
    }

    @AuraEnabled
    public static List<ClusterModelBuilderUiModel.QueryObject> getQueryObjects(String objectName){
        List<ClusterModelBuilderUiModel.QueryObject> result = new List<ClusterModelBuilderUiModel.QueryObject>();
        Schema.DescribeSObjectResult[] descResult = Schema.describeSObjects(new String[]{objectName});
        if (descResult.size() > 0){
            Map<String,Schema.SObjectField> fieldsMap = descResult[0].fields.getMap();
            ClusterModelBuilderUiModel.QueryObject queryObject = new ClusterModelBuilderUiModel.QueryObject(descResult[0]);
            result.add(queryObject);
            List<ClusterModelBuilderUiModel.QueryField> fields = new List<ClusterModelBuilderUiModel.QueryField>();
            for (String fieldName : fieldsMap.keySet()){
                DescribeFieldResult fd = fieldsMap.get(fieldName).getDescribe();
                if (isFieldClusterable(fd)) {
                    ClusterModelBuilderUiModel.QueryField field = new ClusterModelBuilderUiModel.QueryField(fd, objectName, '');
                    field.checked = field.name.toLowerCase() == 'id' || fd.isNameField();
                    fields.add(field);
                    //Polymorphic fields are not supported for now
                    if (!fd.isNamePointing()) {
                        List <Schema.sObjectType> references = fd.getReferenceTo();
                        //Adding all parent relations to the list
                        for (Schema.sObjectType sot:references) {
                            ClusterModelBuilderUiModel.QueryObject parentObject = getQueryObject(sot.getDescribe().getName(), fd.getRelationshipName());
                            String relationName = fd.getRelationshipName();
                            if (relationName == null || relationName == '') {
                                relationName = fieldName;
                            }
                            parentObject.label = relationName + ' (' + parentObject.label + ')';
                            result.add(parentObject);
                        }
                    }
                }
            }
            fields.sort();
            queryObject.fields = fields;
        }
        return result;
    }

    public static ClusterModelBuilderUiModel.QueryObject getQueryObject(String objectName, String relationshipName){
        Schema.DescribeSObjectResult[] descResult = Schema.describeSObjects(new String[]{objectName});
        if (descResult.size() > 0){
            ClusterModelBuilderUiModel.QueryObject queryObject = new ClusterModelBuilderUiModel.QueryObject(descResult[0]);
            queryObject.relationshipName = relationshipName;
            List<ClusterModelBuilderUiModel.QueryField> fields = new List<ClusterModelBuilderUiModel.QueryField>();
            Map<String,Schema.SObjectField> fieldsMap = descResult[0].fields.getMap();
            for (String fieldName : fieldsMap.keySet()){
                DescribeFieldResult fd = fieldsMap.get(fieldName).getDescribe();
                if (isFieldClusterable(fd)) {
                    ClusterModelBuilderUiModel.QueryField field = new ClusterModelBuilderUiModel.QueryField(fd, objectName, relationshipName);                
                    fields.add(field);
                }
            }
            fields.sort();
            queryObject.fields = fields;
            return queryObject;
        }
        else {
            return null;
        }
    }

    public static Boolean isFieldClusterable(DescribeFieldResult dfr) {
        Schema.DisplayType fType = dfr.getType();
        return fType != Schema.DisplayType.ADDRESS && fType != Schema.DisplayType.DATACATEGORYGROUPREFERENCE;
    }
}