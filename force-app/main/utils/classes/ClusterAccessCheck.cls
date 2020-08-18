public with sharing class ClusterAccessCheck {
    public static void checkUpdatePermission(Schema.DescribeSObjectResult objectDesc) {
        if (!objectDesc.isUpdateable()) {
            throw new ClusterException('Current user doesn\'t have permissions to update records in ' + objectDesc.getName());
        }
    }

    public static void checkCreatePermission(Schema.DescribeSObjectResult objectDesc) {
        if (!objectDesc.isCreateable()) {
            throw new ClusterException('Current user doesn\'t have permissions to create new records in ' + objectDesc.getName());
        }
    }

    public static void checkReadPermission(Schema.DescribeSObjectResult objectDesc) {
        if (!objectDesc.isAccessible()) {
            throw new ClusterException('Current user doesn\'t have permissions to access ' + objectDesc.getName());
        }
    }

    public static void checkDeletePermission(Schema.DescribeSObjectResult objectDesc) {
        if (!objectDesc.isDeletable()) {
            throw new ClusterException('Current user doesn\'t have permissions to delete records in ' + objectDesc.getName());
        }
    }

    public static void checkCRUDPermission(Schema.DescribeSObjectResult objectDesc) {
        if (!(objectDesc.isDeletable() && objectDesc.isAccessible() && objectDesc.isCreateable() && objectDesc.isUpdateable())) {
            throw new ClusterException('Current user doesn\'t have CRUD permissions on ' + objectDesc.getName());
        }
    }

    public static void checkFLSReadPermission(Schema.DescribeFieldResult fieldDesc) {
        if (!fieldDesc.isAccessible()) {
            throw new ClusterException('Current user doesn\'t have FLS read permissions on ' + fieldDesc.getName());
        }
    }

    public static void checkFLSCreatePermission(Schema.DescribeFieldResult fieldDesc) {
        if (!(fieldDesc.isAccessible() && fieldDesc.isCreateable())) {
            throw new ClusterException('Current user doesn\'t have create FLS permissions on ' + fieldDesc.getName());
        }
    }

    public static List<String> checkModelObjectAccessPermissions(ClusterModelWrapper model) {
        List<String> errors = new List<String>();
        Map<String, List<ClusterModelFieldWrapper>> modelObjects = new Map<String, List<ClusterModelFieldWrapper>>();
        modelObjects.put(model.objectName, new List<ClusterModelFieldWrapper>());
        for (ClusterModelFieldWrapper field:model.fields) {
            List<ClusterModelFieldWrapper> modelFields = modelObjects.get(field.objectName);
            if (modelFields == null) {
                modelFields = new List<ClusterModelFieldWrapper>();
                modelObjects.put(field.objectName, modelFields);
            }
            modelFields.add(field);
        }        
        Schema.DescribeSObjectResult[] descResults = Schema.describeSObjects(new List<String>(modelObjects.keySet()));
        for (Schema.DescribeSObjectResult dr:descResults) {
            if (!dr.isAccessible()) {
                errors.add('Current user doesn\'t have read permissions on ' + dr.getName());
            }
            List<ClusterModelFieldWrapper> modelFields = modelObjects.get(dr.getName());
            Map<String,Schema.SObjectField> fieldsMap = dr.fields.getMap();
            for (ClusterModelFieldWrapper field:modelFields) {
                DescribeFieldResult fd = fieldsMap.get(field.name).getDescribe();
                if (!fd.isAccessible()) {
                    errors.add('Current user doesn\'t have read FLS permissions on ' + dr.getName() + '.' + fd.getName());
                }
                if ((field.distanceType == ClusterConstants.FIELDTYPE_OUTPUT) && (!dr.isUpdateable() || !fd.isUpdateable())) {
                    errors.add('Current user doesn\'t have update FLS permissions on ' + dr.getName() + '.' + fd.getName());
                }
            }
        }
        return errors;
    }
    

}