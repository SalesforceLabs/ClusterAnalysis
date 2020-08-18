/*
 * Algorithm parameters
 *
 * @author: Iskander Mukhamedgaliyev
 */
public with sharing class ClusterAlgorithmParameter {
    public enum ParameterType { STRING_PARAMETER, INTEGER_PARAMETER, DECIMAL_PARAMETER, BOOLEAN_PARAMETER, SELECT_PARAMETER }

    @AuraEnabled
    public String name;
    @AuraEnabled
    public String description;
    @AuraEnabled
    public String type;
    public ParameterType typeEnum;
    @AuraEnabled
    public Object value;
    @AuraEnabled
    public String[] options;
    public ClusterAlgorithmParameter() { }
    public ClusterAlgorithmParameter(String paramName, String paramDescription, ParameterType paramType, Object paramValue, String[] paramOptions) {
        this.name = paramName;
        this.description = paramDescription;
        this.typeEnum = paramType;
        this.type = paramType.name();
        this.value = paramValue;
        this.options = paramOptions;
    }
}