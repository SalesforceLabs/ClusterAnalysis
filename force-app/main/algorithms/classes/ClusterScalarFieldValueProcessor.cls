/*
 * Converts scalar field values
 *
 * @author: Iskander Mukhamedgaliyev
 */
public with sharing class ClusterScalarFieldValueProcessor implements ClusterFieldValueProcessor {
    ClusterJobState jobState;

    public ClusterScalarFieldValueProcessor(ClusterJobState state) {
        this.jobState = state;
    }

    public Object processFieldValue(SObject record, ClusterModelFieldWrapper fieldDesc, ClusterMinMaxValue minMaxValue) {
        Object fieldValue = ClusterDataHelper.getSObjectFieldValue(record, fieldDesc);
        //Populating minMaxValues with min and max values for each field respectively
        //This is essential for distance calculations
        Integer compare = ClusterDataHelper.compareFieldValueAbs(minMaxValue.maxValue, fieldValue, fieldDesc);
        if (compare < 0) {
            //For text distances min and max values will contain string length
            if (fieldDesc.distanceType == ClusterConstants.FIELDTYPE_TEXT) {
                minMaxValue.maxValue = fieldValue == null ? 0 : String.valueOf(fieldValue).length();
            }
            else {
                minMaxValue.maxValue = fieldValue;
            }
        }
        compare = ClusterDataHelper.compareFieldValueAbs(minMaxValue.minValue, fieldValue, fieldDesc);
        if (compare > 0 || (minMaxValue.minValue == null)) {
            if (fieldDesc.distanceType == ClusterConstants.FIELDTYPE_TEXT) {
                minMaxValue.minValue = fieldValue == null ? 0 : String.valueOf(fieldValue).length();
            }
            else {
                minMaxValue.minValue = fieldValue;
            }
        }
        return fieldValue;
    }

    public void processTotals(ClusterModelFieldWrapper fieldDesc, ClusterMinMaxValue minMaxValue, Integer recordCount) {
        //precalculating delta (max-min)
        if (fieldDesc.distanceType == ClusterConstants.FIELDTYPE_NUMERIC) {
            minMaxValue.delta = ClusterDataHelper.asDouble(minMaxValue.maxValue) - ClusterDataHelper.asDouble(minMaxValue.minValue);
        }
    }

    public Object parseValueFromJson(JSONParser parser) {
        JSONToken nextToken = parser.nextToken();
        Object value;
        switch on nextToken {            
            when VALUE_NUMBER_FLOAT, VALUE_NUMBER_INT {
                value = parser.getDoubleValue();
            }
            when VALUE_STRING {
                value = parser.getText();
            }
            when VALUE_NULL {
                value = null;
            }
            when VALUE_FALSE, VALUE_TRUE {
                value = parser.getBooleanValue();
            }
            when else {
                throw new ClusterException('Cannot parse json value ' + parser.getText());
            }
        }
        return value;
    }
}